// Pruebas del evaluador de permisos.   deno test --no-check --allow-read recursos/js/
import assert from "node:assert/strict";
import test from "node:test";
import { evaluar, patronARegex, quitarEnvoltorios, partes, REGLAS_EJEMPLO as R } from "./permisos.js";

test("comodín final tras espacio casa con y sin argumentos", () => {
  assert.ok(patronARegex("npm run *").test("npm run"));
  assert.ok(patronARegex("npm run *").test("npm run build --watch"));
  assert.ok(!patronARegex("npm run *").test("npm install"));
  assert.ok(patronARegex("ls:*").test("ls -la"));
});

test("sin espacio antes del comodín es un prefijo", () => {
  assert.ok(patronARegex("git reset --hard*").test("git reset --hard HEAD~1"));
  assert.ok(patronARegex("git reset --hard*").test("git reset --hardx"));
});

test("el punto y otros caracteres especiales se escapan", () => {
  assert.ok(patronARegex("julia --project=. *").test("julia --project=. script.jl"));
  assert.ok(!patronARegex("julia --project=. *").test("julia --projectX. script.jl"));
});

test("orden deny → ask → allow", () => {
  assert.equal(evaluar(R, "git status").decision, "allow");
  assert.equal(evaluar(R, "git push origin main").decision, "ask");
  assert.equal(evaluar(R, "rm -rf resultados").decision, "deny");
  assert.equal(evaluar({ allow: ["git *"], ask: ["git push *"], deny: [] }, "git push x").decision, "ask");
  assert.equal(evaluar({ allow: ["rm *"], ask: [], deny: ["rm -rf *"] }, "rm -rf x").decision, "deny");
});

test("órdenes compuestas: deny/ask casan con cualquier parte; allow exige todas", () => {
  assert.equal(evaluar(R, "git status && git push").decision, "ask");
  assert.equal(evaluar(R, "git status && git diff").decision, "allow");
  assert.equal(evaluar(R, "git status && curl x").decision, "ask-por-defecto");
  assert.equal(evaluar(R, "ls; rm -rf /").decision, "deny");
});

test("los envoltorios se descartan", () => {
  assert.equal(quitarEnvoltorios("timeout 30 uv run pytest"), "uv run pytest");
  assert.equal(evaluar(R, "timeout 30 uv run pytest").decision, "allow");
  assert.equal(evaluar(R, "nice rm -rf x").decision, "deny");
});

test("la carpeta protegida se bloquea en cualquier posición", () => {
  assert.equal(evaluar(R, "cat datos/privados/a.csv").decision, "deny");
  assert.equal(evaluar(R, "git add datos/privados").decision, "deny");
});

test("sin regla: pregunta por defecto; orden vacía también", () => {
  assert.equal(evaluar(R, "curl https://ejemplo.invalid").decision, "ask-por-defecto");
  assert.equal(evaluar(R, "  ").decision, "ask-por-defecto");
  assert.deepEqual(partes("a && b | c; d || e"), ["a", "b", "c", "d", "e"]);
});

test("limitación documentada: la regla de argumentos es frágil", () => {
  const r = { allow: ["curl https://github.com/*"], ask: [], deny: [] };
  assert.equal(evaluar(r, "curl https://github.com/x").decision, "allow");
  assert.equal(evaluar(r, "curl -L https://github.com/x").decision, "ask-por-defecto");
});
