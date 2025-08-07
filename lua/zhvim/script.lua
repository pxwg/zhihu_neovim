local util = require("zhvim.util")
local M = {}

---Execute a user-defined script and return the result, where the output is in CommonMark format.
---@param opts ZhnvimConfigs
---@param filetype string The filetype of the current buffer.
---@param content input_content The content of the input file, which is passed to the user script.
---@return md_content md_content The output of the script in CommonMark format, or nil if no script is defined for the filetype.
function M.execute_user_script(opts, filetype, content)
  local patterns = util.get_all_patterns(opts)
  local extension = util.merge_extension_table(opts)
  local filetypes = util.get_ft_by_patterns(patterns, extension)
  if not vim.tbl_contains(filetypes, filetype) then
    vim.notify("No user script defined for filetype: " .. filetype, vim.log.levels.WARN)
    return { content = "", title = "" }
  end
  local script = opts.script[filetype].script
  if not script or script == "" then
    vim.notify("No user script defined for filetype: " .. filetype, vim.log.levels.WARN)
    return { content = "", title = "" }
  end
  local md_content = script(content)
  return md_content
end

return M
