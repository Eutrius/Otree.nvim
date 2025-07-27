local fs = require("Otree.fs")
local state = require("Otree.state")
local ui = require("Otree.ui")
local oil, _ = pcall(require, "oil")
local M = {}

local function close_dir(node)
  for i, item in ipairs(state.nodes) do
    if node.full_path == item.full_path then
      local prefix = item.full_path
      while
        state.nodes[i + 1] and state.nodes[i + 1].full_path:sub(1, #prefix + 1) == prefix .. "/"
      do
        table.remove(state.nodes, i + 1)
      end
      break
    end
  end
  node.is_open = false
end

local function open_dir(node)
  local new_nodes = fs.scan_dir(node.full_path)
  if not new_nodes or next(new_nodes) == nil then
    return
  end

  local insert_index = nil
  for i, item in ipairs(state.nodes) do
    if item.full_path == node.full_path then
      insert_index = i + 1
      break
    end
  end

  if insert_index then
    for j, new_node in ipairs(new_nodes) do
      new_node.level = node.level + 1
      table.insert(state.nodes, insert_index + j - 1, new_node)
    end
  end

  node.is_open = true
end

local function open_file(mode, node)
  local target_win = nil

  local prev_win = vim.fn.win_getid(vim.fn.winnr("#"))
  if
    vim.api.nvim_win_is_valid(prev_win) and vim.api.nvim_win_get_config(prev_win).relative == ""
  then
    target_win = prev_win
  end

  if not target_win then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative == "" then
        target_win = win
        break
      end
    end
  end

  if not target_win then
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_current_win(target_win)
  local escaped_path = vim.fn.fnameescape(node.full_path)
  vim.cmd(string.format("%s %s", mode, escaped_path))
end

local function can_access_dir(node)
  if not vim.uv.fs_scandir(node.full_path) then
    vim.notify("Otree: " .. node.filename .. " is not accessible", vim.log.levels.WARN)
    return false
  end
  return true
end

local function get_node()
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  local node = state.nodes[line]
  if not node then
    return nil
  end

  if node.type == "directory" and not can_access_dir(node) then
    return nil
  end

  return node
end

function M.open_dirs()
  local node = get_node()
  if not node then
    return
  end
  for _, item in ipairs(state.nodes) do
    if
      node.parent_path == item.parent_path
      and item.type == "directory"
      and not item.is_open
      and can_access_dir(item)
    then
      open_dir(item)
    end
  end
  ui.render()
end

function M.close_dirs()
  local node = get_node()
  if not node then
    return
  end
  for _, item in ipairs(state.nodes) do
    if node.parent_path == item.parent_path and item.type == "directory" and item.is_open then
      close_dir(item)
    end
  end
  ui.render()
end

function M.select_then_close()
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  local node = get_node()
  if not node then
    return
  end
  if node.type == "directory" then
    if not node.is_open then
      open_dir(node)
      local total_line = vim.api.nvim_buf_line_count(state.buf)
      vim.api.nvim_win_set_cursor(state.win, { math.min(line + 1, total_line), 0 })
    else
      close_dir(node)
    end
    ui.render()
  elseif node.type == "file" then
    open_file("drop", node)
    M.close_win()
  end
end

function M.select()
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  local node = get_node()
  if not node then
    return
  end
  if node.type == "directory" then
    if not node.is_open then
      open_dir(node)
      local total_line = vim.api.nvim_buf_line_count(state.buf)
      vim.api.nvim_win_set_cursor(state.win, { math.min(line + 1, total_line), 0 })
    else
      close_dir(node)
    end
    ui.render()
  elseif node.type == "file" then
    open_file("drop", node)
  end
end

function M.open_tab()
  local node = get_node()
  if not node then
    return
  end
  if node.type == "file" then
    open_file("tabedit", node)
  end
end

function M.open_split()
  local node = get_node()
  if not node then
    return
  end
  if node.type == "file" then
    open_file("split", node)
  end
end

function M.open_vsplit()
  local node = get_node()
  if not node then
    return
  end
  if node.type == "file" then
    open_file("vsplit", node)
  end
end

function M.close_dir()
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  local node = get_node()
  if not node then
    return
  end

  if node.type == "directory" and node.is_open then
    close_dir(node)
    ui.render()
    vim.api.nvim_win_set_cursor(state.win, { line, 0 })
    return
  end

  if node.level ~= 0 then
    for i, item in ipairs(state.nodes) do
      if item.full_path == node.parent_path and item.type == "directory" then
        close_dir(item)
        ui.render()
        vim.api.nvim_win_set_cursor(state.win, { i, 0 })
        return
      end
    end
  end
  vim.api.nvim_win_set_cursor(state.win, { math.max(line - 1, 1), 0 })
end

function M.focus_file()
  local curr_node = get_node()
  if not curr_node then
    return
  end

  local prev_win_bufnr = vim.fn.winbufnr(vim.fn.winnr("#"))
  local target_path = vim.fn.bufname(prev_win_bufnr)
  target_path = vim.fn.fnamemodify(target_path, ":p")

  if target_path == "" or curr_node.full_path == target_path then
    return
  end

  local segments = {}
  local path = target_path
  local prev_path = ""

  while path ~= prev_path and path ~= "/" and path ~= "" do
    table.insert(segments, 1, path)
    prev_path = path
    path = vim.fn.fnamemodify(path, ":h")
  end

  if path == "/" then
    table.insert(segments, 1, "/")
  end

  for _, segment_path in ipairs(segments) do
    local path_to_node = {}
    for _, node in ipairs(state.nodes) do
      path_to_node[node.full_path] = node
    end

    local node = path_to_node[segment_path]
    if node and node.type == "directory" and not node.is_open then
      open_dir(node)
    end
  end

  for index, node in ipairs(state.nodes) do
    if node.full_path == target_path then
      M.refresh()
      vim.api.nvim_win_set_cursor(state.win, { index, 0 })
      return
    end
  end
end

function M.toggle_tree()
  if M.close_win() then
  else
    M.open_win()
  end
end

function M.focus_tree()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
  else
    M.open_win()
  end
end

function M.open_help()
  require("Otree.help").open_help()
end

function M.open_win(path)
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.cwd = path or vim.fn.getcwd()
    state.nodes = fs.scan_dir(state.cwd)
    ui.create_buffer()
    state.prev_cur_pos = nil
  end

  ui.create_window()
  if state.focus_on_tree then
  elseif state.prev_cur_pos then
    vim.api.nvim_win_set_cursor(0, state.prev_cur_pos)
  else
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end
end

function M.close_win()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    state.prev_cur_pos = vim.api.nvim_win_get_cursor(state.win)
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
    require("Otree.float").close_float()
    return true
  end
  return false
end

function M.refresh()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    local open_dirs = {}
    if state.nodes then
      for _, node in ipairs(state.nodes) do
        if node.type == "directory" and node.is_open then
          open_dirs[node.full_path] = true
        end
      end
    end
    state.nodes = fs.scan_dir(state.cwd)
    for _, node in ipairs(state.nodes) do
      if node.type == "directory" and open_dirs[node.full_path] then
        open_dir(node)
      end
    end

    ui.render()
  end
end

function M.change_home_dir()
  vim.fn.chdir(state.cwd)
  vim.notify("Otree: changed home directory to " .. state.cwd, vim.log.levels.INFO)
end

function M.goto_home_dir()
  state.prev_cur_pos = nil
  state.cwd = vim.fn.getcwd()
  state.nodes = fs.scan_dir(state.cwd)
  ui.render()
end

function M.goto_parent()
  local parent_dir = vim.fn.fnamemodify(state.cwd, ":h")
  if parent_dir ~= state.cwd then
    state.prev_cur_pos = nil
    local last_cwd = state.cwd
    local last_nodes = state.nodes
    state.cwd = parent_dir
    state.nodes = fs.scan_dir(state.cwd)
    for i, node in ipairs(state.nodes) do
      if node.full_path == last_cwd and last_nodes then
        node.is_open = true
        for j, curr in ipairs(last_nodes) do
          curr.level = curr.level + 1
          table.insert(state.nodes, i + j, curr)
        end
      end
    end
    ui.render()
  end
end

function M.goto_dir()
  local node = get_node()
  if not node then
    return
  end
  if node.type == "directory" then
    state.cwd = node.full_path
  else
    state.cwd = node.parent_path
  end
  state.prev_cur_pos = nil
  M.refresh()
end

function M.oil_dir()
  if not oil then
    return
  end
  local node = get_node()
  local path = state.cwd
  local node_index = nil
  if node then
    path = node.parent_path

    local count = 0
    for _, n in ipairs(state.nodes or {}) do
      if n.parent_path == node.parent_path then
        count = count + 1
      end
      if n.full_path == node.full_path then
        node_index = count
        break
      end
    end
  end
  require("Otree.oil").open_oil(path, node_index)
end

function M.oil_into_dir()
  if not oil then
    return
  end
  local node = get_node()
  local path = state.cwd
  if node then
    if node.type == "directory" then
      path = node.full_path
    else
      return
    end
  end
  require("Otree.oil").open_oil(path)
end

function M.toggle_hidden()
  state.prev_cur_pos = nil
  state.show_hidden = not state.show_hidden
  M.refresh()
  if not oil then
    return
  end
  require("oil").toggle_hidden()
end

function M.toggle_ignore()
  state.prev_cur_pos = nil
  state.show_ignore = not state.show_ignore
  M.refresh()
end

return M
