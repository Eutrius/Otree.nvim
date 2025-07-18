local M = {}

M.ns = vim.api.nvim_create_namespace("Otree")
M.git_ns = vim.api.nvim_create_namespace("OtreeGit")
M.lsp_ns = vim.api.nvim_create_namespace("OtreeLsp")
M.buf_prefix = "Otree://"
M.buf_filetype = "Otree"

return M
