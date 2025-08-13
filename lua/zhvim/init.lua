local default_config = require("zhvim.config")
local M = {}
---@param opts? ZhnvimConfigs
M.setup = function(opts)
  local suscess = require("lib.md_html").initialize() and require("lib.chrome_cookie").initialize()
  if not suscess then
    return
  else
    local config = vim.tbl_deep_extend("force", default_config, opts or {})
    local err_browser_chrome = false
    local err_browser_firefox = false
    if config.browser["chrome"].path == "Unknown Chrome path" then
      vim.notify(
        "You have not set up the browsers path, please set it in `vim.g.zhvim_browser_chrome_path` or `vim.g.zhvim_browser_firefox_path`.",
        vim.log.levels.WARN
      )
      err_browser_chrome = true
    end
    if config.browser["firefox"].path == "Unknown Firefox path" then
      vim.notify(
        "You have not set up the browsers path, please set it in `vim.g.zhvim_browser_firefox_path` or `vim.g.zhvim_browser_chrome_path`.",
        vim.log.levels.WARN
      )
      err_browser_firefox = true
    end

    if vim.env.ZHIVIM_COOKIES and vim.env.ZHIVIM_COOKIES ~= "" then
      vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
    else
      vim.notify(
        "Failed to load Zhihu cookies, try to run `:ZhihuAuth` and reload plugin, or set up your cookie in `vim.g.zhvim_cookies`.",
        vim.log.levels.WARN
      )
    end

    if config.browser["firefox"].db_path == "Unknown Firefox DB path" then
      vim.notify(
        "You have not set up the Firefox database path, please set it in `vim.g.zhvim_browser_firefox_db_path`.",
        vim.log.levels.WARN
      )
      err_browser_firefox = true
    end
    ---@class ZhnvimErrBrowser
    ---@field chrome boolean Whether the Chrome browser has an error in configuration.
    ---@field firefox boolean Whether the Firefox browser has an error in configuration.
    ---@type ZhnvimErrBrowser
    local err_browser = {
      chrome = err_browser_chrome,
      firefox = err_browser_firefox,
    }

    require("zhvim.commands").setup_commands(config, err_browser)
    require("zhvim.commands").setup_autocmd(config)
  end
end
return M
