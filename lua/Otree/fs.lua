local state = require("Otree.state")
local has_mini_icons, mini_icons = pcall(require, "mini.icons")
local has_dev_icons, devicons = pcall(require, "nvim-web-devicons")
local fd = vim.fn.executable("fd") == 1 and "fd" or (vim.fn.executable("fdfind") == 1 and "fdfind")

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

local function cached_stat(path)
  if stat_cache[path] then
    return stat_cache[path]
  end
  local stat = uv.fs_lstat(path)
  if stat.type == "link" then
    local restat = uv.fs_stat(path)
    stat.type = restat.type
    stat.link = true
  end
  stat_cache[path] = stat
  return stat
end

local function get_icon(type, fullpath, filename)
  if has_mini_icons then
    return mini_icons.get(type, filename)
  end

  if type == "directory" then
    local icon = is_dir_empty(fullpath) and state.icons.empty_dir or state.icons.default_directory
    return icon, "OtreeDirectory"
  end

  if has_dev_icons then
    return devicons.get_icon(filename, nil, { default = true })
  end

  return state.icons.default_file, "OtreeFile"
end

local function make_node(full_path, base, stat)
  local rel = full_path:sub(#base + 2)
  local filename = vim.fn.fnamemodify(full_path, ":t")
  local level = rel and #rel > 0 and select(2, rel:gsub("/", "")) or 0
  local icon, icon_hl = get_icon(stat.type, full_path, filename)

  local node = {
    filename = filename,
    full_path = full_path,
    parent_path = vim.fs.dirname(full_path),
    type = stat.type,
    is_open = false,
    level = level,
    icon = icon,
    icon_hl = icon_hl,
  }

  if stat.link then
    node.link = true
    node.link_path = vim.loop.fs_realpath(full_path)
  end

  return node
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

local function get_git_ignored_set(dir)
  local ignored_set = {}
  local cmd = { "git", "status", "-s", "--ignored", "." }
  local result = vim.system(cmd, { cwd = dir, text = true }):wait()

  if result.code == 0 then
    for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
      if line:sub(1, 2) == "!!" then
        local path = vim.fs.normalize(line:sub(4))
        ignored_set[path] = true
      end
    end
  end
  return ignored_set
end

local function glob_to_lua_pattern(glob)
  local p = glob:gsub("([%(%)%.%%%+%-%?%[%^%$])", "%%%1"):gsub("%*", ".*")
  return "^" .. p .. "$"
end

local function is_in_git_repo()
  local output = vim.fn.system("git rev-parse --is-inside-work-tree")
  local err = vim.v.shell_error
  return err == 0 and output:match("true") ~= nil
end

function M.fallback_scan_dir(dir)
  local nodes = {}

  local git_ignored_set = {}
  local user_ignore_patterns = {}
  if not state.show_ignore then
    if is_in_git_repo() and vim.fn.executable("git") == 1 then
      git_ignored_set = get_git_ignored_set(dir)
    end
    for _, pattern in ipairs(state.ignore_patterns) do
      table.insert(user_ignore_patterns, glob_to_lua_pattern(pattern))
    end
  end

  local req, err = uv.fs_scandir(dir)
  if not req then
    vim.notify("Otree fallback failed: " .. tostring(err), vim.log.levels.ERROR)
    return {}
  end

  while true do
    local name, _ = uv.fs_scandir_next(req)
    if not name then
      break
    end

    if name ~= "." and name ~= ".." then
      if not state.show_hidden and name:match("^%.") then
      else
        if not state.show_ignore then
          if git_ignored_set[name] then
          else
            local ignore_match = false
            for _, lua_pattern in ipairs(user_ignore_patterns) do
              if name:match(lua_pattern) then
                ignore_match = true
                break
              end
            end
            if not ignore_match then
              local fullpath = vim.fs.normalize(dir .. "/" .. name)
              local stat = cached_stat(fullpath)
              if stat then
                table.insert(nodes, make_node(fullpath, dir, stat))
              end
            end
          end
        else
          local fullpath = vim.fs.normalize(dir .. "/" .. name)
          local stat = cached_stat(fullpath)
          if stat then
            table.insert(nodes, make_node(fullpath, dir, stat))
          end
        end
      end
    end
  end
  return sort_nodes(nodes)
end

function M.scan_dir(dir)
  dir = dir or vim.fn.getcwd()
  stat_cache = {}

  if fd and vim.fn.executable(fd) == 1 then
    local cmd = { fd, "--max-depth", "1", "-t", "f", "-t", "l", "-t", "d" }
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

    local paths = vim.system(cmd, { cwd = dir, text = true }):wait()
    if paths.code ~= 0 then
      vim.notify("Otree: failed to run fd in directory: " .. dir, vim.log.levels.ERROR)
      return {}
    end

    paths = vim.split(paths.stdout or "", "\n", { trimempty = true })
    local nodes = {}
    for _, path in ipairs(paths) do
      if path ~= dir then
        path = vim.fs.normalize(dir .. "/" .. path)
        local stat = cached_stat(path)
        if stat then
          local node = make_node(path, dir, stat)
          table.insert(nodes, node)
        end
      end
    end
    return sort_nodes(nodes)
  else
    return M.fallback_scan_dir(dir)
  end
end

return M
