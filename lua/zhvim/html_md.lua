local M = {}

---@class md_content
---@field content_md string HTML content to be parsed
---@field title_md string Title of the HTML content

-- Helper function to get the plugin root directory
local function get_plugin_root()
  local source = debug.getinfo(2, "S").source
  local file = string.sub(source, 2) -- Remove the '@' prefix
  local dir = string.match(file, "(.*/)")

  -- Navigate up two directories: from lua/utils/ to the plugin root
  return string.gsub(dir, "lua/zhvim/$", "")
end

---Parse HTML content to extract user, article, and title information using a Python script.
---Writing to a temporary file and executing a Python script to parse the HTML.
---@param html_content string|nil HTML content to be parsed
---@return table parsed_data Parsed data containing title, content, and writer
---@return string|nil error
function M.parse_zhihu_article(html_content)
  if html_content == nil then
    vim.notify("Invalid HTML content provided.", vim.log.levels.ERROR)
    return {}, "Invalid HTML content."
  end
  local plugin_root = get_plugin_root()
  local python_script = plugin_root .. "util/parse_html.py"
  local python_executable = plugin_root .. "/.venv/bin/python"

  local temp_file = "/tmp/nvim_zhihu_html_content.html"
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to open temporary file for writing.", vim.log.levels.ERROR)
    return {}, "Failed to open temporary file."
  end
  file:write(html_content)
  file:close()

  local output = vim.fn.system({ python_executable, python_script, temp_file })

  os.remove(temp_file)

  if vim.v.shell_error ~= 0 then
    vim.notify("Python script failed with error code: " .. output, vim.log.levels.ERROR)
    return {}, "Python script execution failed: " .. output
  end

  local result = vim.fn.json_decode(output)
  if result.error then
    vim.notify("Error: " .. result.error, vim.log.levels.ERROR)
    return {}, result.error
  end

  return result, nil
end

---Convert HTML content to Markdown using a Python script.
---@param html_content string HTML content to be converted
---@return string md_content Converted Markdown content or an error message
---@return string|nil error
function M.convert_html_to_md(html_content)
  if html_content == nil then
    vim.notify("Invalid HTML content provided.", vim.log.levels.ERROR)
    return "", "Invalid HTML content."
  end
  local plugin_root = get_plugin_root()
  local python_script = plugin_root .. "util/html_md.py"
  local python_executable = plugin_root .. "/.venv/bin/python"

  local temp_file = "/tmp/nvim_html_to_md_content.html"
  local file = io.open(temp_file, "w")
  if not file then
    vim.notify("Failed to open temporary file for writing.", vim.log.levels.ERROR)
    return "", "Failed to open temporary file."
  end
  file:write(html_content)
  file:close()

  local output = vim.fn.system({ python_executable, python_script, temp_file })

  os.remove(temp_file)

  if vim.v.shell_error ~= 0 then
    vim.notify("Python script failed with error code: " .. output, vim.log.levels.ERROR)
    return "", "Python script execution failed: " .. output
  end

  return output, nil
end

return M
