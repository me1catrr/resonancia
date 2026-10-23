-- =============================================================================
-- version_unidad.lua: indicador discreto de versión para las páginas de la vía C
--
-- Lee la entrada de la unidad en claude/_versiones.yml (cargado como metadatos
-- del proyecto, clave «versiones») y la muestra bajo el título. Solo actúa en
-- HTML y en páginas con «via: C». Si falta la entrada, falla de forma visible.
-- =============================================================================

local function txt(x)
  if x == nil then return "" end
  return pandoc.utils.stringify(x)
end

local function es_html()
  return FORMAT == "html" or (FORMAT ~= nil and FORMAT:match("^html") ~= nil)
end

function Pandoc(doc)
  if not es_html() then return nil end
  if txt(doc.meta.via) ~= "C" then return nil end
  local id = txt(doc.meta.id)
  local v = doc.meta.versiones and doc.meta.versiones[id]
  if v == nil then
    io.stderr:write("ERROR version_unidad.lua: falta la entrada «" .. id .. "» en claude/_versiones.yml\n")
    os.exit(1)
  end
  local estado = txt(v.estado)
  local clave = (estado == "verificado" and "ok") or (estado == "histórico" and "hist") or "pend"
  local partes = { "Versión " .. txt(v.version), "editada el " .. txt(v.actualizado) }
  local verif = txt(v.verificacion)
  partes[#partes + 1] = (verif ~= "") and ("comprobada el " .. verif) or "sin comprobación técnica"
  local cc = txt(v.claude_code_documentada)
  if cc ~= "" then partes[#partes + 1] = "Claude Code " .. cc .. " (doc.)" end
  partes[#partes + 1] = estado
  local rotulo = pandoc.Div(
    { pandoc.Para({ pandoc.Str(table.concat(partes, " · ")) }) },
    pandoc.Attr("", { "version-unidad", "version-" .. clave }, { role = "note" }))
  table.insert(doc.blocks, 1, rotulo)
  return doc
end
