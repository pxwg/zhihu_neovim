local M = {}
local buf_id = require("zhvim.buf_id")
local html = require("zhvim.md_html")
local md = require("zhvim.html_md")
local sync = require("zhvim.article_sync")
local upl = require("zhvim.article_upload")
local util = require("zhvim.util")
local cookies = vim.env.ZHIVIM_COOKIES or vim.g.zhvim_cookies
local script = require("zhvim.script")

---@param cmd_opts table? Options for the command
---@param opts ZhnvimConfigs User configs
local function init_draft(cmd_opts, opts)
  if not cookies or cookies == "" then
    vim.api.nvim_echo({ { "Please set zhvim_cookies before using this command.", "ErrorMsg" } }, true, { err = true })
    return
  end

  local buf_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.api.nvim_echo(
      { { "Buffer is not saved. Please save the file before creating a draft.", "ErrorMsg" } },
      true,
      { err = true }
    )
    return
  end
  local filetype = vim.bo.filetype
  local filetypes = util.get_ft_by_patterns(opts.patterns, opts.extension)
  local md_content = { content = "", title = "" }

  -- TODO: debug mode
  -- debug test
  -- if filetype == "html" then
  --   md_content = {
  --     content = table.concat(buf_content, "\n"),
  --     title = vim.fn.expand("%:t:r"),
  --   }
  --   upl.init_draft(md_content, cookies)
  --   return
  -- end

  if filetype ~= "markdown" and filetype ~= "md" and vim.tbl_contains(filetypes, filetype) then
    local content_string = table.concat(buf_content, "\n")
    local content_input = {
      content = content_string,
      --TODO: user script to get title
      title = vim.fn.expand("%:t:r"),
      path = filepath,
    }
    md_content = script.execute_user_script(opts, filetype, content_input)
    local content_uploaded = html.update_md_images(md_content.content, cookies)
    md_content = {
      content = content_uploaded,
      title = md_content.title or vim.fn.expand("%:t:r"),
    }
  end

  if filetype == "markdown" or filetype == "md" then
    local title, _ = util.get_markdown_title(0)
    local content = vim.api.nvim_buf_get_lines(0, 1, -1, false)
    if cmd_opts and cmd_opts.fargs and #cmd_opts.fargs > 0 then
      title = cmd_opts.fargs[1]
    end
    local content_input = table.concat(content, "\n")
    content_input = html.update_md_images(content_input, cookies)
    md_content = {
      content = content_input,
      title = title,
    }
  end
  local file_id = buf_id.check_id(filepath)
  if file_id == nil then
    local html_content, error = html.convert_md_to_html(md_content)
    if html_content and error == nil then
      local draft_id, _ = upl.init_draft(html_content, cookies)
      if draft_id then
        vim.api.nvim_echo({ { "Draft created with ID: " .. draft_id, "Msg" } }, true, {})
        buf_id.assign_id(filepath, draft_id)
      else
        vim.api.nvim_echo({ { "Failed to create draft.", "ErrorMsg" } }, true, {})
      end
    else
      vim.api.nvim_echo({ { "Failed to convert Markdown to HTML.", "ErrorMsg" } }, true, { err = true })
    end
  else
    local html_content, error = html.convert_md_to_html(md_content)
    if html_content and error == nil then
      upl.update_draft(file_id, html_content, cookies)
      vim.api.nvim_echo({ { "Draft updated with ID: " .. file_id, "Msg" } }, true, {})
    end
  end
end

--- TODO: modifiable commands to open draft by passing key 'cmd' in config
local function open_draft()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.api.nvim_echo(
      { { "Buffer is not saved. Please save the file before checking the draft ID.", "ErrorMsg" } },
      true,
      { err = true }
    )
    return
  end

  local file_id = buf_id.check_id(filepath)
  if file_id then
    vim.api.nvim_echo({ { "Draft ID: " .. file_id, "Msg" } }, true, {})
    local url = "https://zhuanlan.zhihu.com/p/" .. file_id .. "/edit"
    local sysname = vim.loop.os_uname().sysname
    if sysname == "Windows_NT" then
      vim.fn.system({ "start", url })
    elseif sysname == "Linux" then
      vim.fn.system({ "xdg-open", url })
    else
      vim.fn.system({ "open", url })
    end
  else
    vim.api.nvim_echo({ { "No draft ID found for this file.", "ErrorMsg" } }, true, {})
  end
end

local function sync_article()
  local filepath = vim.api.nvim_buf_get_name(0)
  local url_template = "https://zhuanlan.zhihu.com/p/"
  local file_id = buf_id.check_id(filepath)
  if not file_id then
    vim.api.nvim_echo({ { "No draft ID found for this file.", "ErrorMsg" } }, true, {})
    return
  end
  local url = url_template .. file_id
  local output = sync.download_zhihu_article(url, cookies)
  local html_content = md.parse_zhihu_article(output)
  html_content.content = md.convert_html_to_md(html_content.content)
  html_content.title = html_content.title:gsub(" -- 知乎$", "") or "Untitled"
  local zhihu_content = "# " .. html_content.title .. "\n\n" .. html_content.content

  local buf = vim.api.nvim_create_buf(true, true)
  vim.cmd("split")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  local existing_buf = vim.fn.bufnr("Zhihu: " .. file_id)
  if existing_buf ~= -1 then
    vim.api.nvim_buf_delete(existing_buf, { force = true })
  end
  vim.api.nvim_buf_set_name(buf, "Zhihu: " .. file_id)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(zhihu_content, "\n"))
  vim.api.nvim_set_current_buf(buf)

  if #vim.api.nvim_tabpage_list_wins(0) == 2 then
    vim.cmd("windo diffthis")
  end
end

--- Module for setting up commands
---@param opts ZhnvimConfigs Options for the commands
function M.setup_commands(opts)
  vim.api.nvim_create_user_command("ZhihuDraft", function(cmd_opts)
    init_draft(cmd_opts, opts)
  end, { nargs = "*", complete = "file" })
  vim.api.nvim_create_user_command("ZhihuOpen", open_draft, {})
  vim.api.nvim_create_user_command("ZhihuSync", sync_article, {})
end

---@param opts ZhnvimConfigs Options for the autocmds
function M.setup_autocmd(opts)
  local autocmd = vim.api.nvim_create_autocmd
  --- Set up autocmds in opts.filetype to avoid the default save mechanism of Neovim (which can disrupt inode-based file detection)
  autocmd("BufWritePre", { pattern = opts.patterns, command = "set nowritebackup" })
  autocmd("BufWritePost", { pattern = opts.patterns, command = "set writebackup" })
end

return M
