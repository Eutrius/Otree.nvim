local float = require("Otree.float")
local state = require("Otree.state")
local M = {}

local function format_path_for_title(path)
  local cwd = state.cwd
  path = vim.fn.expand(path):gsub("//+", "/")

  if vim.startswith(path, cwd) then
    local cwd_name = vim.fn.fnamemodify(cwd, ":t")
    local relative_path = path:sub(#cwd + 2)
    return relative_path == "" and cwd_name or (cwd_name .. "/" .. relative_path)
  else
    return path:sub(2)
  end
end

function M.set_title(path, icon)
  local formatted_path = format_path_for_title(path)
  local title = icon .. formatted_path
  if state.oil == "float" then
    float.set_title(title)
  else
    require("Otree.ui").set_title(title)
  end
end

function M.open_oil(path, index)
  index = index or 1
  if state.oil == "float" then
    if float.open_float() ~= true then
      return
    end
  end
  require("oil").open(path, {}, function()
    vim.api.nvim_win_set_cursor(0, { index, 0 })
  end)
  M.set_title(path, state.icons.oil)
end

return M
