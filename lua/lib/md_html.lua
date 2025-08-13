local M = {}

-- State management
local state = {
  initialized = false,
  md_to_html = nil,
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
    return package.loadlib(path, "luaopen_markdown_to_html_lib")
  end)

  if success and type(result) == "function" then
    return result
  end

  return nil
end

-- Initialize the library
function M.initialize()
  if state.initialized then
    return state.markdown_to_html ~= nil
  end

  local plugin_root = get_plugin_root()

  -- Try with different extensions based on the platform
  local lib_paths = {
    plugin_root .. "/build/markdown_to_html_lua51.dylib",
    plugin_root .. "/build/markdown_to_html_lua51.so",
    plugin_root .. "/build/markdown_to_html_lua51.dll",
    plugin_root .. "/build/markdown_to_html_jit.dylib",
    plugin_root .. "/build/markdown_to_html_jit.so",
    plugin_root .. "/build/markdown_to_html_jit.dll",
  }

  local lib_func = nil
  for _, path in ipairs(lib_paths) do
    lib_func = try_load(path)
    if lib_func then
      break
    end
  end

  if not lib_func then
    vim.notify(
      "Failed to load markdown_to_html library. Make sure you run 'make lua51' or 'make luajit' first.",
      vim.log.levels.ERROR
    )
    state.initialized = true
    return false
  end

  state.markdown_to_html = lib_func()
  state.initialized = true
  return true
end

--- Function to convert Markdown to HTML
--- @param markdown string: The Markdown text to convert
--- @return string|nil: The converted HTML string
function M.md_to_html(markdown)
  return state.markdown_to_html.md_to_html(markdown)
end

_G.md_to_html = M.md_to_html

return M
