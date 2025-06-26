local actions = require("Otree.actions")
local state = require("Otree.state")
local M = {}

local default_config = {
  win_size = 30,
  open_on_startup = false,
  use_default_keymaps = true,
  hijack_netrw = true,
  show_hidden = false,
  show_ignore = false,
  cursorline = true,
  oil = "float",

  ignore_patterns = {},

  keymaps = {
    ["<CR>"] = "actions.select",
    ["l"] = "actions.select",
    ["h"] = "actions.close_dir",
    ["q"] = "actions.close_win",
    ["<C-h>"] = "actions.goto_parent",
    ["<C-l>"] = "actions.goto_dir",
    ["<M-h>"] = "actions.goto_home_dir",
    ["cd"] = "actions.change_home_dir",
    ["L"] = "actions.open_dirs",
    ["H"] = "actions.close_dirs",
    ["o"] = "actions.oil_dir",
    ["O"] = "actions.oil_into_dir",
    ["t"] = "actions.open_tab",
    ["v"] = "actions.open_vsplit",
    ["s"] = "actions.open_split",
    ["."] = "actions.toggle_hidden",
    ["i"] = "actions.toggle_ignore",
    ["r"] = "actions.refresh",
    ["f"] = "actions.focus_file",
    ["?"] = "actions.open_help",
  },

  tree = {
    space_after_icon = " ",
    space_after_connector = " ",
    connector_space = " ",
    connector_last = "└",
    connector_middle = "├",
    vertical_line = "│",
  },

  icons = {
    title = " ",
    default_file = "",
    default_directory = "",
    empty_dir = "",
    trash = " ",
    keymap = "⌨ ",
    oil = " ",
  },

  highlights = {
    directory = "Directory",
    file = "Normal",
    tree = "Comment",
    title = "TelescopeTitle",
    float_normal = "TelescopeNormal",
    float_border = "TelescopeBorder",
  },

  float = {
    center = true,
    width_ratio = 0.4,
    height_ratio = 0.7,
    padding = 2,
    cursorline = true,
    border = "rounded",
  },
}

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

local function check_dependencies()
  state.fd = vim.fn.executable("fd") == 1 and "fd"
    or (vim.fn.executable("fdfind") == 1 and "fdfind")
  if not state.fd then
    vim.notify("Otree: neither 'fd' nor 'fdfind' is installed", vim.log.levels.ERROR)
    return false
  end

  local ok_oil, _ = pcall(require, "oil")
  if not ok_oil then
    vim.notify("Otree: oil.nvim is required but not installed", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.setup(opts)
  if check_dependencies() ~= true then
    return
  end

  opts = opts or {}
  local user_keymaps = opts.keymaps
  local disable_default_km = (opts.use_default_keymaps == false)
  opts = vim.tbl_deep_extend("force", default_config, opts)
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
