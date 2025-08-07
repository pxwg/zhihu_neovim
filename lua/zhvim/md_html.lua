local lib = require("lib.md_html")
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

-- Traverse the syntax tree to find image nodes and collect changes
local function get_md_image_changes(root, bufnr, cookies)
  local changes = {}

  local function upload_image(uri)
    local file_path = vim.fn.expand(uri)
    local base_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
    file_path = util.get_absolute_path(file_path, base_dir)

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
  return changes
end

---Upload local Markdown figure to Zhihu and replace the link with the uploaded image link.
---Create a scratch buffer to fit the condition that filetype is not markdown.
---@param md_content string Markdown content to be processed
---@param cookies string Authentication cookies for Zhihu API
---@return string Updated Markdown content with new image links
function M.update_md_images(md_content, cookies)
  local bufnr = vim.api.nvim_create_buf(false, true)
  -- Set filetype to markdown to enable Treesitter
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(md_content, "\n"))

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown_inline")
  if not ok or not parser then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.notify("Treesitter parser for markdown is not available", vim.log.levels.ERROR)
    return md_content
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local changes = get_md_image_changes(root, bufnr, cookies)

  for _, change in ipairs(changes) do
    local start_row, start_col, end_row, end_col = change.node:range()
    md_content = util.replace_text(md_content, start_row, start_col, end_row, end_col, change.new_text)
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  return md_content
end

---TODO: better replace based on Treesitter node range

---Convert Markdown content to HTML satisfying zhihu structure using a Python script.
---@param md_content md_content Markdown content to be converted
---@return html_content html_content content or an error message
---@return string|nil error
function M.convert_md_to_html(md_content)
  local title = md_content.title or "Untitled"
  local content = lib.md_to_html(md_content.content or "")
  local result = {
    title = title,
    content = content,
  }

  return {
    title = result.title or "",
    content = result.content or "",
  }, nil
end

return M
