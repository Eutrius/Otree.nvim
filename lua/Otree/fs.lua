local state = require("Otree.state")
local has_mini_icons, mini_icons = pcall(require, "mini.icons")
local has_dev_icons, devicons = pcall(require, "nvim-web-devicons")
local M = {}

local uv = vim.uv or vim.loop
local stat_cache = {}

local function is_dir_empty(path)
  local req, _ = uv.fs_scandir(path)
  if not req then
    return false
  end
  local entry = uv.fs_scandir_next(req)
  return entry == nil
end

local function get_parent_path(path)
  return path:match("^(.+)/[^/]+$")
end

local function cached_stat(path)
  if stat_cache[path] then
    return stat_cache[path]
  end
  local stat = uv.fs_stat(path)
  stat_cache[path] = stat
  return stat
end

local function get_icon(type, fullpath, filename)
  if has_mini_icons then
    return mini_icons.get(type == "directory" and "directory" or "file", filename)
  end

  if type == "directory" then
    local icon = is_dir_empty(fullpath) and state.icons.empty_dir or state.icons.default_directory
    return icon, state.highlights.directory
  end

  if has_dev_icons then
    return devicons.get_icon(filename, nil, { default = true })
  end

  return state.icons.default_file, state.highlights.file
end

local function make_node(full_path, base, type)
  local rel = full_path:sub(#base + 2)
  local filename = vim.fn.fnamemodify(full_path, ":t")
  local level = select(2, rel:gsub("/", ""))
  local icon, icon_hl = get_icon(type, full_path, filename)

  return {
    filename = filename,
    full_path = full_path,
    parent_path = get_parent_path(full_path),
    type = type,
    is_open = false,
    level = level,
    icon = icon,
    icon_hl = icon_hl,
  }
end

local function sort_nodes(nodes)
  local function compare_nodes(a, b)
    if a.type == "directory" and b.type ~= "directory" then
      return true
    elseif a.type ~= "directory" and b.type == "directory" then
      return false
    end
    return a.full_path < b.full_path
  end
  local result = {}
  for _, node in ipairs(nodes) do
    table.insert(result, node)
  end
  table.sort(result, compare_nodes)
  return result
end

function M.scan_dir(dir)
  dir = dir or vim.fn.getcwd()
  local cmd = { state.fd, "--max-depth", "1", "--absolute-path", "-t", "f", "-t", "d" }
  if state.show_hidden then
    table.insert(cmd, "--hidden")
  end
  if state.show_ignore then
    table.insert(cmd, "--no-ignore")
  else
    for _, pattern in ipairs(state.ignore_patterns) do
      table.insert(cmd, "--exclude")
      table.insert(cmd, pattern)
    end
  end
  table.insert(cmd, ".")
  table.insert(cmd, dir)
  local paths = vim.system(cmd, { cwd = dir, text = true }):wait()
  if paths.code ~= 0 then
    vim.notify("Otree: failed to run fd in directory: " .. dir, vim.log.levels.ERROR)
    return {}
  end
  paths = vim.split(paths.stdout or "", "\n", { trimempty = true })
  local nodes = {}
  for _, path in ipairs(paths) do
    if path ~= dir then
      path = vim.fs.normalize(path)
      local stat = cached_stat(path)
      if stat then
        local node = make_node(path, dir, stat.type)
        table.insert(nodes, node)
      end
    end
  end

  return sort_nodes(nodes)
end

return M
