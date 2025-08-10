local ts_utils = require("nvim-treesitter.ts_utils")
local M = {}
--- TODO: Chinese characters should be supported while counting row numbers.

---Replace text in a string based on Treesitter node range.
---@param content string Original content
---@param start_row number Start row of the range
---@param start_col number Start column of the range
---@param end_row number End row of the range
---@param end_col number End column of the range
---@param new_text string New text to replace the range
---@return string Updated content
function M.replace_text(content, start_row, start_col, end_row, end_col, new_text)
  --- TODO: fix for Chinese characters
  local lines = vim.split(content, "\n", { plain = true })
  local before = lines[start_row + 1]:sub(1, start_col)
  local after = lines[end_row + 1]:sub(end_col + 1)
  -- Replace only the content inside parentheses
  lines[start_row + 1] = before .. new_text .. after
  return table.concat(lines, "\n")
end

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

--- Get all inline formulas from the current Markdown buffer using Treesitter.
--- @param bufnr number? Buffer number (default: current buffer)
--- @return table list of inline formulas with their start and end positions
function M.get_inline_formulas(bufnr)
  bufnr = bufnr or 0
  local parser = vim.treesitter.get_parser(bufnr, "latex")
  if not parser then
    vim.notify("Treesitter parser for markdown_inline is not available", vim.log.levels.ERROR)
    return {}
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  local results = {}

  -- Traverse the syntax tree to find inline_formula nodes
  local function process_node(node)
    if node:type() == "inline_formula" then
      local formula_info = {}
      for child in node:iter_children() do
        local text = vim.treesitter.get_node_text(child, bufnr)
        local start_row, start_col, end_row, end_col = child:range()
        table.insert(formula_info, {
          start_pos = { start_row + 1, start_col + 1 },
          end_pos = { end_row + 1, end_col + 1 },
          text = text,
        })
      end
      table.insert(results, formula_info)
    end
    for child in node:iter_children() do
      process_node(child)
    end
  end
  process_node(root)
  if #results == 0 then
    vim.notify("No inline formulas found in the Markdown file.", vim.log.levels.WARN)
  end

  return results
end

---Remove the leading and trailing whitespace in inline formulas in the current Markdown buffer.
---Ref: [pandoc-doc](https://pandoc.org/demo/example33/8.13-math.html): Anything between two $ characters will be treated as TeX math. The opening $ must have a non-space character immediately to its right, while the closing $ must have a non-space character immediately to its left,
---and must not be followed immediately by a digit. Thus, $20,000 and $30,000 won’t parse as math. If for some reason you need to enclose text in literal $ characters, backslash-escape them and they won’t be treated as math delimiters.
---@param bufnr number Buffer number (default: current buffer)
---@return string Updated content with whitespace removed
function M.remove_inline_formula_whitespace(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  for i = #M.get_inline_formulas(bufnr), 1, -1 do
    local formula = M.get_inline_formulas(bufnr)[i]
    local start_math, end_math = formula[1].end_pos, formula[#formula].start_pos
    local formula_node = formula[#formula - 1]
    -- Replace the text only if the start and end positions are different from the original
    -- this is the situation where the whitespace at the start and end of the inline formula is not removed
    -- e.g. $ 1 + 1 $ -> $1 + 1$
    if formula_node.start_pos[2] ~= start_math[2] or formula_node.end_pos[2] ~= end_math[2] then
      -- Remove leading whitespace before the start of the inline formula if it exists
      if start_math[2] > 1 then
        content =
          M.replace_text(content, start_math[1] - 1, start_math[2] - 2, start_math[1] - 1, start_math[2] - 1, "")
      end
    end
  end
  return content
end

---Get filetype by pattern.
---@param pattern string Pattern to match filetype e.g `*.md`
---@param extension table<string, string>? A table containing file extensions and their associated commands, e.g. `extension = { md = "Markdown" }`
---@return string|nil filetype The matched filetype or nil if not found
function M.get_ft_by_pattern(pattern, extension)
  vim.filetype.add({ extension = extension })
  local filetype = vim.filetype.match({ filename = pattern })
  return filetype
end

---Get filetypes by patterns
---HACK: Somehow some important file type could not be detected by `vim.filetype.match` defaultly, so we introduced `opts.extension` to temporarily solve this problem.
---@param pattern string[] Patterns to match filetypes e.g `{"*.md", "*.txt"}`
---@param extension table<string, string>? A table containing file extensions and their associated commands, e.g. `extension = { md = "Markdown" }`
---@return string[] filetypes A list of matched filetypes
function M.get_ft_by_patterns(pattern, extension)
  local filetypes = {}
  for _, pat in ipairs(pattern) do
    local ft = M.get_ft_by_pattern(pat, extension)
    if ft and not vim.tbl_contains(filetypes, ft) then
      table.insert(filetypes, ft)
    end
  end
  return filetypes
end

---Get absolute path from a relative path.
---@param path string
---@param base_dir string
---@return string
function M.get_absolute_path(path, base_dir)
  if string.sub(path, 1, 1) ~= "/" then
    path = base_dir .. "/" .. path
  end
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

---Get all patterns from ZhnvimConfigs
---@param config ZhnvimConfigs
---@return table<string>
function M.get_all_patterns(config)
  local patterns = {}
  for _, v in pairs(config.script) do
    if v.pattern then
      table.insert(patterns, v.pattern)
    end
  end
  return patterns
end

---Generate extension table from config
---@param config ZhnvimConfigs
---@return table
function M.merge_extension_table(config)
  local merged = {}
  for _, v in pairs(config.script) do
    if v.extension then
      for ext, filetype in pairs(v.extension) do
        merged[ext] = filetype
      end
    end
  end
  return merged
end

---Convert a table<string, string> to a valid Cookie string
---@param t table<string, string>
---@return string
function M.table_to_cookie(t)
  local cookie = {}
  for k, v in pairs(t) do
    table.insert(cookie, k .. "=" .. v)
  end
  return table.concat(cookie, "; ")
end

-- Helper function to get the plugin root directory
function M.get_plugin_root()
  local source = debug.getinfo(2, "S").source
  local file = string.sub(source, 2) -- Remove the '@' prefix
  local dir = string.match(file, "(.*/)")

  -- Navigate up two directories: from lua/utils/ to the plugin root
  return string.gsub(dir, "lua/zhvim/$", "")
end

return M
