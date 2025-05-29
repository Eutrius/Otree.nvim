local state = require("Otree.state")
local oil = require("oil")
local M = {}

M.outer_win_id = nil
M.inner_win_id = nil

local function reset_window_ids()
	M.inner_win_id = nil
	M.outer_win_id = nil
end

local function close_window_if_valid(win_id)
	if win_id and vim.api.nvim_win_is_valid(win_id) then
		vim.api.nvim_win_close(win_id, true)
	end
end

local function calculate_window_geometry()
	local width = vim.o.columns
	local height = vim.o.lines
	local outer_width = math.floor(width * state.float.width_ratio)
	local outer_height = math.floor(height * state.float.height_ratio)
	local col = math.floor((width - outer_width) / 2)
	local row = math.floor((height - outer_height) / 2)

	return {
		outer_width = outer_width,
		outer_height = outer_height,
		inner_width = outer_width - state.float.padding * 2,
		inner_height = outer_height - state.float.padding * 2,
		col = col,
		row = row,
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
		border = "rounded",
		noautocmd = true,
		focusable = false,
	})

	local winhl =
		string.format("Normal:%s,FloatBorder:%s", state.highlights.float_normal, state.highlights.float_border)
	vim.api.nvim_win_set_option(M.outer_win_id, "winhl", winhl)
end

local function create_inner_window(geometry)
	local inner_buf = vim.api.nvim_create_buf(false, true)

	M.inner_win_id = vim.api.nvim_open_win(inner_buf, true, {
		relative = "win",
		win = M.outer_win_id,
		width = geometry.inner_width,
		height = geometry.inner_height,
		col = state.float.padding,
		row = state.float.padding,
		style = "minimal",
		border = "none",
		noautocmd = true,
	})
end

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

local function configure_window_options()
	vim.api.nvim_win_set_option(M.inner_win_id, "cursorline", state.float.cursorline)
end

local function setup_buffer_keymaps(buf)
	local close_keys = { "q", "<Esc>" }

	for _, key in ipairs(close_keys) do
		vim.keymap.set("n", key, M._close, {
			buffer = buf,
			noremap = true,
		})
	end
	vim.keymap.set("n", "<CR>", function()
		vim.cmd("w")
	end, {
		buffer = buf,
		noremap = true,
	})
end

local function handle_buffer_leave(args)
	local buff = args.buf
	if vim.bo[buff].filetype ~= "oil" then
		return
	end

	vim.schedule(function()
		local curr = vim.api.nvim_get_current_buf()
		local curr_filetype = vim.bo[curr].filetype

		if curr_filetype == "oil_preview" or curr_filetype == "oil" then
			return
		end

		if vim.api.nvim_buf_is_valid(buff) then
			M._close()
		end
	end)
end

local function setup_buffer_autocmds(buf)
	local augroup_id = vim.api.nvim_create_augroup("OFloatingWindow", { clear = true })

	vim.api.nvim_create_autocmd("BufLeave", {
		group = augroup_id,
		buffer = buf,
		callback = handle_buffer_leave,
	})
end

local function reset_show_hidden()
	if require("oil.config").view_options.show_hidden ~= state.show_hidden then
		oil.toggle_hidden()
	end
end

function M._close()
	close_window_if_valid(M.inner_win_id)
	close_window_if_valid(M.outer_win_id)
	reset_window_ids()
	reset_show_hidden()
	vim.api.nvim_win_set_buf(state.win, state.buf)
	require("Otree.actions").refresh()
end

function M._create_windows()
	if M.outer_win_id and vim.api.nvim_win_is_valid(M.outer_win_id) then
		return
	end

	local geometry = calculate_window_geometry()
	create_outer_window(geometry)
	create_inner_window(geometry)
end

function M._update_title(path)
	-- if not M.outer_win_id or not vim.api.nvim_win_is_valid(M.outer_win_id) then
	-- 	return
	-- end
	local formatted_path = format_path_for_title(path)
	vim.wo[state.win].winbar = "%#" .. state.highlights.title .. "#" .. state.icons.title .. formatted_path

	--
	-- local buf = vim.api.nvim_win_get_buf(state.win)
	-- vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, 1)
	-- vim.api.nvim_buf_set_extmark(buf, state.ns, 0, 0, {
	-- 	virt_text = { { title_text, state.highlights.title } },
	-- })
end

function M.open_float(path)
	-- M._create_windows()
	--
	-- if not vim.api.nvim_win_is_valid(M.inner_win_id) then
	-- 	return
	-- end
	--
	-- vim.api.nvim_set_current_win(M.inner_win_id)
	-- vim.api.nvim_set_current_win(state.win)

	oil.open(path)
	M._update_title(path)
	vim.api.nvim_set_option_value("number", false, { scope = "local", win = state.win })
	-- configure_window_options()

	local buf = vim.api.nvim_get_current_buf()
	setup_buffer_keymaps(buf)
	-- setup_buffer_autocmds(buf)
end

return M
