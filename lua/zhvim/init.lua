local M = {}
M.setup = function()
  local suscess = require("lib.md_html").initialize()
  if not suscess then
    vim.notify("Failed to load markdown_to_html library. Make sure you run 'make lua51' first.", vim.log.levels.ERROR)
    return
  else
    require("zhvim.commands").setup_commands()
  end
end
return M
