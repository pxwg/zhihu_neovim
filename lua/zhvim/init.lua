local default_config = require("zhvim.config")
local M = {}
---@param opts? ZhnvimConfigs
M.setup = function(opts)
  local suscess = require("lib.md_html").initialize()
  if not suscess then
    vim.notify("Failed to load markdown_to_html library. Make sure you run 'make lua51' first.", vim.log.levels.ERROR)
    return
  else
    local config = vim.tbl_deep_extend("force", default_config, opts or {})
    require("zhvim.commands").setup_commands(config)
    require("zhvim.commands").setup_autocmd(config)
  end
end
return M
