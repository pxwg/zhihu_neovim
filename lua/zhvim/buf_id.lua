local M = {}

--- TODO: Support windows which do not have `stat` command
local id_file = vim.fn.stdpath("data") .. "/zhvim_buf_ids.json"

---Load IDs from the JSON file
---@return table
local function load_ids()
  local dir = vim.fn.fnamemodify(id_file, ":h")
  if not vim.fn.isdirectory(dir) then
    vim.fn.mkdir(dir, "p")
  end
  if vim.fn.filereadable(id_file) == 0 then
    vim.api.nvim_echo({ { "ID file not found, creating a new one: " .. id_file, "WarningMsg" } }, true, {})
    local file = io.open(id_file, "w")
    if file then
      file:write("{}")
      file:close()
    end
    return {}
  end
  local content = vim.fn.readfile(id_file)
  if not content or #content == 0 then
    return {}
  end
  return vim.fn.json_decode(table.concat(content, "\n")) or {}
end

---Get the inode of a file as a string
---@param filepath string
---@return string|nil
local function get_inode(filepath)
  local handle = io.popen("stat " .. filepath)
  if not handle then
    vim.notify("Failed to get inode for " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result:match("%d+")
end

---Save IDs to the JSON file
---@param ids table
local function save_ids(ids)
  local json_content = vim.fn.json_encode(ids)
  local file = io.open(id_file, "w")
  if file then
    file:write(json_content)
    file:close()
  else
    vim.notify("Failed to save IDs to file: " .. id_file, vim.log.levels.ERROR)
  end
end

---Assign an ID to a file based on its inode
---@param filepath string
---@param id string
local function assign_id(filepath, id)
  local ids = load_ids()
  local inode = get_inode(filepath)
  if not inode then
    vim.notify("Failed to get inode for " .. filepath, vim.log.levels.ERROR)
    return
  end
  ids[inode] = id
  save_ids(ids)
end

---Check if a file has an assigned ID
---@param filepath string
---@return string|nil
function M.check_id(filepath)
  local ids = load_ids()
  local inode = get_inode(filepath)
  return ids[inode] or nil
end

---Assign an ID to a file based on its inode
---@param filepath string
---@param id string
function M.assign_id(filepath, id)
  assign_id(filepath, id)
end

return M
