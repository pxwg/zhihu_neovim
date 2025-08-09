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
      local cookie_str = cookies and require("zhvim.util").table_to_cookie(cookies) or nil
      if cookie_str and cookies.d_c0 ~= "" and cookies.z_c0 ~= "" then
        vim.g.zhvim_cookies = cookie_str
      else
        vim.notify(
          "Failed to get Zhihu cookies from Firefox, trying environment variable ZHIVIM_COOKIES.",
          vim.log.levels.WARN
        )
        vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
        if not vim.g.zhvim_cookies then
          vim.notify(
            "Could not find cookies, please set ZHIVIM_COOKIES environment variable or set opts.browser = 'firefox' to use Firefox cookies.",
            vim.log.levels.ERROR
          )
        end
      end
    else
      vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
      if not vim.g.zhvim_cookies then
        vim.notify(
          "Could not find cookies, please set ZHIVIM_COOKIES environment variable or set opts.browser = 'firefox' to use Firefox cookies.",
          vim.log.levels.ERROR
        )
      end
    end

    require("zhvim.commands").setup_commands(config)
    require("zhvim.commands").setup_autocmd(config)
  end
end
return M
