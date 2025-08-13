local M = {}

-- State management
local state = {
  initialized = false,
  chrome_cookie = nil,
}

-- Helper function to get the plugin root directory
local function get_plugin_root()
  local source = debug.getinfo(2, "S").source
  local file = string.sub(source, 2) -- Remove the '@' prefix
  local dir = string.match(file, "(.*/)")
  return string.gsub(dir, "lua/lib/$", "")
end

-- Try to load a dynamic library
local function try_load(path)
  local success, result = pcall(function()
    return package.loadlib(path, "luaopen_chrome_cookie_lib")
  end)

  if success and type(result) == "function" then
    return result
  end

  return nil
end

-- Initialize the library
function M.initialize()
  if state.initialized then
    return state.chrome_cookie ~= nil
  end

  local plugin_root = get_plugin_root()

  -- Try with different extensions based on the platform
  local lib_paths = {
    plugin_root .. "/build/chrome_cookie_lua51.dylib",
    plugin_root .. "/build/chrome_cookie_lua51.so",
    plugin_root .. "/build/chrome_cookie_lua51.dll",
    plugin_root .. "/build/chrome_cookie_jit.dylib",
    plugin_root .. "/build/chrome_cookie_jit.so",
    plugin_root .. "/build/chrome_cookie_jit.dll",
  }

  local lib_func = nil
  for _, path in ipairs(lib_paths) do
    lib_func = try_load(path)
    if lib_func then
      break
    end
  end

  if not lib_func then
    vim.notify("Failed to load chrome_cookie library. Make sure you run `bash deploy.sh` first.", vim.log.levels.ERROR)
    state.initialized = true
    return false
  end

  state.chrome_cookie = lib_func()
  state.initialized = true
  return true
end

---Decrypt a Chrome cookie value using the provided master key.
---@param encrypted_value string The encrypted cookie value as a byte array.
---@param master_key string The Chrome master key as a byte array.
---@return string The decrypted cookie value as a UTF-8 string.
function M.decrypt_chrome_cookie_str(encrypted_value, master_key)
  return state.chrome_cookie.decrypt_chrome_cookie(encrypted_value, master_key)
end

---Get Chrome master key.
---@return string The Chrome master key as a byte array.
function M.get_chrome_master_key()
  return state.chrome_cookie.get_master_key()
end

---Get Chrome cookies.
---@param cookie_path string
---@param password string
---@return table<string, string> A table where keys are cookie names and values are cookie values.
function M.get_cookies(cookie_path, password)
  return state.chrome_cookie.get_cookies(cookie_path, password)
end

---Get Chrome password.
---@return string The Chrome password as a byte array.
function M.get_chrome_password()
  return state.chrome_cookie.get_chrome_password()
end

---Get Chrome cookies for a specific host.
---@param cookie_path string
---@param password string
---@param host string The host for which to retrieve cookies.
---@return table<string, string> A table where keys are cookie names and values are cookie values for the specified host.
function M.get_cookies_for_host(cookie_path, password, host)
  return state.chrome_cookie.get_cookies_for_host(cookie_path, password, host)
end

---Get the value of a specific cookie for a given host.
---@param cookie_path string
---@param password string
---@param host string The host for which to retrieve the cookie.
---@param name string The name of the cookie to retrieve.
---@return string The value of the specified cookie for the given host, or nil if not found.
function M.get_cookie_value(cookie_path, password, host, name)
  return state.chrome_cookie.get_cookie_value(cookie_path, password, host, name)
end

return M
