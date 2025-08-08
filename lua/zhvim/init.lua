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

    if config.browser == "firefox" then
      local cookies = require("zhvim.get_cookie").get_zhihu_cookies(config.browser)
      if not cookies or cookies.d_c0 == "" or cookies.z_c0 == "" then
        vim.notify("Failed to get Zhihu cookies from Firefox", vim.log.levels.ERROR)
        vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES or ""
      end
      local cookie_str = require("zhvim.util").table_to_cookie(cookies)
      if cookie_str then
        vim.g.zhvim_cookies = cookie_str
      else
        vim.notify("Failed to get Zhihu cookies from Firefox", vim.log.levels.ERROR)
        vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
      end
    end

    require("zhvim.commands").setup_commands(config)
    require("zhvim.commands").setup_autocmd(config)
  end
end
return M
