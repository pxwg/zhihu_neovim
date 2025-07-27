local M = {}
local html_md = require("zhvim.html_md")

--- Helper function to execute a curl command with headers
---@param url string The Zhihu article URL
---@return string|nil html_content The HTML content of the article, or nil if an error occurs
---@return string|nil error Error message if the download fails
function M.download_zhihu_article(url, cookies)
  cookies = cookies or ""
  local headers = {
    "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8 ",
    "accept-language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
    "upgrade-insecure-requests: 1",
    "sec-fetch-dest: document",
    "sec-fetch-mode: navigate",
    "sec-fetch-site: none",
    "sec-fetch-user: ?1",
    "priority: u=0, i",
    "Cookie: " .. cookies,
  }

  local curl_cmd = "curl -s -L --compressed"

  for _, header in ipairs(headers) do
    curl_cmd = curl_cmd .. ' -H "' .. header .. '"'
  end
  curl_cmd = curl_cmd .. ' "' .. url .. '"'
  local handle = io.popen(curl_cmd)
  if not handle then
    return nil, "Failed to execute curl command"
  end

  local html_content = handle:read("*a")
  local success, exit_code = handle:close()

  -- Error handling
  if not success then
    return nil, "Curl command failed with non-zero exit code"
  end
  if html_content == "" then
    return nil, "Failed to download article content or content is empty"
  end
  if html_content:match("知乎，让每一次点击都充满意义") or html_content:match("zh%-zse%-ck") then
    return nil, "Anti-crawler page returned. Valid cookies required or IP might be blocked."
  end
  if
    html_content:match(
      "有问题，就会有答案打开知乎App在「我的页」右上角打开扫一扫其他扫码方式"
    )
  then
    return nil, "Cookies are required to access the article."
  end
  if html_content:match("你似乎来到了没有知识存在的荒原") then
    return nil, "The page does not exist."
  end

  return html_content, nil
end

---Function to get md5 hash of the current buffer content.
---@param content string Content of the current buffer
---@return string md5 hash of the content
function M.get_buffer_hash(content) end

---Function to compare the current buffer content with a given hash.

return M
