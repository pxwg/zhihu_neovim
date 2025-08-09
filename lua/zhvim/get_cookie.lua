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
    return { d_c0 = nil, z_c0 = nil }
  end

  local d_c0_cmd = {
    "sqlite3",
    cookies_db,
    "SELECT value FROM moz_cookies WHERE host='.zhihu.com' AND name='d_c0';",
  }
  local z_c0_cmd = {
    "sqlite3",
    cookies_db,
    "SELECT value FROM moz_cookies WHERE host='.zhihu.com' AND name='z_c0';",
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
function M.get_zhihu_cookies(browser)
  if browser == "firefox" then
    return get_zhihu_cookies_firefox()
  elseif browser == "chrome" then
    return get_zhihu_cookies_chrome()
  else
    vim.notify("Unsupported browser: " .. browser .. ". Only firefox and chrome are supported.", vim.log.levels.ERROR)
    return { d_c0 = "", z_c0 = "" }
  end
end

return M
