-- =============================================================================
-- ejercicios.lua: filtro de Quarto para los ejercicios intercalados
--
-- Convierte los divs ::: {.ejercicio tipo="…" …} en tarjetas interactivas y, solo
-- en las páginas que los contienen, inserta en línea recursos/js/ejercicios.js.
-- Atributos admitidos: tipo, respuesta, tol, unidad, multiple, texto. Los
-- renombra a data-* (lo que lee el JS). Solo actúa en HTML (no en diapositivas).
-- =============================================================================

local cuenta = 0
local tipos = { vf = true, opcion = true, numerico = true, abierta = true,
                programacion = true, investigacion = true, encuesta = true }
local atributos = { "tipo", "respuesta", "tol", "unidad", "multiple", "texto" }

local function es_html()
  return FORMAT == "html" or (FORMAT ~= nil and FORMAT:match("^html") ~= nil)
end

local function ruta_js()
  local base
  if quarto and quarto.project and quarto.project.directory then
    base = quarto.project.directory
  else
    local script = PANDOC_SCRIPT_FILE or "scripts/ejercicios.lua"
    base = (script:match("^(.*)[/\\]scripts[/\\][^/\\]+$")) or "."
  end
  return base .. "/recursos/js/ejercicios.js"
end

local function Div(el)
  if not es_html() then return nil end
  if not el.classes:includes("ejercicio") then return nil end
  local tipo = el.attributes["tipo"]
  if tipo == nil or not tipos[tipo] then
    io.stderr:write("AVISO ejercicios.lua: ejercicio sin tipo válido (" .. tostring(tipo) ..
                    ") en id=" .. tostring(el.identifier) .. "\n")
    return nil
  end
  if el.identifier == nil or el.identifier == "" then
    io.stderr:write("AVISO ejercicios.lua: ejercicio de tipo " .. tipo .. " sin id (el progreso no se podrá guardar bien)\n")
  end
  for _, a in ipairs(atributos) do
    local v = el.attributes[a]
    if v ~= nil then
      el.attributes["data-" .. a] = v
      el.attributes[a] = nil
    end
  end
  cuenta = cuenta + 1
  return el
end

local function Pandoc(doc)
  if cuenta == 0 or not es_html() then return nil end
  local f = io.open(ruta_js(), "r")
  if f == nil then
    io.stderr:write("AVISO ejercicios.lua: no encuentro " .. ruta_js() .. "\n")
    return nil
  end
  local js = f:read("*a")
  f:close()
  quarto.doc.include_text("after-body", "<script>\n" .. js .. "\n</script>")
  return nil
end

return { { Div = Div }, { Pandoc = Pandoc } }
