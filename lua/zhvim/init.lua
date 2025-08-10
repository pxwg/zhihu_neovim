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

    if vim.env.ZHIVIM_COOKIES and vim.env.ZHIVIM_COOKIES ~= "" then
      vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
    else
      vim.notify(
        "Failed to load Zhihu cookies, try to run `:ZhihuAuth` and reload plugin, or set up your cookie in `vim.g.zhvim_cookies`.",
        vim.log.levels.WARN
      )
    end

    require("zhvim.commands").setup_commands(config)
    require("zhvim.commands").setup_autocmd(config)
  end
end
return M
