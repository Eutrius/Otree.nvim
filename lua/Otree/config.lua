local M = {

  win_size = 30,
  open_on_startup = false,
  use_default_keymaps = true,
  hijack_netrw = true,
  show_hidden = false,
  show_ignore = false,
  cursorline = true,
  oil = "float",

  ignore_patterns = { "RPN.cpp" },

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
    ["p"] = "actions.print_nodes",
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

return M
