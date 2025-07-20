local M = {}

local function execute_curl_command(curl_command)
  local handle = io.popen(curl_command)
  local response = handle:read("*a")
  handle:close()
  return response
end

function M.init_draft(file_path, cookies)
  local md_to_html = require("md_to_html")
  local draft_url = "https://zhuanlan.zhihu.com/api/articles/drafts"

  local file = io.open(file_path, "r")
  if not file then
    print("无法打开文件: " .. file_path)
    return
  end

  local md_content = file:read("*a")
  file:close()

  local content
  local success, err = pcall(function()
    content = md_to_html.convert_md_to_html(md_content)
  end)

  if not success then
    print("Markdown 转换为 HTML 失败: " .. err)
    return
  end

  local draft_body = {
    title = "Test",
    delta_time = 0,
    can_reward = false,
  }

  local draft_body_json = vim.fn.json_encode(draft_body)
  local headers = {
    "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Content-Type: application/json",
    "Cookie: " .. cookies,
    "x-requested-with: fetch",
  }

  local curl_command = string.format(
    [[curl -X POST %s -H "%s" -H "%s" -H "%s" -H "%s" -d '%s']],
    draft_url,
    headers[1],
    headers[2],
    headers[3],
    headers[4],
    draft_body_json
  )

  local response = execute_curl_command(curl_command)
  local draft_response = vim.fn.json_decode(response)

  if draft_response and draft_response.id then
    print("草稿创建成功，ID: " .. draft_response.id)
    return draft_response.id, content
  else
    print("草稿创建失败")
  end
end

function M.update_draft(draft_id, file_path, cookies)
  local md_to_html = require("md_to_html")
  local patch_url = string.format("https://zhuanlan.zhihu.com/api/articles/%s/draft", draft_id)

  local file = io.open(file_path, "r")
  if not file then
    print("无法打开文件: " .. file_path)
    return
  end

  local md_content = file:read("*a")
  file:close()

  local content
  local success, err = pcall(function()
    content = md_to_html.convert_md_to_html(md_content)
  end)

  if not success then
    print("Markdown 转换为 HTML 失败: " .. err)
    return
  end

  local patch_body = {
    title = "Test",
    content = content,
    table_of_contents = false,
    delta_time = 30,
    can_reward = false,
  }

  local patch_body_json = vim.fn.json_encode(patch_body)
  local headers = {
    "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Content-Type: application/json",
    "Cookie: " .. cookies,
    "x-requested-with: fetch",
  }

  local curl_command = string.format(
    [[curl -X PATCH %s -H "%s" -H "%s" -H "%s" -H "%s" -d '%s']],
    patch_url,
    headers[1],
    headers[2],
    headers[3],
    headers[4],
    patch_body_json
  )

  local response = execute_curl_command(curl_command)
  if response then
    print("草稿更新成功")
  else
    print("草稿更新失败")
  end
end

return M
