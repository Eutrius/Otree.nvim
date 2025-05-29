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
	ignore_patterns = {},
	cursorline = true,
	keymaps = {
		["<CR>"] = "actions.on_enter",
		["l"] = "actions.on_enter",
		["h"] = "actions.on_close_dir",
		["q"] = "actions.close_win",
		["<C-h>"] = "actions.goto_parent",
		["<C-l>"] = "actions.goto_dir",
		["<M-h>"] = "actions.goto_pwd",
		["cd"] = "actions.change_pwd",
		["L"] = "actions.open_dirs",
		["H"] = "actions.close_dirs",
		["o"] = "actions.edit_dir",
		["O"] = "actions.edit_into_dir",
		["t"] = "actions.open_tab",
		["v"] = "actions.open_vsplit",
		["s"] = "actions.open_split",
		["r"] = "actions.refresh",
		["f"] = "actions.focus_file",
		["."] = "actions.toggle_hidden",
		["i"] = "actions.toggle_ignore",
	},
	tree = {
		space_after_icon = " ",
		space_after_connector = " ",
		connector_space = "  ",
		connector_last = "└─",
		connector_middle = "├─",
		vertical_line = "│",
	},
	icons = {
		title = " ",
		directory = "",
		empty_dir = "",
	},
	highlights = {
		directory = "Directory",
		file = "Normal",
		title = "TelescopeTitle",
		tree = "Comment",
		normal = "Normal",
		float_normal = "TelescopeNormal",
		float_border = "TelescopeBorder",
	},
	float = {
		width_ratio = 0.4,
		height_ratio = 0.7,
		padding = 2,
		cursorline = true,
	},
}

local function hijack_netrw(opts)
	vim.g.loaded_netrw = 1
	vim.g.loaded_netrwPlugin = 1

	vim.api.nvim_create_autocmd("VimEnter", {
		nested = true,
		callback = function()
			local args = vim.fn.argv()
			local pwd = vim.fn.getcwd()
			if #args == 0 then
				if opts.open_on_startup then
					actions.open_win(pwd)
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
				actions.open_win(pwd)
			elseif path == ".." then
				actions.open_win(pwd:match("^(.+)/[^/]+$"))
			else
				actions.open_win(pwd .. "/" .. path)
			end
		end,
	})
end

local function setup_oil(oil)
	oil.setup({
		use_default_keymaps = false,
		skip_confirm_for_simple_edits = true,
		delete_to_trash = true,
		cleanup_delay_ms = false,
		default_file_explorer = false,
		keymaps = {
			["."] = { "actions.toggle_hidden", mode = "n" },
			["t"] = { "actions.toggle_trash", mode = "n" },
		},
		view_options = {
			show_hidden = state.show_hidden,
		},
		confirmation = {
			max_width = 0.9,
			min_width = { 30 },
		},
	})
end

function M.setup(opts)
	local ok_devicons, _ = pcall(require, "nvim-web-devicons")
	if not ok_devicons then
		vim.notify("Otree: nvim-web-devicons is required but not installed", vim.log.levels.ERROR)
		return
	end

	local ok_oil, oil = pcall(require, "oil")
	if not ok_oil then
		vim.notify("Otree: oil.nvim is required but not installed", vim.log.levels.ERROR)
		return
	end

	state.fd = vim.fn.executable("fd") == 1 and "fd" or (vim.fn.executable("fdfind") == 1 and "fdfind")
	if not state.fd then
		vim.notify("Otree : neither 'fd' nor 'fdfind' is installed!", vim.log.levels.ERROR)
		return
	end

	opts = vim.tbl_deep_extend("force", default_config, opts or {})

	if not opts.use_default_keymaps then
		opts["keymaps"] = {}
	end

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
	}

	for _, key in ipairs(config_keys) do
		state[key] = opts[key]
	end

	vim.api.nvim_create_user_command("Otree", actions.toggle_tree, {})
	vim.api.nvim_create_user_command("OtreeFocus", actions.focus_tree, {})

	setup_oil(oil)
	if opts.hijack_netrw then
		hijack_netrw(opts)
	end

	return M
end

return M
