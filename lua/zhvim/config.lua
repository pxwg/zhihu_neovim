local util = require("zhvim.util")

---@class input_content
---@field content string The content of the input file.
---@field title string The title of the input file.
---@field path string The path of the input file.

---@class ZhnvimConfigs.FiletypesScript
---@field pattern string The blob pattern of the file type, which is used to match the file type.
---@field extension? table<string, string> Somehow some important file type could not be detected by `vim.filetype.match` defaultly, so we introduce this.
---@field script? fun(input_content:input_content): md_content The function to execute the script, which takes an input_content and returns a md_content.

---@class ZhnvimConfigs.BrowserScript
---@field interface? boolean Whether to use the browser interface for cookie extraction. If set to `false`, it will use extract cookies from the browser database directly (which might be **unstable** for sync articles from Zhihu but valid for uploading articles).
---@field timeout? number The timeout for the browser script, in seconds.
---@field path? string The path to the browser executable. By default, it will use the system's default browser path.
---@field init_url? string The initial URL to open in the browser for cookie extraction. We recommend using your Zhihu user homepage, for example, `https://www.zhihu.com/people/bu-hui-fei-de-qi-e-71`.
---@field port? number The port to use for control browser. By default, it will use 6000 for Firefox and 9222 for Chrome.
---@field db_path? string The path to the database file for storing cookies. If not set, it will use the default path for the browser.

---@class ZhnvimConfigs
---@field script table<string, ZhnvimConfigs.FiletypesScript> A table of filetype scripts.
---@field browser? { firefox?: ZhnvimConfigs.BrowserScript, chrome?: ZhnvimConfigs.BrowserScript } The browser which has already logged in Zhihu, used to extract cookies from the browser.
---@field default_browser? "chrome"|"firefox" The default browser to use for cookie extraction. If not set, it will try chrome first.

---@type ZhnvimConfigs
local default_config = {
  script = {
    ---@type ZhnvimConfigs.FiletypesScript
    typst = {
      pattern = "*.typ",
      extension = { typ = "typst" },
    },
  },
  default_browser = "chrome", -- Default browser to use for cookie extraction, can be "firefox" or "chrome"
  browser = {
    ---@type ZhnvimConfigs.BrowserScript
    firefox = {
      interface = false,
      init_url = "https://www.zhihu.com/",
      path = util.get_browser_path("firefox") or "Unknown Firefox path",
      db_path = util.get_firefox_cookies_path() or "Unknown Firefox DB path",
    },
    ---@type ZhnvimConfigs.BrowserScript
    chrome = {
      interface = true,
      timeout = 10,
      init_url = "https://www.zhihu.com/",
      path = util.get_browser_path("chrome") or "Unknown Chrome path",
      port = 9222,
    },
  },
}

return default_config
