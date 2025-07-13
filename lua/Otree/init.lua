local actions = require("Otree.actions")
local config = require("Otree.config")
local state = require("Otree.state")
local M = {}

local function hijack_netrw(opts)
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  vim.api.nvim_create_autocmd("VimEnter", {
    nested = true,
    callback = function()
      local args = vim.fn.argv()
      local cwd = vim.fn.getcwd()
      if #args == 0 then
        if opts.open_on_startup then
          actions.open_win(cwd)
        end
        return
      end
      local file_flag = false
      local path = nil
      for i = 1, #args do
        if vim.fn.isdirectory(args[i]) == 1 then
          if vim.fn.bufexists(args[i]) == 1 then
            vim.cmd("bwipeout " .. vim.fn.bufnr(args[i]))
          end
          path = args[i]
        else
          file_flag = true
        end
      end
      if not file_flag then
        vim.cmd("enew")
      end
      if path == "." then
        actions.open_win(cwd)
      elseif path == ".." then
        actions.open_win(cwd:match("^(.+)/[^/]+$"))
      elseif path then
        actions.open_win(cwd .. "/" .. path)
      end
    end,
  })
end

local function setup_oil()
  local ok, _ = pcall(require, "oil")
  if not ok then
    return
  end
  if vim.fn.exists(":Oil") ~= 2 then
    require("oil").setup({
      default_file_explorer = false,
      skip_confirm_for_simple_edits = true,
      delete_to_trash = true,
      cleanup_delay_ms = false,
    })
  end
  require("oil.config").view_options.show_hidden = state.show_hidden
end

local function setup_state(opts)
  local config_keys = {
    "show_hidden",
    "show_ignore",
    "cursorline",
    "ignore_patterns",
    "keymaps",
    "win_size",
    "highlights",
    "tree",
    "icons",
    "float",
    "oil",
  }
  for _, key in ipairs(config_keys) do
    state[key] = opts[key]
  end
end

function M.setup(opts)
  opts = opts or {}
  local user_keymaps = opts.keymaps
  local disable_default_km = (opts.use_default_keymaps == false)
  opts = vim.tbl_deep_extend("force", config, opts)
  if disable_default_km then
    opts.keymaps = user_keymaps or {}
  end

  setup_state(opts)
  setup_oil()
  if opts.hijack_netrw then
    hijack_netrw(opts)
  end

  vim.api.nvim_create_user_command("Otree", actions.toggle_tree, {})
  vim.api.nvim_create_user_command("OtreeFocus", actions.focus_tree, {})

  return M
end

return M
