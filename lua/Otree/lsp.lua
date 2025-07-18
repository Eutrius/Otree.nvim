local state = require("Otree.state")
local M = {}

local diagnostic_hl = {
  [vim.diagnostic.severity.ERROR] = "OtreeLspError",
  [vim.diagnostic.severity.WARN] = "OtreeLspWarn",
  [vim.diagnostic.severity.INFO] = "OtreeLspInfo",
  [vim.diagnostic.severity.HINT] = "OtreeLspHint",
}

local function get_diagnostic_icon(severity)
  local icon = "• "
  local hl = diagnostic_hl[severity]
  if not hl then
    return nil
  end
  return { { icon, hl } }
end

local function get_highest_severity_diagnostic(diagnostics)
  if #diagnostics == 0 then
    return nil
  end
  table.sort(diagnostics, function(a, b)
    return a.severity < b.severity
  end)
  return diagnostics[1]
end

local function add_diagnostic_info_to_folder(folder_marks, path, severity)
  if not severity then
    return
  end

  if not folder_marks[path] or severity < folder_marks[path].severity then
    folder_marks[path] = {
      severity = severity,
      icon = get_diagnostic_icon(severity),
    }
  end
end

local function find_parent_in_tree(path_to_line, file_path, root)
  local path = file_path
  while path and path ~= root do
    if path_to_line[path] then
      return path
    end
    path = vim.fs.dirname(path)
  end
  return nil
end

local function collect_all_diagnostics()
  local diagnostics_map = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name and buf_name ~= "" then
        local buf_diagnostics = vim.diagnostic.get(buf)
        if #buf_diagnostics > 0 then
          diagnostics_map[buf_name] = buf_diagnostics
        end
      end
    end
  end

  return diagnostics_map
end

function M.add_lsp_diagnostic_extmarks()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.buf, state.lsp_ns, 0, -1)

  local root = state.cwd
  local diagnostics_map = collect_all_diagnostics()

  if not next(diagnostics_map) then
    return
  end

  local path_to_line = {}
  local folder_marks = {}

  for i, node in ipairs(state.nodes) do
    path_to_line[node.full_path] = i - 1
  end

  for file_path, diagnostics in pairs(diagnostics_map) do
    local line = path_to_line[file_path]
    if line then
      local highest_severity = get_highest_severity_diagnostic(diagnostics)
      if highest_severity then
        local diagnostic_info = get_diagnostic_icon(highest_severity.severity)
        if diagnostic_info then
          vim.api.nvim_buf_set_extmark(state.buf, state.lsp_ns, line, -1, {
            virt_text = diagnostic_info,
            virt_text_pos = "right_align",
            priority = 100,
            hl_mode = "combine",
          })
          diagnostics_map[file_path] = nil
        end
      end
    end
  end

  for file_path, diagnostics in pairs(diagnostics_map) do
    local parent_path = find_parent_in_tree(path_to_line, file_path, root)
    if parent_path then
      local highest_severity = get_highest_severity_diagnostic(diagnostics)
      if highest_severity then
        add_diagnostic_info_to_folder(folder_marks, parent_path, highest_severity.severity)
      end
    end
  end

  for folder, mark_info in pairs(folder_marks) do
    local line = path_to_line[folder]
    if line and mark_info.icon then
      vim.api.nvim_buf_set_extmark(state.buf, state.lsp_ns, line, -1, {
        virt_text = mark_info.icon,
        virt_text_pos = "right_align",
        priority = 100,
        hl_mode = "combine",
      })
    end
  end
end

function M.refresh_lsp_diagnostics()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  M.add_lsp_diagnostic_extmarks()
end

function M.setup()
  local lsp_augroup = vim.api.nvim_create_augroup("OtreeLsp", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = lsp_augroup,
    pattern = "OtreeRender",
    callback = M.refresh_lsp_diagnostics,
  })

  local timer = vim.loop.new_timer()
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = lsp_augroup,
    callback = function()
      timer:stop()
      timer:start(
        500,
        0,
        vim.schedule_wrap(function()
          M.refresh_lsp_diagnostics()
        end)
      )
    end,
  })
end

return M
