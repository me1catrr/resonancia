"""Crea o actualiza un BORRADOR en Zenodo con un paquete de datos. No publica nunca.

Uso (desde la raíz del proyecto):
    python3 -I scripts/zenodo/depositar.py datos/zenodo/torroja-puente --seco      # solo comprueba
    ZENODO_TOKEN=... python3 -I scripts/zenodo/depositar.py datos/zenodo/torroja-puente

Entorno:
    ZENODO_TOKEN  token personal con permiso deposit:write (nunca en el repositorio)
    ZENODO_URL    por defecto https://sandbox.zenodo.org (pruebas); para el real: https://zenodo.org

El paquete lleva un `zenodo.json` con los metadatos. Si ya existe `.deposito` (id del borrador), se reutiliza.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("ZENODO_URL", "https://sandbox.zenodo.org").rstrip("/")
OBLIGATORIOS = ("title", "upload_type", "description", "creators", "license")


def api(metodo, ruta, token, cuerpo=None, datos=None, tipo="application/json"):
    url = ruta if ruta.startswith("http") else f"{BASE}/api{ruta}"
    if cuerpo is not None:
        datos, tipo = json.dumps(cuerpo).encode(), "application/json"
    req = urllib.request.Request(url, data=datos, method=metodo)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", tipo)
    try:
        with urllib.request.urlopen(req) as r:
            texto = r.read().decode()
            return json.loads(texto) if texto else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"Error {e.code} en {metodo} {ruta}: {e.read().decode()[:500]}")


def main(argv):
    seco = "--seco" in argv
    carpetas = [a for a in argv if not a.startswith("--")]
    if len(carpetas) != 1:
        sys.exit(__doc__)
    paquete = Path(carpetas[0])
    meta = json.loads((paquete / "zenodo.json").read_text(encoding="utf-8"))
    faltan = [k for k in OBLIGATORIOS if not meta.get(k)]
    if faltan:
        sys.exit(f"Faltan metadatos en zenodo.json: {faltan}")
    ficheros = sorted(p for p in paquete.rglob("*") if p.is_file() and p.name not in (".deposito", ".DS_Store", "zenodo.json"))
    total = sum(p.stat().st_size for p in ficheros)
    print(f"Destino: {BASE}\nPaquete: {paquete} ({len(ficheros)} ficheros, {total / 1e6:.0f} MB)")
    for p in ficheros:
        print(f"  {p.relative_to(paquete)}  {p.stat().st_size / 1e6:.1f} MB")
    if seco:
        print("Modo seco: no se ha enviado nada.")
        return
    token = os.environ.get("ZENODO_TOKEN")
    if not token:
        sys.exit("Falta la variable de entorno ZENODO_TOKEN.")

    marca = paquete / ".deposito"
    if marca.exists():
        dep = api("GET", f"/deposit/depositions/{marca.read_text().strip()}", token)
    else:
        dep = api("POST", "/deposit/depositions", token, cuerpo={})
        marca.write_text(str(dep["id"]))
    print(f"Borrador {dep['id']}: {dep['links']['html']}")
    api("PUT", f"/deposit/depositions/{dep['id']}", token, cuerpo={"metadata": meta})
    print("Metadatos enviados.")

    cubo = dep["links"]["bucket"]
    ya = {f["filename"] for f in api("GET", f"/deposit/depositions/{dep['id']}/files", token)}
    for p in ficheros:
        nombre = p.relative_to(paquete).as_posix()
        if nombre in ya:
            print(f"  ya subido: {nombre}")
            continue
        with p.open("rb") as f:
            api("PUT", f"{cubo}/{nombre}", token, datos=f, tipo="application/octet-stream")
        print(f"  subido: {nombre}")
    print("Listo. Revisa el borrador en la web y publícalo desde allí.")


main(sys.argv[1:])
