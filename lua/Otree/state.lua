local M = {}

M.augroup = vim.api.nvim_create_augroup("OtreeGroup", { clear = true })
M.ns = vim.api.nvim_create_namespace("Otree")
M.git_ns = vim.api.nvim_create_namespace("OtreeGit")
M.buf_prefix = "Otree://"
M.buf_filetype = "Otree"

return M
