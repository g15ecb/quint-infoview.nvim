local source = require("quint_infoview.source")

local M = { buf = nil, source_buf = nil, result = nil, items = {}, actions = {} }

local ns = vim.api.nvim_create_namespace("quint_infoview_panel")
local step_ns = vim.api.nvim_create_namespace("quint_infoview_step")

local icons = {
  ok = { "✓", "QuintInfoOk" },
  violation = { "✗", "QuintInfoFail" },
  warning = { "!", "QuintInfoWarn" },
  error = { "✗", "QuintInfoFail" },
}

local function builder()
  local b = { lines = {}, hls = {}, items = {} }
  function b.add(text, hl, item)
    table.insert(b.lines, text)
    if hl then
      table.insert(b.hls, { #b.lines - 1, 0, #text, hl })
    end
    b.items[#b.lines] = item
  end
  function b.span(from, to, hl)
    table.insert(b.hls, { #b.lines - 1, from, to, hl })
  end
  return b
end

local function pad(names)
  local width = 0
  for _, n in ipairs(names) do
    width = math.max(width, #n)
  end
  return function(n)
    return n .. string.rep(" ", width - #n)
  end
end

local function invariants(b, result, c)
  local rows = {}
  for _, name in ipairs(c.violated) do
    table.insert(rows, { name = name, ok = false })
  end
  if c.status == "violation" then
    for _, d in ipairs(source.in_module(result.scan, "invariant", result.main)) do
      if not vim.tbl_contains(c.violated, d.name) then
        table.insert(rows, { name = d.name, held = true })
      end
    end
  else
    for _, name in ipairs(c.checked) do
      table.insert(rows, { name = name, ok = true })
    end
  end
  if #rows == 0 then
    return
  end
  b.add("Invariants", "QuintInfoHeading")
  for _, r in ipairs(rows) do
    local item = { name = r.name, kinds = { "invariant", "val" } }
    if r.held then
      b.add("  · " .. r.name .. "  held until the run stopped", "QuintInfoDim", item)
    else
      b.add(("  %s %s"):format(r.ok and "✓" or "✗", r.name), r.ok and "QuintInfoOk" or "QuintInfoFail", item)
    end
  end
end

local function observations(b, c)
  if #c.observations == 0 then
    return
  end
  b.add("Observations", "QuintInfoHeading")
  local p = pad(vim.tbl_map(function(o)
    return o.name
  end, c.observations))
  for _, o in ipairs(c.observations) do
    local reached = o.seen > 0
    b.add(
      ("  %s %s  %d/%d  %s%%"):format(reached and "●" or "○", p(o.name), o.seen, o.total, o.pct),
      reached and "QuintInfoOk" or "QuintInfoWarn",
      { name = o.name, kinds = { "observation", "val" } }
    )
  end
end

local function tests(b, result)
  if not result.tests then
    return
  end
  b.add("Tests  " .. vim.fs.basename(result.test_file), "QuintInfoHeading")
  for _, t in ipairs(result.tests) do
    local item = { name = t.name, kinds = { "run" }, file = result.test_file, location = t.location }
    if t.ok then
      b.add("  ✓ " .. t.name, "QuintInfoOk", item)
    else
      b.add("  ✗ " .. t.name .. (t.message and "  " .. t.message or ""), "QuintInfoFail", item)
    end
  end
  if #result.tests == 0 then
    for _, line in ipairs(result.tests_check.output) do
      b.add("  " .. line, "QuintInfoDim", { location = result.tests_check.location })
    end
  end
end

local function counterexample(b, result)
  if not result.steps or not result.check or result.check.status ~= "violation" then
    return
  end
  b.add(("Counterexample  %d states"):format(#result.steps), "QuintInfoHeading")
  for _, step in ipairs(result.steps) do
    local item = { step = step }
    local head = ("  %d %s"):format(step.index, step.action or "")
    b.add(head .. (#step.picks > 0 and "  " .. table.concat(step.picks, ", ") or ""), nil, item)
    b.span(2, #head, "QuintInfoAction")
    local shown = 0
    for _, v in ipairs(step.vars) do
      if step.index == 0 or v.changed then
        shown = shown + 1
        b.add(("      %s = %s"):format(v.name, v.value), nil, item)
        b.span(6, 6 + #v.name, step.index == 0 and "QuintInfoDim" or "QuintInfoChanged")
      end
    end
    if shown == 0 then
      b.add("      (no change)", "QuintInfoDim", item)
    end
  end
end

function M.content(result)
  local b = builder()
  if not result then
    b.add("No results yet. Save the file or run :QuintInfo run", "QuintInfoDim")
    return b
  end
  b.add(("Quint · %s · %s"):format(result.main or vim.fs.basename(result.file), result.mode), "QuintInfoTitle")
  if result.running then
    b.add("running…", "QuintInfoDim")
  end
  local c = result.check
  if c then
    local icon = icons[c.status] or icons.error
    b.add(("%s %s  %s"):format(icon[1], c.status or "failed", c.headline or c.errors[#c.errors] or ""), icon[2])
    invariants(b, result, c)
    observations(b, c)
  end
  tests(b, result)
  counterexample(b, result)
  if c and (not c.status or c.status == "error") then
    b.add("Output", "QuintInfoHeading")
    for _, line in ipairs(c.output) do
      b.add("  " .. line, nil, { location = c.location })
    end
  end
  return b
end

function M.is_open()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

local function source_win()
  local win = M.source_buf and vim.fn.bufwinid(M.source_buf) or -1
  if win ~= -1 then
    return win
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= M.win then
      return w
    end
  end
end

local function goto_target(target)
  local win = source_win()
  if not win or not target then
    return
  end
  vim.api.nvim_set_current_win(win)
  if target.file and target.file ~= vim.api.nvim_buf_get_name(0) then
    vim.cmd.edit(vim.fn.fnameescape(target.file))
  end
  vim.api.nvim_win_set_cursor(win, { target.line, math.max((target.col or 1) - 1, 0) })
end

local function file_scan(file)
  if file == vim.api.nvim_buf_get_name(M.source_buf) then
    return M.result.scan
  end
  return source.scan(vim.fn.readfile(file))
end

local function resolve(item)
  if not item or not M.result then
    return nil
  end
  if item.location then
    return item.location
  end
  if item.step and item.step.action then
    local d = source.find(M.result.scan, item.step.action, { "action" }, M.result.main)
    return d and { file = M.result.file, line = d.line }
  end
  if item.name then
    local file = item.file or M.result.file
    local d = source.find(file_scan(file), item.name, item.kinds, M.result.main)
    return d and { file = file, line = d.line }
  end
end

function M.highlight_step()
  if not M.source_buf or not vim.api.nvim_buf_is_valid(M.source_buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(M.source_buf, step_ns, 0, -1)
  local item = M.items[vim.api.nvim_win_get_cursor(0)[1]]
  local target = item and item.step and resolve(item)
  if not target then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(M.source_buf, 0, -1, false)
  local from, to = source.block(lines, target.line)
  vim.api.nvim_buf_set_extmark(M.source_buf, step_ns, from - 1, 0, {
    end_row = to - 1,
    end_col = #lines[to],
    hl_group = "QuintInfoStep",
    hl_eol = true,
  })
end

local function ensure_buf()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    return M.buf
  end
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(M.buf, "quint://infoview")
  vim.bo[M.buf].filetype = "quintinfo"
  vim.bo[M.buf].modifiable = false
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = M.buf, nowait = true })
  end
  map("<CR>", function()
    goto_target(resolve(M.items[vim.api.nvim_win_get_cursor(0)[1]]))
  end)
  map("q", M.close)
  map("r", function()
    M.actions.run(M.source_buf)
  end)
  map("v", function()
    M.actions.verify(M.source_buf)
  end)
  vim.api.nvim_create_autocmd("CursorMoved", { buffer = M.buf, callback = M.highlight_step })
  return M.buf
end

function M.draw()
  local buf = ensure_buf()
  local b = M.content(M.result)
  M.items = b.items
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, b.lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(b.hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end
end

function M.open(width)
  if M.is_open() then
    return
  end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("botright vsplit")
  M.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.win, ensure_buf())
  vim.api.nvim_win_set_width(M.win, width)
  local wo = vim.wo[M.win]
  wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
  wo.wrap, wo.linebreak, wo.cursorline, wo.winfixwidth = true, true, true, true
  wo.breakindent = true
  M.draw()
  vim.api.nvim_set_current_win(prev)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  if M.source_buf and vim.api.nvim_buf_is_valid(M.source_buf) then
    vim.api.nvim_buf_clear_namespace(M.source_buf, step_ns, 0, -1)
  end
end

function M.show(source_buf, result)
  M.source_buf, M.result = source_buf, result
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    M.draw()
  end
end

return M
