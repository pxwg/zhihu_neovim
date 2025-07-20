local M = {}

--- @class html_content
--- @field title string
--- @field content string

---Function to execute a curl command and return the response
---@param curl_command string command to execute
---@return string response
local function execute_curl_command(curl_command)
  local handle = io.popen(curl_command)
  if handle == nil then
    print("Error executing curl command: " .. curl_command)
    return ""
  else
    local response = handle:read("*a")
    handle:close()
    return response
  end
end

---Function to initialize a draft on Zhihu
---@param html_content html_content HTML content of the article
---@param cookies number Cookies for authentication
---@return number|nil
---@return string|nil
function M.init_draft(html_content, cookies)
  local draft_url = "https://zhuanlan.zhihu.com/api/articles/drafts"

  local draft_body = {
    title = html_content.title,
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
    return draft_response.id, html_content.content
  else
    vim.notify("Error generating draf.", vim.log.levels.ERROR)
    return nil, nil
  end
end

---Function to update a draft on Zhihu
---@param draft_id number
---@param html_content html_content
---@param cookies number
function M.update_draft(draft_id, html_content, cookies)
  local patch_url = string.format("https://zhuanlan.zhihu.com/api/articles/%s/draft", draft_id)
  local patch_body = {
    title = html_content.title,
    content = html_content.content,
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
    vim.notify("Updated draft successfully.", vim.log.levels.INFO)
  else
    vim.notify("Error updating draft.", vim.log.levels.ERROR)
  end
end

return M
