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

local function setup_oil(opts)
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
  require("oil.config").view_options.show_hidden = opts.show_hidden
end

local function setup_state(opts)
  local config_keys = {
    "show_hidden",
    "show_ignore",
    "cursorline",
    "focus_on_enter",
    "ignore_patterns",
    "keymaps",
    "win_size",
    "open_on_left",
    "tree",
    "icons",
    "float",
    "oil",
  }
  for _, key in ipairs(config_keys) do
    state[key] = opts[key]
  end
end

local function setup_highlights(opts)
  local hi = opts.highlights

  local highlights = {
    OtreeDirectory = hi.directory,
    OtreeTree = hi.tree,
    OtreeTitle = hi.title,
    OtreeFile = hi.file,
    OtreeFloatNormal = hi.float_normal,
    OtreeFloatBorder = hi.float_border,
    OtreeLinkPath = hi.link_path,
  }

  if opts.git_signs then
    highlights = vim.tbl_deep_extend("keep", highlights, {
      OtreeGitUntracked = hi.git_untracked,
      OtreeGitIgnored = hi.git_ignored,
      OtreeGitModified = hi.git_modified,
      OtreeGitAdded = hi.git_added,
      OtreeGitDeleted = hi.git_deleted,
      OtreeGitConflict = hi.git_conflict,
      OtreeGitRenamed = hi.git_renamed,
      OtreeGitCopied = hi.git_copied,
    })
  end

  if opts.lsp_signs then
    highlights = vim.tbl_deep_extend("keep", highlights, {
      OtreeLspHint = hi.lsp_hint,
      OtreeLspWarn = hi.lsp_warn,
      OtreeLspError = hi.lsp_error,
      OtreeLspInfo = hi.lsp_info,
    })
  end

  for name, target in pairs(highlights) do
    if vim.fn.hlexists(name) == 0 then
      vim.api.nvim_set_hl(0, name, { link = target })
    end
  end
end

function M.setup(opts)
  opts = opts or {}
  local user_keymaps = opts.keymaps
  opts = vim.tbl_deep_extend("force", config, opts)

  setup_oil(opts)
  setup_highlights(opts)

  if not opts.use_default_keymaps then
    opts.keymaps = user_keymaps or {}
  end

  if opts.hijack_netrw then
    hijack_netrw(opts)
  end

  if opts.git_signs then
    require("Otree.git").setup()
  end

  if opts.lsp_signs then
    require("Otree.lsp").setup()
  end

  setup_state(opts)
  vim.api.nvim_create_user_command("Otree", actions.toggle_tree, {})
  vim.api.nvim_create_user_command("OtreeFocus", actions.focus_tree, {})
  return M
end

return M
