---APIs for neovim
---@diagnostic disable: undefined-global
-- luacheck: ignore 111 113
local uv = require 'luv'
local M = {}

---open a prompt for image
---for example:
---inoremap <C-L> <C-O>:lua require'zhihu.nvim'.input()<CR>
---@param prompt string?
function M.input(prompt)
  prompt = prompt or 'Enter image file path: '
  vim.ui.input({
    prompt = prompt, completion = 'file'
  }, M.on_confirm)
end

---callback for `input`
---@param input string
function M.on_confirm(input)
  if input == nil then
    return
  end
  local Image = require 'zhihu.image'.Image
  if input:sub(1, 2) == '~/' then
    input = uv.os_homedir() .. '/' .. input:sub(3)
  end
  local url = tostring(Image.from_file(input))
  if url then
    vim.api.nvim_put({ url }, "b", false, true)
  end
end

---open article's URL.
---for example:
---nnoremap <localleader>lv :lua require'zhihu.nvim'.open()<CR>
---@param id integer?
---@param question_id integer?
---@param edit boolean?
function M.open(id, question_id, edit)
  if not vim.bo.modifiable then
    edit = false
  end
  local article = { itemId = id, question_id = question_id }
  if article.itemId == nil and article.question_id == nil then
    article = vim.b.article
  end
  local Article = require 'zhihu.article'.Article
  article = Article(article)
  local url
  if article.itemId or article.question_id then
    url = article:get_url(edit)
  else
    url = vim.api.nvim_buf_get_name(0)
    if url:match "zhihu://" then
      vim.notify("run :w firstly!", vim.log.levels.WARN)
      return
    end
  end
  vim.ui.open(url)
end

return M
