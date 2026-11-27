local panel = require("quint_infoview.panel")
local qi = require("quint_infoview")
local H = dofile(_G.fixtures .. "/../helpers.lua")

local quint = vim.env.QUINT or "quint"

local function workdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  for _, f in ipairs({ "mutex.qnt", "mutex_test.qnt", "tyerr.qnt" }) do
    vim.fn.writefile(vim.fn.readfile(_G.fixtures .. "/spec/" .. f), dir .. "/" .. f)
  end
  return dir
end

local function save_and_wait()
  local file = vim.api.nvim_buf_get_name(0)
  vim.cmd("silent write")
  local done = vim.wait(60000, function()
    return panel.result ~= nil and panel.result.file == file and not panel.result.running
  end, 50)
  H.truthy(done, "quint finished for " .. file)
end

local function panel_lines()
  return vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false)
end

local function marks(buf)
  local ns = vim.api.nvim_get_namespaces().quint_infoview_marks
  return vim.tbl_map(function(m)
    return { m[2] + 1, m[4].virt_text[1][1] }
  end, vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }))
end

local function diags(buf)
  return vim.tbl_map(function(d)
    return { d.lnum + 1, d.message }
  end, vim.diagnostic.get(buf, { namespace = vim.api.nvim_get_namespaces().quint_infoview }))
end

local function reset()
  panel.close()
  vim.cmd("silent! %bwipeout!")
end

if vim.fn.executable(quint) == 0 then
  return {}
end

qi.setup({ cmd = { quint }, verify_args = { "--max-steps", "4" } })

return {
  ["save runs the module under the cursor and its tests"] = function()
    reset()
    local dir = workdir()
    local file = dir .. "/mutex.qnt"
    vim.cmd.edit(file)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_win_set_cursor(0, { H.line_of(lines, "^module mutexBuggy") + 1, 0 })
    save_and_wait()
    H.truthy(panel.is_open(), "panel opened")
    H.eq(buf, vim.api.nvim_get_current_buf(), "focus stays in the source")
    local pl = panel_lines()
    H.eq("Quint · mutexBuggy · run", pl[1])
    H.has_line(pl, "^  ✗ atMostOneCritical$")
    H.has_line(pl, "^  ✗ wrongOwnerTest")
    H.has_line(pl, "^Counterexample")
    local buggy = H.line_of(lines, "^module mutexBuggy")
    local inv = buggy + H.line_of(vim.list_slice(lines, buggy + 1), "invariant atMostOneCritical")
    H.eq({ { inv, "atMostOneCritical violated in mutexBuggy (run)" } }, diags(buf))
    H.truthy(vim.iter(marks(buf)):any(function(m) return m[1] > buggy and m[2]:match("^● %d+/%d+$") end), "observation mark")

    local acquire = H.line_of(lines, "action acquire")
    local row = H.line_of(pl, "^  %d+ acquire")
    vim.api.nvim_set_current_win(panel.win)
    vim.api.nvim_win_set_cursor(panel.win, { row, 0 })
    panel.highlight_step()
    local step_ns = vim.api.nvim_get_namespaces().quint_infoview_step
    local hl = vim.api.nvim_buf_get_extmarks(buf, step_ns, 0, -1, { details = true })
    H.eq(1, #hl)
    H.eq({ acquire - 1, acquire + 4 }, { hl[1][2], hl[1][4].end_row })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    H.eq(buf, vim.api.nvim_get_current_buf())
    H.eq(acquire, vim.api.nvim_win_get_cursor(0)[1])
  end,
  ["ok run marks held invariants"] = function()
    reset()
    local dir = workdir()
    local file = dir .. "/mutex.qnt"
    vim.cmd.edit(file)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local ok = H.line_of(lines, "^module mutexOk")
    vim.api.nvim_win_set_cursor(0, { ok + 1, 0 })
    save_and_wait()
    H.eq({}, diags(buf))
    local m = marks(buf)
    H.truthy(vim.iter(m):any(function(x) return x[1] == ok + 2 and x[2] == "✓ held" end), vim.inspect(m))
    H.truthy(vim.iter(m):any(function(x) return x[1] == H.line_of(lines, "invariant freeMeansNobodyCritical") and x[2] == "✓ held" end), "imported invariant marked")
  end,
  ["test file marks passing tests and flags failing ones"] = function()
    reset()
    local dir = workdir()
    local file = dir .. "/mutex_test.qnt"
    vim.cmd.edit(file)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    save_and_wait()
    H.eq({ { H.line_of(lines, "run handOverTest"), "✓ passed" } }, marks(buf))
    local d = diags(buf)
    H.eq(1, #d)
    H.eq("Expect condition does not hold true", d[1][2])
    H.truthy(d[1][1] >= H.line_of(lines, "run wrongOwnerTest"))
  end,
  ["type error shows output and a diagnostic"] = function()
    reset()
    local dir = workdir()
    local file = dir .. "/tyerr.qnt"
    vim.cmd.edit(file)
    local buf = vim.api.nvim_get_current_buf()
    save_and_wait()
    H.has_line(panel_lines(), "^✗ failed  typechecking failed$")
    H.eq(3, diags(buf)[1][1])
  end,
  ["verify shows the counterexample without actions"] = function()
    reset()
    if vim.fn.executable("java") == 0 then
      return
    end
    local dir = workdir()
    vim.cmd.edit(dir .. "/mutex.qnt")
    local file = vim.api.nvim_buf_get_name(0)
    vim.cmd("QuintInfo verify")
    H.truthy(vim.wait(120000, function()
      return panel.result ~= nil and panel.result.file == file and not panel.result.running
    end, 100), "verify finished")
    local pl = panel_lines()
    H.eq("Quint · mutexBuggy · verify", pl[1])
    H.has_line(pl, "^  ✗ atMostOneCritical$")
    H.has_line(pl, "^  0 $")
    H.eq(nil, H.line_of(pl, "^Tests"))
  end,
  ["pinned main and toggle"] = function()
    reset()
    local dir = workdir()
    local file = dir .. "/mutex.qnt"
    vim.cmd.edit(file)
    vim.cmd("QuintInfo main mutexUnreached")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    save_and_wait()
    H.eq("Quint · mutexUnreached · run", panel_lines()[1])
    H.has_line(panel_lines(), "^  ○ threeCritical")
    vim.cmd("QuintInfo")
    H.truthy(not panel.is_open(), "toggle closes")
    vim.cmd("QuintInfo toggle")
    H.truthy(panel.is_open(), "toggle opens")
    H.eq("Quint · mutexUnreached · run", panel_lines()[1])
  end,
}
