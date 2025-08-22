local M = {}

local KNOWN_TAGS = {
  ["%%s"] = "s",
  ["substitute"] = "substitute",
  ["s/"] = "substitute",
  ["s_flags"] = "s_flags",
  ["register"] = "registers",
  ["yank"] = "y",
  ["delete"] = "dl",
  ["visual block"] = "visual-block",
  ["macro"] = "q",
  ["fold"] = "folding",
  ["quickfix"] = "quickfix",
  ["loclist"] = "location-list",
  ["split"] = "windows",
  ["buffer"] = "buffers",
  ["marks"] = "mark-motions",
  ["search"] = "pattern-overview",
}

function M.infer_tag(q, user_map)
  local map = vim.tbl_extend("force", KNOWN_TAGS, user_map or {})
  local ql = (q or ""):lower()
  for k, tag in pairs(map) do
    if ql:find(k, 1, true) then return tag end
  end
  if ql:match(":%s*/") then
    if ql:find("flag", 1, true) or ql:find("interactive", 1, true) then
      return "s_flags"
    end
    return "substitute"
  end
  return nil
end

return M
