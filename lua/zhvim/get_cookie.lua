local utils = require("zhvim.util")
local M = {}

---Get the Firefox cookies.sqlite path for the current user
---@return string|nil cookies_path Full path to cookies.sqlite or nil if not found
local function get_firefox_cookies_path()
  local home = os.getenv("HOME")
  if not home then
    vim.notify("Cannot get HOME environment variable", vim.log.levels.ERROR)
    return nil
  end

  local sysname = vim.loop.os_uname().sysname
  local profile_dir = nil

  if sysname == "Darwin" then
    -- macOS Firefox profile directory
    local base = home .. "/Library/Application Support/Firefox/Profiles"
    local handle = io.popen("find '" .. base .. "' -name '*.default-release' -type d 2>/dev/null")
    if handle then
      profile_dir = handle:read("*l")
      handle:close()
    end
  elseif sysname == "Linux" then
    -- Linux Firefox profile directory
    local base = home .. "/.mozilla/firefox"
    local handle = io.popen("find '" .. base .. "' -name '*.default-release' -type d 2>/dev/null")
    if handle then
      profile_dir = handle:read("*l")
      handle:close()
    end
  else
    vim.notify("Unsupported OS: " .. sysname .. ". Only macOS and Linux are supported.", vim.log.levels.ERROR)
    return nil
  end

  if profile_dir then
    return profile_dir .. "/cookies.sqlite"
  else
    vim.notify("Cannot find Firefox cookies.sqlite", vim.log.levels.ERROR)
    return nil
  end
end

---Get the Chrome Cookies file path for the current user
---@return string|nil cookies_path Full path to Cookies file or nil if not found
local function get_chrome_cookies_path()
  local home = os.getenv("HOME")
  if not home then
    vim.notify("Cannot get HOME environment variable", vim.log.levels.ERROR)
    return nil
  end

  local sysname = vim.loop.os_uname().sysname

  if sysname == "Darwin" then
    -- macOS Chrome Cookies file
    return home .. "/Library/Application Support/Google/Chrome/Default/Cookies"
  elseif sysname == "Linux" then
    -- Linux Chrome Cookies file
    return home .. "/.config/google-chrome/Default/Cookies"
  else
    vim.notify("Unsupported OS: " .. sysname .. ". Only macOS and Linux are supported.", vim.log.levels.ERROR)
    return nil
  end
end

---Get cookies path for a specified browser
---d_c0 and z_c0 are the cookies needed for Zhihu update articles
---@param browser "firefox"|"chrome" Browser name: "firefox" or "chrome"
---@return string|nil cookies_path Full path to cookies file or nil if not found
function M.get_cookies_path(browser)
  if browser == "firefox" then
    return get_firefox_cookies_path()
  elseif browser == "chrome" then
    return get_chrome_cookies_path()
  else
    vim.notify("Unsupported browser: " .. browser .. ". Only firefox and chrome are supported.", vim.log.levels.ERROR)
    return nil
  end
end

---Extract Zhihu cookies from Firefox database
---@return table<string, string> cookies Table with d_c0 and z_c0 cookies
local function get_zhihu_cookies_firefox()
  local cookies_db = get_firefox_cookies_path()
  if not cookies_db then
    return {}
  end
  local query_cmd = {
    "sqlite3",
    cookies_db,
    "SELECT name, value FROM moz_cookies WHERE host='.zhihu.com';",
  }
  local res = vim.system(query_cmd, { text = true }):wait()

  if res.code ~= 0 then
    if res.stderr and res.stderr:match("database is locked") then
      vim.notify(
        "The database is locked. Please try closing your browser and reload this plugin.",
        vim.log.levels.ERROR
      )
      return {}
    end
    vim.notify("Failed to execute sqlite3 command: " .. (res.stderr or ""), vim.log.levels.ERROR)
    return {}
  end

  local cookies = {}
  for line in (res.stdout or ""):gmatch("[^\r\n]+") do
    local name, value = line:match("^(.-)|(.+)$")
    if name and value then
      cookies[name] = value
    end
  end

  if vim.tbl_isempty(cookies) then
    if res.stdout and res.stdout:match("database is locked") then
      vim.notify(
        "The database is locked. Please try closing your browser and reload this plugin.",
        vim.log.levels.ERROR
      )
    else
      vim.notify("Failed to get Zhihu cookies, make sure you are logged in via Firefox", vim.log.levels.ERROR)
    end
  end

  return cookies
end

---Extract Zhihu cookies from Chrome database
---@return table<string, string> cookies Table with d_c0 and z_c0 cookies
local function get_zhihu_cookies_chrome()
  local cookies_db = get_chrome_cookies_path()
  if not cookies_db then
    return { d_c0 = nil, z_c0 = nil }
  end

  local d_c0_cmd = {
    "sqlite3",
    cookies_db,
    "SELECT value FROM cookies WHERE host_key='.zhihu.com' AND name='d_c0';",
  }
  local z_c0_cmd = {
    "sqlite3",
    cookies_db,
    "SELECT value FROM cookies WHERE host_key='.zhihu.com' AND name='z_c0';",
  }

  local d_c0_res = vim.system(d_c0_cmd, { text = true }):wait()
  local z_c0_res = vim.system(z_c0_cmd, { text = true }):wait()

  if d_c0_res.code ~= 0 or z_c0_res.code ~= 0 then
    if d_c0_res.stderr:match("database is locked") or z_c0_res.stderr:match("database is locked") then
      vim.notify(
        "The database is locked. Please try closing your browser and reload this plugin.",
        vim.log.levels.ERROR
      )
      return { d_c0 = "", z_c0 = "" }
    end
    vim.notify(
      "Failed to execute sqlite3 command: " .. (d_c0_res.stderr or "") .. (z_c0_res.stderr or ""),
      vim.log.levels.ERROR
    )
    return { d_c0 = "", z_c0 = "" }
  end

  local d_c0 = vim.trim(d_c0_res.stdout or "")
  local z_c0 = vim.trim(z_c0_res.stdout or "")

  if not d_c0 or not z_c0 then
    if (d_c0 and d_c0:match("database is locked")) or (z_c0 and z_c0:match("database is locked")) then
      vim.notify(
        "The database is locked. Please try closing your browser and reload this plugin.",
        vim.log.levels.ERROR
      )
    else
      vim.notify("Failed to get Zhihu cookies, make sure you are logged in via Firefox", vim.log.levels.ERROR)
    end
  end

  return { d_c0 = d_c0, z_c0 = z_c0 }
end

---Get Zhihu cookies for a specified browser
---@param browser "firefox"|"chrome" Browser name to extract cookies from
---@param opts ZhnvimConfigs Configuration options
function M.get_zhihu_cookies(browser, opts)
  local plugin_root = utils.get_plugin_root()
  local result = {}
  local cookie_str = ""
  local tmp_dir = vim.fn.tempname()
  local python_executable = plugin_root .. "/.venv/bin/python"

  --TODO: MacOS/Linux detection
  if browser == "chrome" then
    local python_script_chrome = plugin_root .. "/util/auth_chrome.py"
    local chrome_path = opts.browser["chrome"].path
    local chrome_cmd = {
      chrome_path,
      "--remote-debugging-port=" .. opts.browser["chrome"].port,
      "--user-data-dir=" .. tmp_dir,
      "--no-first-run",
      "--no-default-browser-check",
      "--homepage=about:blank",
      "--disable-default-apps",
    }
    local id = vim.fn.jobstart(chrome_cmd, { detach = true })

    local timeout = opts and opts.browser["chrome"].timeout or 10
    local url = opts and opts.browser["chrome"].init_url or "https://www.zhihu.com/"
    local port = opts and opts.browser["chrome"].port or 9222

    local script_cmd = {
      python_executable,
      python_script_chrome,
      "--timeout",
      tostring(timeout),
      "--url",
      url,
      "--port",
      tostring(port),
    }
    result = vim.system(script_cmd, { text = true }):wait()

    cookie_str = result.stdout or ""

    vim.fn.jobstop(id)
    if result.code ~= 0 then
      vim.notify("Failed to get Zhihu cookies: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return {}
    end
  end
  if browser == "firefox" then
    -- TODO: Implement Firefox cookie extraction with a similar approach instead of this
    get_zhihu_cookies_firefox()
  end
  local cookies = vim.json.decode(cookie_str)
  cookies = cookies[1]
  return cookies
end

---Load Zhihu cookies into vim.g.zhvim_cookies
---@param browser "firefox"|"chrome" Configuration table containing browser option
---@param opts ZhnvimConfigs Configuration options
function M.load_cookie(browser, opts)
  if browser == "chrome" then
    local cookies = M.get_zhihu_cookies(browser, opts)
    local cookie_str = cookies and require("zhvim.util").table_to_cookie(cookies) or nil
    if cookie_str and cookies.d_c0 ~= "" and cookies.z_c0 ~= "" then
      vim.g.zhvim_cookies = cookie_str
      vim.fn.setenv("ZHIVIM_COOKIES", cookie_str)
    else
      vim.notify(
        "Failed to get Zhihu cookies from "
          .. browser
          .. ", trying to load from environment variable `ZHIVIM_COOKIES`...",
        vim.log.levels.WARN
      )
      vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
      if not vim.g.zhvim_cookies then
        vim.notify("Could not find cookies, please set `ZHIVIM_COOKIES` environment variable.", vim.log.levels.ERROR)
      end
    end
  elseif browser == "firefox" then
    --TODO: Implement Firefox cookie extraction
  else
    vim.g.zhvim_cookies = vim.env.ZHIVIM_COOKIES
    if not vim.g.zhvim_cookies then
      vim.notify(
        "Could not find cookies, please set `ZHIVIM_COOKIES` environment variable or set `opts.browser = 'firefox'|'chrome'` to get cookies from browser.",
        vim.log.levels.ERROR
      )
    end
  end
end

return M
