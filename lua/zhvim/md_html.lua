local upl = require("zhvim.article_upload")
local util = require("zhvim.util")
local M = {}

---@class md_content
---@field content string Markdown content to be converted to HTML
---@field title string Title of the Markdown content

-- Helper function to get the plugin root directory
local function get_plugin_root()
  local source = debug.getinfo(2, "S").source
  local file = string.sub(source, 2) -- Remove the '@' prefix
  local dir = string.match(file, "(.*/)")

  -- Navigate up two directories: from la/utils/ to the plugin root
  return string.gsub(dir, "lua/zhvim/$", "")
end

---Upload local Markdown figure to Zhihu and replace the link with the uploaded image link.
---@param md_content string Markdown content to be processed
---@param cookies string Authentication cookies for Zhihu API
---@return string Updated Markdown content with new image links
function M.update_md_images(md_content, cookies)
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr, "markdown_inline")
  if not parser then
    vim.notify("Treesitter parser for markdown is not available", vim.log.levels.ERROR)
    return md_content
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  local changes = {}

  -- Helper function to upload an image and return the new URL
  local function upload_image(uri)
    local file_path = vim.fn.expand(uri)
    local file_exists = vim.fn.filereadable(file_path) == 1
    if not file_exists then
      vim.notify("File does not exist: " .. file_path, vim.log.levels.ERROR)
      return uri
    end
    local img_hash = upl.read_file_and_hash(file_path)
    if not img_hash then
      return uri
    end
    local upload_result = upl.get_image_id_from_hash(img_hash, cookies)
    if not upload_result then
      return uri
    end
    local result = upl.get_image_link(file_path, upload_result.upload_token, upload_result.upload_file)
    if not result then
      return uri
    end
    return result
  end

  -- Traverse the syntax tree to find image nodes
  local function process_node(node)
    if node:type() == "image" then
      local url_node = nil
      for child in node:iter_children() do
        if child:type() == "link_destination" then
          url_node = child
          break
        end
      end
      local url = url_node and vim.treesitter.get_node_text(url_node, bufnr) or nil
      if url then
        local new_url = upload_image(url)
        table.insert(changes, {
          node = url_node,
          new_text = new_url,
        })
      end
    end
    for child in node:iter_children() do
      process_node(child)
    end
  end
  process_node(root)
  -- Apply changes to the content
  for _, change in ipairs(changes) do
    local start_row, start_col, end_row, end_col = change.node:range()
    md_content = util.replace_text(md_content, start_row - 1, start_col, end_row - 1, end_col, change.new_text)
  end
  return md_content
end

---TODO: better replace based on Treesitter node range

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

  -- print(result.content)
  return {
    title = result.title or "",
    content = result.content or "",
  }, nil
end

return M
