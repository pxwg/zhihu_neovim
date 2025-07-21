local M = {}

---@class md_content
---@field content string Markdown content to be converted to HTML
---@field title string Title of the Markdown content

-- Helper function to get the plugin root directory
local function get_plugin_root()
  local source = debug.getinfo(2, "S").source
  local file = string.sub(source, 2) -- Remove the '@' prefix
  local dir = string.match(file, "(.*/)")

  -- Navigate up two directories: from lua/utils/ to the plugin root
  return string.gsub(dir, "lua/zhvim/$", "")
end

---Convert Markdown content to HTML satisfying zhihu structure using a Python script.
---@param md_content md_content Markdown content to be converted
---@return html_content html_content content or an error message
---@return string|nil error
function M.convert_md_to_html(md_content)
  local plugin_root = get_plugin_root()
  local python_script = plugin_root .. "util/md_html.py"
  local python_executable = plugin_root .. "/.venv/bin/python"

  local input_data = vim.fn.json_encode({ markdown = md_content })

  local output = vim.fn.system({ python_executable, python_script }, input_data)

  if vim.v.shell_error ~= 0 then
    vim.notify("Python script failed with error code: " .. output, vim.log.levels.ERROR)
    return { title = "", content = "" }, "Python script execution failed: " .. output
  end

  local result = vim.fn.json_decode(output)
  if result.error then
    vim.notify("Error: " .. result.error, vim.log.levels.ERROR)
    return { title = "", content = "" }, result.error
  end

  return {
    title = result.title or "",
    content = result.content or "",
  }, nil
end

return M
