local util = require("zhvim.util")
local M = {}

---@class upload_token
---@field access_id string
---@field access_key string
---@field access_token string
---@field access_timestamp number

---@class upload_file
---@field image_id string
---@field object_key string
---@field state number

---@class upload_response
---@field upload_vendor string
---@field upload_token upload_token
---@field upload_file upload_file

---@class html_content
---@field title string
---@field content string

---TODO: Reads a file as binary and calculates its SHA256 hash.
---@param file_path string The absolute path to the file
---@return string|nil The SHA256 hash of the file content, or nil if an error occurs
function M.read_file_and_hash(file_path)
  local sha256_cmd = "openssl dgst -md5 " .. vim.fn.shellescape(file_path) .. " | awk '{print $2}'"
  local hash = vim.fn.system(sha256_cmd):gsub("%s+", "")
  return hash
end

-- Function to infer MIME type from file extension
local function infer_mime_type(file_path)
  local ext = file_path:match("^.+(%..+)$"):lower()
  local mime_types = {
    [".jpg"] = "image/jpeg",
    [".jpeg"] = "image/jpeg",
    [".png"] = "image/png",
    [".gif"] = "image/gif",
    [".bmp"] = "image/bmp",
    [".webp"] = "image/webp",
  }
  return mime_types[ext] or "application/octet-stream" -- Default to binary stream
end

---Calculate the HMAC-SHA1 signature and return it as a base64-encoded string.
---@param access_key_secret string The secret key used for signing
---@param string_to_sign string The string to be signed
---@return string The base64-encoded signature
local function calculate_signature(access_key_secret, string_to_sign)
  local escaped_string_to_sign = string_to_sign:gsub("'", "'\\''")
  local escaped_access_key_secret = access_key_secret:gsub("'", "'\\''")
  local command = string.format(
    "printf '%s' | openssl dgst -sha1 -hmac '%s' -binary | openssl base64",
    escaped_string_to_sign,
    escaped_access_key_secret
  )
  local handle = io.popen(command)
  local signature = handle:read("*a"):gsub("%s+", "") -- Remove trailing whitespace/newlines
  handle:close()
  return signature
end

---Function to execute a curl command and return the response
---@param curl_command string command to execute
---@return string response
local function execute_curl_command(curl_command)
  local response = vim.fn.system(curl_command)
  if vim.v.shell_error ~= 0 then
    local error_message = table.concat(vim.fn.systemlist(curl_command))
    vim.notify(
      "Error executing curl command: " .. curl_command .. "\n Error message: " .. error_message,
      vim.log.levels.ERROR
    )
    return ""
  end
  return response
end

---Function to initialize a draft on Zhihu
---@param html_content html_content HTML content of the article
---@param cookies string Cookies for authentication
---@return string|nil
---@return string|nil
function M.init_draft(html_content, cookies)
  local draft_url = "https://zhuanlan.zhihu.com/api/articles/drafts"

  local draft_body = {
    title = html_content.title,
    content = html_content.content,
    delta_time = 0,
    can_reward = false,
  }

  -- Filter out illegal characters from the content
  local draft_body_json = vim.fn.json_encode(draft_body):gsub("'", "'\\''")
  local headers = {
    "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Content-Type: application/json",
    "Cookie: " .. cookies,
    "x-requested-with: fetch",
  }

  local curl_command = string.format(
    [[curl -s -X POST %s -H "%s" -H "%s" -H "%s" -H "%s" -d '%s']],
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
    vim.notify("Error generating draft.", vim.log.levels.ERROR)
    return nil, nil
  end
end

---Function to update a draft on Zhihu
---@param draft_id string ID of the draft to update
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
  local temp_file_path = "/tmp/nvim_zhihu_html_content_input.json"

  local temp_file = io.open(temp_file_path, "w")
  if temp_file then
    temp_file:write(patch_body_json)
    temp_file:close()
  else
    vim.notify("Failed to create temporary file.", vim.log.levels.ERROR)
    return
  end

  local headers = {
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Content-Type: application/json",
    "Cookie: " .. cookies,
    "x-requested-with: fetch",
  }

  local curl_command = string.format(
    [[curl -s -X PATCH %s -H "%s" -H "%s" -H "%s" -H "%s" --data-binary @%s]],
    patch_url,
    headers[1],
    headers[2],
    headers[3],
    headers[4],
    temp_file_path
  )

  local response = execute_curl_command(curl_command)

  os.remove(temp_file_path)

  if response then
    vim.notify("Updated draft successfully.", vim.log.levels.INFO)
  else
    vim.notify("Error updating draft.", vim.log.levels.ERROR)
  end
end

---Get image ID from hash using Zhihu API.
---@param img_hash string Image hash to retrieve ID for
---@param cookie string Authentication cookie for Zhihu API
---@return upload_response|nil
function M.get_image_id_from_hash(img_hash, cookie)
  local headers = {
    "Content-Type: application/json",
    "Accept-Language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
    "Cookie: " .. cookie,
  }
  local body = vim.fn.json_encode({
    image_hash = img_hash,
    source = "article",
  })

  local temp_file_path = "/tmp/nvim_zhihu_image_hash_input.json"

  -- Write the JSON body to the temporary file
  local temp_file = io.open(temp_file_path, "w")
  if temp_file then
    temp_file:write(body)
    temp_file:close()
  else
    vim.notify("Failed to create temporary file.", vim.log.levels.ERROR)
    return nil
  end

  local curl_command = string.format(
    [[curl -s -X POST https://api.zhihu.com/images -H "%s" -H "%s" -H "%s" --data-binary @%s]],
    headers[1],
    headers[2],
    headers[3],
    temp_file_path
  )

  local response = execute_curl_command(curl_command)

  os.remove(temp_file_path)

  local result = nil
  if response then
    local parsed_response = vim.fn.json_decode(response)
    result = parsed_response
    if result then
      vim.notify("Image ID retrieved successfully.", vim.log.levels.INFO)
    else
      vim.notify("Failed to parse response from Zhihu API", vim.log.levels.ERROR)
    end
  else
    vim.notify("Failed to retrieve image ID.", vim.log.levels.ERROR)
  end
  return result
end

---Generate a random hash using the system's time and a random number.
---@return string
function M.generate_random_hash()
  local os_name = vim.loop.os_uname().sysname:lower()

  local md5_command = "md5" -- Default for macOS
  if os_name == "linux" then
    md5_command = "md5sum"
  end
  local random_seed = tostring(os.time()) .. tostring(math.random())
  local handle = io.popen(string.format("echo -n '%s' | %s", random_seed, md5_command))
  if not handle then
    vim.notify("Failed to execute command: " .. md5_command, vim.log.levels.ERROR)
    return ""
  end
  local result = handle:read("*a")
  handle:close()

  return result:match("%w+")
end

-- local filepath = vim.fn.expand("~/tests/test.png")
-- local hash = M.read_file_and_hash(filepath)
-- -- local hash = M.generate_random_hash()
-- if not hash then
--   vim.notify("Failed to read or hash the file: " .. filepath, vim.log.levels.ERROR)
--   return
-- end
-- print(hash)
-- local cookie = vim.env.ZHIVIM_COOKIES or vim.g.zhvim_cookies
-- print(vim.inspect(M.get_image_id_from_hash(hash, cookie)))

---Upload an image to Zhihu and return the response
---@param image_path string Absolute path to the image
---@param upload_token upload_token Authentication token for Zhihu API
---@return boolean|nil response
function M.upload_image(image_path, upload_token)
  local mime_type = infer_mime_type(image_path)
  if not mime_type then
    vim.notify("Failed to infer MIME type for file: " .. image_path, vim.log.levels.ERROR)
    return nil
  end
  local img_hash = M.read_file_and_hash(image_path)
  local utc_date = os.date("!%a, %d %b %Y %H:%M:%S GMT")
  local ua = "aliyun-sdk-js/6.8.0 Firefox 137.0 on OS X 10.15"

  local string_to_sign = string.format(
    "PUT\n\n%s\n%s\nx-oss-date:%s\nx-oss-security-token:%s\nx-oss-user-agent:%s\n/zhihu-pics/v2-%s",
    mime_type,
    utc_date,
    utc_date,
    upload_token.access_token,
    ua,
    img_hash
  )

  local signature = calculate_signature(upload_token.access_key, string_to_sign)
  if not signature then
    vim.notify("Failed to calculate signature.", vim.log.levels.ERROR)
    return nil
  end

  local headers = {
    "User-Agent: " .. ua,
    "Accept-Encoding: gzip, deflate, br, zstd",
    "Content-Type: " .. mime_type,
    "Accept-Language: zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
    "x-oss-date: " .. utc_date,
    "x-oss-user-agent: " .. ua,
    "x-oss-security-token: " .. upload_token.access_token,
    "Authorization: OSS " .. upload_token.access_id .. ":" .. signature,
  }

  -- Prepare headers for curl command
  local curl_headers = ""
  for _, header in ipairs(headers) do
    curl_headers = curl_headers .. string.format('-H "%s" ', header)
  end

  local file = assert(io.open(image_path, "rb"))
  local binary_data = file:read("*all")
  file:close()

  local curl_command = string.format(
    [[curl -s -X PUT https://zhihu-pics-upload.zhimg.com/v2-%s \
  %s--data-binary @-]],
    img_hash,
    curl_headers
  )

  -- Sending the binary data to curl command and capturing the response
  local handle = assert(io.popen(curl_command, "w"))
  handle:write(binary_data)
  local response = handle:close()
  if response then
    return response
  else
    vim.notify("Failed to upload image: " .. image_path, vim.log.levels.ERROR)
    return nil
  end
end

---Get the image link from Zhihu API or upload it if it is not uploaded.
---@param image_path string Absolute path to the image
---@param upload_token upload_token Authentication token for Zhihu API
---@param upload_file upload_file File information for the image
---@return string|nil New image URL or nil if upload failed
function M.get_image_link(image_path, upload_token, upload_file)
  local base_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":h")
  image_path = util.get_absolute_path(image_path, base_dir)

  local img_hash = M.read_file_and_hash(image_path)
  if not img_hash then
    vim.notify("Failed to read or hash the file: " .. image_path, vim.log.levels.ERROR)
    return nil
  end
  local mime_type = infer_mime_type(image_path)
  local image_status = upload_file.state
  local url = "https://picx.zhimg.com/v2-" .. img_hash .. "." .. mime_type:match("image/(%w+)")
  if image_status == 1 then
    return url
  elseif image_status == 2 then
    local response = M.upload_image(image_path, upload_token)
    if response then
      vim.notify("Image uploaded successfully.", vim.log.levels.INFO)
      return url
    else
      vim.notify("Failed to upload image.", vim.log.levels.ERROR)
      return nil
    end
  else
    vim.notify(
      "Image upload status is unknown: " .. image_status .. ", returning the default url",
      vim.log.levels.ERROR
    )
    return url
  end
end

return M
