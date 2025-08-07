---@class input_content
---@field content string The content of the input file.
---@field title string The title of the input file.
---@field path string The path of the input file.

---@class ZhnvimConfigs.FiletypesScript
---@field pattern string The blob pattern of the file type, which is used to match the file type.
---@field extension? table<string, string> Somehow some important file type could not be detected by `vim.filetype.match` defaultly, so we introduce this.
---@field script? fun(input_content:input_content): md_content The function to execute the script, which takes an input_content and returns a md_content.

---@class ZhnvimConfigs
---@field script table<string, ZhnvimConfigs.FiletypesScript> A table of filetype scripts.

---@type ZhnvimConfigs
local default_config = {
  script = {
    typst = {
      pattern = "*.typ",
      extension = { typ = "typst" },
    },
  },
}

return default_config
