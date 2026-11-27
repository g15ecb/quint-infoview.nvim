local M = {}

M.tested = { "0.34.0", "0.35.0" }

function M.check()
  vim.health.start("quint-infoview")
  local cmd = require("quint_infoview").config.cmd
  if vim.fn.executable(cmd[1]) == 0 then
    vim.health.error(cmd[1] .. " not found on PATH")
    return
  end
  local out = vim.system(vim.list_extend(vim.list_extend({}, cmd), { "--version" }), { text = true }):wait()
  local version = vim.trim(out.stdout or "")
  if vim.tbl_contains(M.tested, version) then
    vim.health.ok("quint " .. version)
  else
    vim.health.warn(("quint %s is untested; output parsing is tested against %s"):format(version, table.concat(M.tested, ", ")))
  end
  if vim.fn.executable("java") == 1 then
    vim.health.ok("java found (needed by :QuintInfo verify)")
  else
    vim.health.warn("java not found; :QuintInfo verify needs it for Apalache and TLC")
  end
end

return M
