local ts_utils = require("nvim-treesitter.ts_utils")
local M = {}

--- Get the first Markdown level-1 heading (# title) as the title.
---@param bufnr number Buffer number (default: current buffer)
---@return string|nil title The extracted title, or nil if not found
---@return integer|nil line_nr The line number of the title, or nil if not found
function M.get_markdown_title(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Ensure Treesitter is available and the buffer has Markdown filetype
  if vim.bo[bufnr].filetype ~= "markdown" then
    vim.notify("Buffer is not a Markdown file.", vim.log.levels.ERROR)
    return nil
  end

  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    vim.notify("Treesitter parser for Markdown not found.", vim.log.levels.ERROR)
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  -- Use Treesitter query to find level-1 headings
  local query = vim.treesitter.query.parse(
    "markdown",
    [[
    (atx_heading
      (atx_h1_marker)
      ((inline) @title))
    ]]
  )

  for pattern, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      if name == "title" then
        for _, node in ipairs(nodes) do
          local line_nr = node:range() -- Get the line number of the title
          return vim.treesitter.get_node_text(node, bufnr), line_nr + 1 -- Add 1 to convert to 1-based indexing
        end
      end
    end
  end

  vim.notify("No level-1 heading found in the Markdown file.", vim.log.levels.WARN)
  return vim.fn.expand("%:t:r"), 0 -- Return the file name without extension as a fallback title
end

return M
