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
---@field timeout? number The timeout for the browser script, in seconds.
---@field path? string The path to the browser executable. By default, it will use the system's default browser path.
---@field init_url? string The initial URL to open in the browser for cookie extraction. We recommend using your Zhihu user homepage, for example, `https://www.zhihu.com/people/bu-hui-fei-de-qi-e-71`.

---@class ZhnvimConfigs
---@field script table<string, ZhnvimConfigs.FiletypesScript> A table of filetype scripts.
---@field browser? table<'firefox'|'chrome',ZhnvimConfigs.BrowserScript> The browser which have alrady logged in Zhihu, which is used to extract cookies from the browser.

---@type ZhnvimConfigs
local default_config = {
  script = {
    typst = {
      pattern = "*.typ",
      extension = { typ = "typst" },
    },
  },
  browser = {
    firefox = {
      timeout = 10,
      init_url = "https://www.zhihu.com/",
      path = util.get_browser_path("firefox") or "Unknown Firefox path",
    },
    chrome = {
      timeout = 10,
      init_url = "https://www.zhihu.com/",
      path = util.get_browser_path("chrome") or "Unknown Chrome path",
    },
  },
}

return default_config
