local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.cmd("runtime plugin/quint_infoview.lua")
_G.fixtures = root .. "/tests/fixtures"
local filter = _G.arg[1]
local failed, passed = 0, 0
for _, file in ipairs(vim.fn.glob(root .. "/tests/*_spec.lua", false, true)) do
  local cases = dofile(file)
  local names = vim.tbl_keys(cases)
  table.sort(names)
  for _, name in ipairs(names) do
    local label = vim.fs.basename(file):gsub("_spec%.lua$", "") .. ": " .. name
    if not filter or label:find(filter, 1, true) then
      local ok, err = xpcall(cases[name], debug.traceback)
      if ok then
        passed = passed + 1
        io.stdout:write("ok   " .. label .. "\n")
      else
        failed = failed + 1
        io.stdout:write("FAIL " .. label .. "\n" .. tostring(err) .. "\n")
      end
    end
  end
end
io.stdout:write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
