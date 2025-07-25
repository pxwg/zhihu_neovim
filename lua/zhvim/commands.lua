local M = {}
local buf_id = require("zhvim.buf_id")
local html = require("zhvim.md_html")
local md = require("zhvim.html_md")
local sync = require("zhvim.article_sync")
local upl = require("zhvim.article_upload")
local cookies = vim.env.ZHIVIM_COOKIES or vim.g.zhvim_cookies

---Initializes a draft for the current buffer.
---@param opts table? Options for the command
local function init_draft(opts)
  if not cookies or cookies == "" then
    vim.api.nvim_echo({ { "Please set zhvim_cookies before using this command.", "ErrorMsg" } }, true, { err = true })
    return
  end

  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.api.nvim_echo(
      { { "Buffer is not saved. Please save the file before creating a draft.", "ErrorMsg" } },
      true,
      { err = true }
    )
    return
  end

  local title = vim.fn.fnamemodify(filepath, ":t:r")
  if opts and opts.fargs and #opts.fargs > 0 then
    title = opts.fargs[1]
  end
  local md_content = {
    content = content,
    title = title,
  }
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

  vim.api.nvim_command("new")
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 }) -- Set buffer as nofile
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = 0 }) -- Set buffer type to markdown
  local title = html_content.title:gsub(" - 知乎", "") or "Untitled"
  local lines = { "# " .. title, "", unpack(vim.split(html_content.content, "\n")) }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

--- Module for setting up commands
function M.setup_commands()
  vim.api.nvim_create_user_command("ZhihuDraft", init_draft, { nargs = "*", complete = "file" })
  vim.api.nvim_create_user_command("ZhihuOpen", open_draft, {})
  vim.api.nvim_create_user_command("ZhihuSync", sync_article, {})
end

return M
