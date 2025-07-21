local M = {}
local buf_id = require("zhvim.buf_id")
local html = require("zhvim.md_html")
local upl = require("zhvim.article_upload")

--- Module for setting up commands in Zhnvim
function M.setup_commands()
  ---Initialize a draft on Zhihu in the Zhnvim format.
  vim.api.nvim_create_user_command("ZhnvimInitDraft", function(opts)
    local cookies = vim.env.ZHIVIM_COOKIES or vim.g.zhvim_cookies
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

    local title = opts.fargs[1] or vim.fn.fnamemodify(filepath, ":t:r")
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
  end, { nargs = "*", complete = "file" })
end

return M
