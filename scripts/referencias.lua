-- =============================================================================
-- referencias.lua: lista de referencias al final de cada unidad, además de las
-- citas al margen.
--
-- Con `citation-location: margin`, Quarto coloca cada referencia junto al texto
-- pero no genera la lista final. Este filtro procesa una COPIA del documento con
-- citeproc, extrae el bloque de la bibliografía y lo añade al final de la
-- página bajo «Referencias». Las citas originales no se tocan, de modo que el
-- margen y las tarjetas emergentes siguen funcionando.
-- Solo actúa en HTML, en páginas con citas y con citation-location: margin.
-- =============================================================================

local function es_html()
  return FORMAT == "html" or (FORMAT ~= nil and FORMAT:match("^html") ~= nil)
end

local function en_margen(meta)
  local v = meta["citation-location"]
  return v ~= nil and pandoc.utils.stringify(v) == "margin"
end

-- Las referencias cruzadas (@fig-…, @eq-…, @thm-…) también son «citas» para
-- pandoc hasta que Quarto las resuelve: se ignoran.
local prefijos = { "fig", "tbl", "eq", "sec", "thm", "lem", "cor", "prp", "cnj", "def", "exm", "exr", "lst" }
local function es_referencia_cruzada(id)
  for _, p in ipairs(prefijos) do
    if id:sub(1, #p + 1) == p .. "-" then return true end
  end
  return false
end

local function citas_reales(doc)
  local hay = false
  doc:walk({ Cite = function(c)
    for _, ci in ipairs(c.citations) do
      if not es_referencia_cruzada(ci.id) then hay = true end
    end
  end })
  return hay
end

local function dir_documento()
  local f = quarto and quarto.doc and quarto.doc.input_file or nil
  if f == nil then return nil end
  return (f:match("^(.*)[/\\][^/\\]+$"))
end

local function absolutas(meta)
  local b = meta.bibliography
  if b == nil then return nil end
  local lista = pandoc.List()
  local function agregar(x)
    local ruta = pandoc.utils.stringify(x)
    if ruta:sub(1, 1) ~= "/" then
      local base = dir_documento()
      if base ~= nil then ruta = pandoc.path.normalize(base .. "/" .. ruta) end
    end
    lista:insert(pandoc.MetaString(ruta))
  end
  if b.t == "MetaList" then
    for _, x in ipairs(b) do agregar(x) end
  else
    agregar(b)
  end
  return pandoc.MetaList(lista)
end

local function Pandoc(doc)
  if not es_html() or not en_margen(doc.meta) or not citas_reales(doc) then return nil end
  local copia = doc:clone()
  copia.meta["suppress-bibliography"] = false
  copia.meta["citation-location"] = nil
  copia.meta.bibliography = absolutas(copia.meta)
  -- quita las referencias cruzadas para que citeproc solo vea citas reales
  copia = copia:walk({ Cite = function(c)
    for _, ci in ipairs(c.citations) do
      if not es_referencia_cruzada(ci.id) then return nil end
    end
    return c.content
  end })
  local ok, procesado = pcall(pandoc.utils.citeproc, copia)
  if not ok or procesado == nil then
    io.stderr:write("AVISO referencias.lua: no se pudo generar la lista final (" .. tostring(procesado) .. ")\n")
    return nil
  end
  local refs = nil
  for _, b in ipairs(procesado.blocks) do
    if b.t == "Div" and b.identifier == "refs" then refs = b end
  end
  if refs == nil or #refs.content == 0 then
    io.stderr:write("AVISO referencias.lua: la lista de referencias salió vacía\n")
    return nil
  end
  -- Quarto vacía las listas `.references` y reutiliza los `.csl-entry` en el margen:
  -- se renombran clases e identificadores para que la lista final no se confunda con ellos.
  refs.identifier = "refs-unidad"
  refs.classes = pandoc.List({ "referencias-unidad" })
  refs.attributes = {}
  refs.content = refs.content:map(function(b)
    if b.t == "Div" then
      b.identifier = ""
      b.classes = pandoc.List({ "ref-final" })
    end
    return b
  end)
  doc.blocks:insert(pandoc.Header(2, "Referencias", pandoc.Attr("referencias-unidad", { "unnumbered" })))
  doc.blocks:insert(pandoc.Para({
    pandoc.Emph({ pandoc.Str("Son las mismas que aparecen en el margen, junto al texto.") }),
    pandoc.Space(),
    pandoc.Str("La lista completa del curso, con el estado de verificación de cada ficha, está en R5."),
  }))
  doc.blocks:insert(refs)
  return doc
end

return { { Pandoc = Pandoc } }
