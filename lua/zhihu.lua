---lazy load
local M = {
  opts = {
    ---@type Article
    article = {}
  }
}

---set up
---@param opts table
function M.setup(opts)
  -- luacheck: ignore 111 113
  ---@diagnostic disable: undefined-global
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

---override default value, only run once
function M.init()
  if M.is_init then
    return
  end
  local Article = require 'zhihu.article'.Article
  for k, v in pairs(M.opts.article) do
    Article[k] = v
  end
  M.is_init = true
end

---create autocmds
---@param augroup_id integer?
function M.create_autocmds(augroup_id)
  augroup_id = augroup_id or vim.api.nvim_create_augroup("zhihu", {})
  vim.api.nvim_create_autocmd({ "BufReadCmd", "SessionLoadPost" }, {
    pattern = "zhihu://*",
    group = augroup_id,
    callback = function()
      M.init()
      require "zhihu.nvim.callback".read_cb()
    end
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    pattern = "zhihu://*",
    group = augroup_id,
    callback = function()
      M.init()
      require "zhihu.nvim.callback".write_cb()
    end
  })
end

return M
