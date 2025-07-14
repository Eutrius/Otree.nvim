local state = require("Otree.state")
local M = {}

M.outer_win_id = nil
M.inner_win_id = nil

local function close_window_if_valid(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
  end
end

local function calculate_window_geometry(config)
  local width = vim.o.columns
  local height = vim.o.lines
  local outer_width = math.floor(width * config.width_ratio)
  local outer_height = math.floor(height * config.height_ratio)
  local col = state.open_on_left and state.win_size + 1 or width - state.win_size - outer_width - 3
  local row = 0
  if config.center then
    col = math.floor((width - outer_width) / 2)
    row = math.floor((height - outer_height) / 2)
  end

  return {
    outer_width = outer_width,
    outer_height = outer_height,
    inner_width = outer_width - config.padding * 2,
    inner_height = outer_height - config.padding * 2,
    col = col,
    row = row,
    padding = config.padding,
    border = config.border,
  }
end

local function create_outer_window(geometry)
  local outer_buf = vim.api.nvim_create_buf(false, true)

  M.outer_win_id = vim.api.nvim_open_win(outer_buf, false, {
    relative = "editor",
    width = geometry.outer_width,
    height = geometry.outer_height,
    col = geometry.col,
    row = geometry.row,
    style = "minimal",
    border = geometry.border,
    noautocmd = true,
    focusable = false,
    zindex = 1,
  })

  local winhl = string.format("Normal:%s,FloatBorder:%s", "OtreeFloatNormal", "OtreeFloatBorder")
  vim.api.nvim_win_set_option(M.outer_win_id, "winhl", winhl)
end

local function create_inner_window(geometry)
  local inner_buf = vim.api.nvim_create_buf(false, true)

  M.inner_win_id = vim.api.nvim_open_win(inner_buf, true, {
    relative = "win",
    win = M.outer_win_id,
    width = geometry.inner_width,
    height = geometry.inner_height,
    col = geometry.padding,
    row = geometry.padding,
    border = "none",
    noautocmd = true,
  })
end

local function handle_buffer_leave()
  vim.schedule(function()
    local curr = vim.api.nvim_get_current_buf()
    local curr_filetype = vim.bo[curr].filetype
    if curr_filetype == "" or curr_filetype == "oil_preview" or curr_filetype == "oil" then
      local win_config = vim.api.nvim_win_get_config(0)
      local is_floating = win_config.relative ~= ""

      if is_floating then
        return
      end
    end

    M.close_float()
    require("Otree.actions").refresh()
  end)
end

local function handle_buffer_enter(args)
  if args.file:match("^oil://") then
    require("Otree.oil").set_title(args.file:gsub("^oil://", ""), state.icons.oil)
    return
  end
  if args.file:match("^oil%-trash://") then
    require("Otree.oil").set_title(args.file:gsub("^oil%-trash://", ""), state.icons.trash)
    return
  end
  if args.file:match("^" .. state.buf_prefix) or args.file == "" then
    return
  end
  M.close_float()
  require("Otree.actions").refresh()

  local target_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == "" and win ~= state.win then
      target_win = win
      break
    end
  end

  if not target_win then
    vim.api.nvim_win_set_buf(state.win, args.buf)
    state.win = nil
    return
  end
  vim.api.nvim_set_current_win(target_win)
  vim.cmd("silent! drop " .. args.file)
end

local function setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("OtreeFloat", { clear = true })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    callback = handle_buffer_leave,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = handle_buffer_enter,
  })
end

function M.close_float()
  pcall(function()
    vim.api.nvim_clear_autocmds({ group = "OtreeFloat" })
  end)
  close_window_if_valid(M.inner_win_id)
  close_window_if_valid(M.outer_win_id)
  M.inner_win_id = nil
  M.outer_win_id = nil
end

function M.open_float(config)
  config = vim.tbl_deep_extend("force", state.float, config or {})
  local geometry = calculate_window_geometry(config)
  create_outer_window(geometry)
  create_inner_window(geometry)
  if not vim.api.nvim_win_is_valid(M.inner_win_id) then
    return false
  end
  if not vim.api.nvim_win_is_valid(M.outer_win_id) then
    return false
  end
  vim.api.nvim_win_set_option(M.inner_win_id, "cursorline", config.cursorline)
  vim.api.nvim_set_current_win(M.inner_win_id)
  setup_autocmds()
  return true
end

function M.set_title(title)
  if not M.outer_win_id or not vim.api.nvim_win_is_valid(M.outer_win_id) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(M.outer_win_id)
  vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, 1)
  vim.api.nvim_buf_set_extmark(buf, state.ns, 0, 0, {
    virt_text = { { title, "OtreeTitle" } },
  })
end

return M
