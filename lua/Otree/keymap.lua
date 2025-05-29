local state = require("Otree.state")
local M = {}

local function resolve_action(action_str, actions)
	if action_str:match("^actions%.") then
		local func_name = action_str:gsub("^actions%.", "")
		return actions[func_name]
	end
	return actions[action_str]
end

local function should_redirect_buffer(args)
	local curr_win = vim.api.nvim_get_current_win()
	return curr_win == state.win
		and args.buf ~= state.buf
		and vim.bo[args.buf].filetype ~= state.buf_filetype
		and vim.bo[args.buf].filetype ~= "oil"
end

local function handle_buffer_redirection(args)
	if not should_redirect_buffer(args) then
		return
	end

	local target_win = vim.fn.win_getid(vim.fn.winnr("l"))
	if not vim.api.nvim_win_is_valid(target_win) then
		return
	end

	vim.api.nvim_set_current_win(target_win)
	vim.api.nvim_win_set_buf(target_win, args.buf)

	if vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_win_set_buf(state.win, state.buf)
	end
end

local function check_last_window()
	if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
		return false
	end

	local wins = vim.api.nvim_tabpage_list_wins(0)
	local non_floating_wins = {}

	for _, win in ipairs(wins) do
		local config = vim.api.nvim_win_get_config(win)
		if config.relative == "" then
			table.insert(non_floating_wins, win)
		end
	end
	return #non_floating_wins == 1 and non_floating_wins[1] == state.win
end

local function handle_window_cleanup()
	local curr_win = vim.api.nvim_get_current_win()
	local config = vim.api.nvim_win_get_config(curr_win)

	if curr_win ~= state.win and config.relative == "" then
		vim.api.nvim_win_close(curr_win, false)
	end
end

local function check_modified_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_option(bufnr, "modified") then
			return true
		end
	end
	return false
end

local function handle_window_enter()
	if check_last_window() then
		if check_modified_buffers() then
			vim.api.nvim_buf_delete(state.buf, { force = true })
			state.win = nil
		else
			vim.cmd("silent! quit!")
		end
	else
		handle_window_cleanup()
	end
end

local function create_buffer_enter_autocmd(augroup)
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		callback = handle_buffer_redirection,
	})
end

local function create_window_enter_autocmds(augroup, buf)
	vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
		group = augroup,
		buffer = buf,
		callback = handle_window_enter,
	})
end

function M.setup_keymaps(buf)
	local actions = require("Otree.actions")

	for _, key in ipairs({ "i", "I", "a", "A", "o", "O", "c", "C", "s", "S", "r", "R" }) do
		vim.keymap.set("n", key, "<Nop>", { buffer = buf })
	end

	for key, action_str in pairs(state.keymaps) do
		local action_func = resolve_action(action_str, actions)
		if action_func then
			vim.keymap.set("n", key, action_func, { buffer = buf, nowait = true })
		else
			vim.notify("Otree: Unknown action '" .. action_str .. "' for key '" .. key .. "'", vim.log.levels.WARN)
		end
	end
end

function M.setup_buffer_autocmds(buf)
	create_buffer_enter_autocmd(state.augroup)
	create_window_enter_autocmds(state.augroup, buf)
end

return M
