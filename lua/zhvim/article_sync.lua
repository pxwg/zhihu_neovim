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

local cookies =
  "_xsrf=n307Z5jPjVcthUiEKqabhAT7U0UpZd72; _zap=b09c145d-f4f8-46fc-b9e6-42172f97ca78; HMACCOUNT=796EE3D1B1BEA346; d_c0=auITCzAONhqPTvpcxHFNaA7ktThZAKXBngw=|1743084196; __snaker__id=ftfNnECCJyeK2Vz6; o_act=login; ref_source=other_https://www.zhihu.com/signin; expire_in=15551999; q_c1=c471a4d3aaae46a79290af7c7a5b77c5|1743093258000|1743093258000; edu_user_uuid=edu-v1|3a75a380-c793-4622-afb5-2c85755887c7; Hm_lvt_98beee57fd2ef70ccdd5ca52b9740c49=1750902956; z_c0=2|1:0|10:1751356940|4:z_c0|80:MS4xdzAwSUVRQUFBQUFtQUFBQVlBSlZUWWYxU1dtMWlGMXlOQkRaQ1Y4SnlQOXN3cTg4XzV1eXdnPT0=|675b0511150a254b5e4f58f2adfe495b4ebc9e3fd950ef248f715c9c12771462; __zse_ck=004_H=pGyeNh92bOyOFTg6Hbv9uvILL8BjM3QTljitoTYvu0hVMsd8VQ6iNM=ptk68Hht2BxFKn9HqH0oj3HCZvZX1KEXvv26kvE4ycd6qpT3SrpsUQ7ckMyPepdSt95ADJU-RfMQI80MVvaQysGjw2pBy9bVrcPn6wRqUVcotZDqgSrz4cWNzHjMvHsmloNYWosGo2zael/q9+S8w3WdM7Zw2FTm3EaPlC/yp2LCtv2uCi8dMj489LgipuNi3EEllfVS; SESSIONID=AK2fFv67koUTWgzQRofYdOhh3D1PoxOKEMld7duEvWS; JOID=UFASAEkP3sm--wFwN-Rz3wzODkwoRJr_2b19SQRku5PurWYAadfsT9fxBHsyk6Wc2OjXjCR1FL0ZDeurLfIaIO8=; osd=VVAdBE0K3sa6_wRwOOB32gzBCkgtRJX73bh9RgBgvpPhqWIFadjoS9LxC382lqWT3OzSjCtxELgZAu-vKPIVJOs=; tst=r; BEC=738c6d0432e7aaf738ea36855cdce904; Hm_lpvt_98beee57fd2ef70ccdd5ca52b9740c49=1753432565"

---Function to get md5 hash of the current buffer content.
---@param content string Content of the current buffer
---@return string md5 hash of the content
function M.get_buffer_hash(content) end

---Function to compare the current buffer content with a given hash.

return M
