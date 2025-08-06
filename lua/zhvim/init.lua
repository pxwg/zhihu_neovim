local default_config = require("zhvim.config")
local M = {}
---@param opts? ZhnvimConfigs
M.setup = function(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})
  require("zhvim.commands").setup_commands(config)
  require("zhvim.commands").setup_autocmd(config)
end
return M
