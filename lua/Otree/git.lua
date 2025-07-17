local state = require("Otree.state")
local M = {}

local git_icons = {
  ["!"] = { icon = "! ", hl = "OtreeGitIgnored" },
  ["?"] = { icon = "? ", hl = "OtreeGitUntracked" },
  ["M"] = { icon = "~ ", hl = "OtreeGitModified" },
  ["A"] = { icon = "+ ", hl = "OtreeGitAdded" },
  ["D"] = { icon = "- ", hl = "OtreeGitDeleted" },
  ["R"] = { icon = "> ", hl = "OtreeGitRenamed" },
  ["C"] = { icon = "= ", hl = "OtreeGitCopied" },
  ["U"] = { icon = "! ", hl = "OtreeGitConflict" },
  [" "] = { icon = "  ", hl = nil },
}

local function get_git_icon(code)
  if #code ~= 2 then
    return nil
  end

  local index_char = code:sub(1, 1)
  local worktree_char = code:sub(2, 2)

  local index_icon = git_icons[index_char] or git_icons[" "]
  local worktree_icon = git_icons[worktree_char] or git_icons[" "]

  if index_char == "U" or worktree_char == "U" or index_char == "?" or index_char == "!" then
    return { { git_icons[index_char].icon, git_icons[worktree_char].hl } }
  end

  local virt_text = {}
  if index_icon.icon:match("%S") then
    table.insert(virt_text, { index_icon.icon, index_icon.hl })
  end
  if worktree_icon.icon:match("%S") then
    table.insert(virt_text, { worktree_icon.icon, worktree_icon.hl })
  end

  if #virt_text == 0 then
    return nil
  end

  return virt_text
end

local function fetch_git_root(callback)
  vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }, function(res)
    if res.code ~= 0 or not res.stdout then
      state.git_root = nil
      callback(nil)
      return
    end
    state.git_root = res.stdout:gsub("[\r\n]+$", "")
    callback(state.git_root)
  end)
end

local function fetch_git_status(callback)
  if not state.git_root then
    callback({})
    return
  end

  vim.system(
    { "git", "-C", state.git_root, "status", "--porcelain", "--ignored" },
    { text = true },
    function(obj)
      local status_map = {}
      if obj.code == 0 and obj.stdout then
        for line in obj.stdout:gmatch("[^\r\n]+") do
          local status = line:sub(1, 2)
          local path = vim.fs.normalize(line:sub(4))
          path = path:gsub("^%s+", ""):gsub("%s+$", "")
          status_map[path] = status
        end
      end
      state.status_map = status_map
      callback(status_map)
    end
  )
end

local function add_git_info_to_folder(folder_marks, path, git_infos)
  if not git_infos then
    return
  end

  folder_marks[path] = folder_marks[path] or { _seen = {} }
  local seen = folder_marks[path]._seen

  for _, git_info in ipairs(git_infos) do
    local key = git_info[1] .. ":" .. (git_info[2] or "")
    if not seen[key] then
      table.insert(folder_marks[path], git_info)
      seen[key] = true
    end
  end
end

local function find_parent_in_tree(path_to_line, file_path, git_root)
  local path = file_path
  while path and path ~= git_root do
    if path_to_line[path] then
      return path
    end
    path = vim.fs.dirname(path)
  end
  return nil
end

function M.add_git_status_extmarks()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.buf, state.git_ns, 0, -1)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)

  local git_root = state.git_root
  local status_map = vim.deepcopy(state.status_map or {})
  if not git_root or not next(status_map) then
    return
  end

  local path_to_line = {}
  local folder_marks = {}

  for i, node in ipairs(state.nodes) do
    local rel_path = node.full_path:sub(#git_root + 2)
    path_to_line[node.full_path] = i - 1
    local status = status_map[rel_path]

    if status then
      local git_info = get_git_icon(status)
      if git_info then
        vim.api.nvim_buf_set_extmark(state.buf, state.git_ns, i - 1, -1, {
          virt_text = git_info,
          virt_text_pos = "right_align",
          hl_mode = "combine",
        })
        status_map[rel_path] = nil
      end
    end
  end

  for rel_path, status in pairs(status_map) do
    local file_path = git_root .. "/" .. rel_path
    local parent_path = find_parent_in_tree(path_to_line, file_path, git_root)

    if parent_path then
      local git_infos = get_git_icon(status)
      add_git_info_to_folder(folder_marks, parent_path, git_infos)
    end
  end

  for folder, icons in pairs(folder_marks) do
    icons._seen = nil
    local line = path_to_line[folder]
    if line then
      vim.api.nvim_buf_set_extmark(state.buf, state.git_ns, line, -1, {
        virt_text = icons,
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  end

  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)
end

function M.refresh_git_status()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  fetch_git_root(function(git_root)
    if not git_root then
      return
    end

    fetch_git_status(function()
      vim.schedule(function()
        M.add_git_status_extmarks()
      end)
    end)
  end)
end

function M.setup()
  local git_augroup = vim.api.nvim_create_augroup("OtreeGit", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = git_augroup,
    callback = M.refresh_git_status,
  })

  vim.api.nvim_create_autocmd("User", {
    group = git_augroup,
    pattern = "OtreeRender",
    callback = M.refresh_git_status,
  })
end

return M
