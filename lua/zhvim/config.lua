---@class input_content
---@field content string The content of the input file.
---@field title string The title of the input file.

---@class ZhnvimConfigs
---@field patterns string[] Filetypes to apply the commands to e.g. `patterns = {"*.md", "*.typ"}`
---@field script table<string, fun(input_content:input_content): md_content> A table containing the vim script to execute and its associated filetype, e.g. `script = { typst = your_script_function }`
---@field extension table<string, string> A table containing file extensions and their associated commands, e.g. `extension = { md = "Markdown" }`

---@type ZhnvimConfigs
local default_config = {
  patterns = { "*.typ" },
  ---Somehow some important file type could not be detected by `vim.filetype.match` defaultly, so we introduce this.
  extension = { typ = "typst" },
  script = {},
}

return default_config
