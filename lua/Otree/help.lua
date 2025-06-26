local float = require("Otree.float")
local state = require("Otree.state")
local M = {}

local function configure_buffer_options(buf)
  local buf_opts = {
    buftype = "nofile",
    bufhidden = "hide",
    swapfile = false,
    buflisted = false,
  }

  for opt, value in pairs(buf_opts) do
    vim.api.nvim_set_option_value(opt, value, { buf = buf })
  end
end

local function display_keys(buf)
  local keys = {}
  for k in pairs(state.keymaps) do
    table.insert(keys, k)
  end
  table.sort(keys)

  local lines = {}
  local highlights = {}

  local max_len = 0
  for _, k in ipairs(keys) do
    if #k > max_len then
      max_len = #k
    end
  end

  local str = "Key"
  local str_pad = string.rep(" ", max_len - #str + 2)
  table.insert(lines, string.format("%s%s -> %s", str_pad, str, "Command"))
  table.insert(highlights, {
    line = 0,
    col = 0,
    len = -1,
    hl = state.highlights.tree,
  })
  for _, k in ipairs(keys) do
    local v = state.keymaps[k]:sub(#"actions." + 1)
    local padding = string.rep(" ", max_len - #k + 2)
    local line = string.format("%s%s -> %s", padding, k, v)
    table.insert(lines, line)

    local lnum = #lines - 1
    local key_end = line:find("->") - 2

    table.insert(highlights, {
      line = lnum,
      col = 0,
      len = key_end,
      hl = state.highlights.directory,
    })
    table.insert(highlights, {
      line = lnum,
      col = key_end + 1,
      len = 2,
      hl = state.highlights.tree,
    })
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)

  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, state.ns, h.hl, h.line, h.col, h.col + h.len)
  end
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.open_help()
  local config = {
    width_ratio = 0.2,
    height_ratio = 0.7,
    center = false,
  }
  if float.open_float(config) ~= true then
    return
  end
  vim.api.nvim_win_set_config(float.inner_win_id, {
    style = "minimal",
  })
  local buf = vim.api.nvim_create_buf(false, true)
  configure_buffer_options(buf)
  display_keys(buf)
  vim.api.nvim_win_set_buf(float.inner_win_id, buf)
  float.set_title(state.icons.keymap .. " Otree Keymaps")
end
return M
