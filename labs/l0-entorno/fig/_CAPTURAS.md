# Capturas pendientes de L0 (no se publica: el prefijo `_` lo excluye del render)

Estado: **ninguna captura existe todavía**. En `index.qmd` hay un recuadro «Captura pendiente» por cada
tema, con el bloque Markdown de la figura comentado justo debajo. Cuando la captura exista:

1. Guárdala en `labs/l0-entorno/fig/` con el nombre previsto (PNG, ancho de 1200 a 1600 px, sin
   ventanas ajenas al tema).
2. En `index.qmd`, descomenta el bloque de la figura, añade el pie (`![Pie…](…){#fig-… fig-alt="…"}`) y
   elimina el recuadro `.captura-pendiente`.
3. Regla del proyecto: la captura **acompaña** al texto, nunca lo sustituye. Revisa que la página siga
   siendo comprensible sin ella.

## Cómo hacerlas (reglas comunes)

- **Nada personal**: oculta o difumina nombre de usuario del sistema, rutas con tu nombre
  (usa `cd ~/Proyectos` y un indicador de órdenes corto), correo, direcciones de cuenta y cualquier
  token. En `git config` y en `claude auth status` aparece el correo: usa una cuenta de pruebas o
  tapa el dato.
- **Terminal**: tema claro, fuente de 14 pt o más, ventana de unas 90 columnas. macOS: Terminal.app
  o la terminal integrada de VS Code, captura con Mayús+Cmd+4 y la barra espaciadora (ventana).
  Windows: Windows Terminal con PowerShell 7, captura con Win+Mayús+S.
- **VS Code**: tema claro, barra lateral de archivos visible, panel de terminal abierto.
- Una captura por sistema (macOS y Windows) cuando el aspecto difiere; si son idénticas salvo el
  marco de la ventana, basta una y se dice en el pie.
- Comprueba que el texto de la captura se lee a 800 px de ancho (tamaño en la página).

## Tabla

| Fichero previsto | Sistema | Qué mostrar | Cómo hacerla | `fig-alt` propuesto |
|---|---|---|---|---|
| `fig/cap-powershell-win.png` | Windows | Windows Terminal con una pestaña de PowerShell 7 y el resultado de `$PSVersionTable.PSVersion` (versión mayor 7) | Instala PowerShell 7 (`winget install --id Microsoft.PowerShell --source winget`), ábrelo y ejecuta la orden | «Windows Terminal con PowerShell 7 mostrando la versión de PowerShell con la versión mayor 7» |
| `fig/cap-git-mac.png` | macOS | `git --version` y `git config --global --get user.name` (sin correo) | Terminal limpia; ejecuta las dos órdenes | «Terminal de macOS con la versión de Git y el nombre configurado para los commits» |
| `fig/cap-git-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «PowerShell 7 con la versión de Git y el nombre configurado para los commits» |
| `fig/cap-juliaup-mac.png` | macOS | Salida de `juliaup status` (canal por defecto, versión instalada) y de `julia --version` | Tras instalar con juliaup; terminal limpia | «Terminal de macOS con la tabla de juliaup que marca la versión 1.12 como predeterminada y la versión de Julia» |
| `fig/cap-juliaup-win.png` | Windows | Final de la instalación de Julia con `winget` (mensaje de éxito) y después `julia --version` en una terminal nueva | Instala con winget; abre una terminal nueva | «PowerShell 7 con el mensaje de instalación correcta de Julia y la versión instalada» |
| `fig/cap-quarto-check-mac.png` | macOS | `quarto check install` con las marcas de verificación y la versión de Quarto | Ejecuta la orden; recorta para que quepan las líneas «Checking Quarto installation… OK» | «Terminal de macOS con el resultado de quarto check install: la instalación de Quarto aparece correcta» |
| `fig/cap-quarto-check-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «PowerShell 7 con el resultado de quarto check install: la instalación de Quarto aparece correcta» |
| `fig/cap-vscode-mac.png` | macOS | VS Code con la carpeta `resonancia` abierta, el explorador de archivos, la terminal integrada y la vista de extensiones con Julia, Quarto y Claude Code instaladas | Abre la carpeta del repositorio; panel Extensiones filtrado por «instaladas»; terminal con `git status` | «VS Code con el repositorio resonancia abierto, la terminal integrada abajo y las extensiones de Julia, Quarto y Claude Code en la barra lateral» |
| `fig/cap-vscode-win.png` | Windows | Lo mismo, con PowerShell 7 como perfil de la terminal integrada | Idem (perfil de terminal: PowerShell) | «VS Code en Windows con el repositorio resonancia abierto y PowerShell 7 en la terminal integrada» |
| `fig/cap-clonar-mac.png` | macOS | `git clone …`, `cd resonancia`, `git status` limpio y el final de `Pkg.instantiate()` | Ejecuta la secuencia en una carpeta nueva; recorta el progreso largo | «Terminal de macOS tras clonar el repositorio resonancia e instanciar el entorno de Julia sin errores» |
| `fig/cap-clonar-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «PowerShell 7 tras clonar el repositorio resonancia e instanciar el entorno de Julia sin errores» |
| `fig/cap-claude-instalar-mac.png` | macOS | `claude --version` tras instalar y el resultado de `claude doctor` | Terminal limpia; oculta la ruta con tu nombre | «Terminal de macOS con la versión de Claude Code y el diagnóstico de claude doctor» |
| `fig/cap-claude-instalar-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «PowerShell 7 con la versión de Claude Code y el diagnóstico de claude doctor» |
| `fig/cap-claude-confianza-mac.png` | macOS | La pregunta de confianza de la carpeta que aparece la primera vez que se ejecuta `claude` en el repositorio | Ejecuta `claude` en una copia sin confianza previa; captura **antes** de responder | «Pantalla de Claude Code que pregunta si se confía en la carpeta del proyecto, con las opciones de aceptar o salir» |
| `fig/cap-claude-confianza-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «Pantalla de Claude Code en Windows que pregunta si se confía en la carpeta del proyecto» |
| `fig/cap-verificacion-mac.png` | macOS | La lista de verificación final completa y su resultado correcto | Ejecuta el bloque de la sección de práctica (paso final) | «Terminal de macOS con las versiones de Julia, Quarto, Git, uv y Claude Code y la comprobación de Resonancia.jl» |
| `fig/cap-verificacion-win.png` | Windows | Lo mismo en PowerShell 7 | Idem | «PowerShell 7 con las versiones de Julia, Quarto, Git, uv y Claude Code y la comprobación de Resonancia.jl» |

## Notas

- Las capturas de Claude Code pueden cambiar de versión en versión (textos de la pregunta de confianza,
  formato de `claude doctor`): anota en el pie la versión con la que se hizo.
- No se hacen capturas de la web de GitHub ni de formularios de cuenta (cambian a menudo y pueden
  mostrar datos personales); el texto de la unidad basta.
- Las figuras 1 y 2 de la unidad (`portada`, `arquitectura`) son TikZ y ya están compiladas.
