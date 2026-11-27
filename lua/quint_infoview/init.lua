local itf = require("quint_infoview.itf")
local panel = require("quint_infoview.panel")
local parse = require("quint_infoview.parse")
local source = require("quint_infoview.source")

local M = {}

M.config = {
  cmd = { "quint" },
  run_args = {},
  verify_args = {},
  test_args = {},
  on_save = true,
  auto_open = true,
  width = 64,
}

local states = {}
local marks_ns = vim.api.nvim_create_namespace("quint_infoview_marks")
local diag_ns = vim.api.nvim_create_namespace("quint_infoview")

local highlights = {
  QuintInfoTitle = "Title",
  QuintInfoHeading = "Label",
  QuintInfoOk = "DiagnosticOk",
  QuintInfoFail = "DiagnosticError",
  QuintInfoWarn = "DiagnosticWarn",
  QuintInfoDim = "Comment",
  QuintInfoAction = "Function",
  QuintInfoChanged = "DiagnosticWarn",
  QuintInfoStep = "Visual",
}

local function state(buf)
  states[buf] = states[buf] or { gen = 0, jobs = {} }
  return states[buf]
end

local function test_file(file)
  if file:match("_test%.qnt$") then
    return file
  end
  local sibling = file:gsub("%.qnt$", "_test.qnt")
  return vim.uv.fs_stat(sibling) and sibling or nil
end

local function cursor_row(buf)
  local win = vim.fn.bufwinid(buf)
  return win ~= -1 and vim.api.nvim_win_get_cursor(win)[1] or 1
end

local function mark(buf, line, text, hl)
  vim.api.nvim_buf_set_extmark(buf, marks_ns, line - 1, 0, { virt_text = { { text, hl } }, virt_text_pos = "eol" })
end

local function annotate(buf, result)
  vim.api.nvim_buf_clear_namespace(buf, marks_ns, 0, -1)
  local diags, scan, c = {}, result.scan, result.check
  local function diag(line, col, severity, message)
    table.insert(diags, { lnum = line - 1, col = col, severity = severity, message = message, source = "quint" })
  end
  if c then
    for _, name in ipairs(c.violated) do
      local d = source.find(scan, name, { "invariant", "val" }, result.main)
      if d then
        diag(d.line, 0, vim.diagnostic.severity.ERROR, ("%s violated in %s (%s)"):format(name, result.main, result.mode))
      end
    end
    for _, name in ipairs(c.checked) do
      local d = source.find(scan, name, { "invariant", "val" }, result.main)
      if d then
        mark(buf, d.line, "✓ held", "QuintInfoOk")
      end
    end
    for _, o in ipairs(c.observations) do
      local d = source.find(scan, o.name, { "observation", "val" }, result.main)
      if d then
        mark(buf, d.line, ("%s %d/%d"):format(o.seen > 0 and "●" or "○", o.seen, o.total), o.seen > 0 and "QuintInfoOk" or "QuintInfoWarn")
      end
    end
    if c.location and c.location.file == result.file and (not c.status or c.status == "error") then
      diag(c.location.line, c.location.col - 1, vim.diagnostic.severity.ERROR, c.output[1] or "quint failed")
    end
  end
  if result.test_file == result.file then
    for _, t in ipairs(result.tests or {}) do
      local d = source.find(scan, t.name, { "run" })
      if t.ok and d then
        mark(buf, d.line, "✓ passed", "QuintInfoOk")
      elseif not t.ok then
        local at = t.location or (d and { line = d.line, col = 1 })
        if at then
          diag(at.line, at.col - 1, vim.diagnostic.severity.ERROR, t.message or (t.name .. " failed"))
        end
      end
    end
  end
  vim.diagnostic.set(diag_ns, buf, diags)
end

local function publish(buf, result)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not result.running then
    annotate(buf, result)
  end
  if M.config.auto_open and not result.running and not panel.is_open() then
    panel.open(M.config.width)
  end
  panel.show(buf, result)
end

local function spawn(st, gen, cmd, dir, on_done)
  local job = vim.system(cmd, { cwd = dir, text = true }, function(obj)
    vim.schedule(function()
      if st.gen == gen then
        on_done((obj.stdout or "") .. "\n" .. (obj.stderr or ""))
      end
    end)
  end)
  table.insert(st.jobs, job)
end

function M.check(buf, mode)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  mode = mode or "run"
  local file = vim.api.nvim_buf_get_name(buf)
  local st = state(buf)
  for _, job in ipairs(st.jobs) do
    pcall(job.kill, job, 15)
  end
  st.jobs, st.gen = {}, st.gen + 1
  local gen = st.gen
  local scan = source.scan(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  local tests = mode == "run" and test_file(file) or nil
  local main = not file:match("_test%.qnt$") and (st.main or source.main_module(scan, cursor_row(buf))) or nil
  local result = { mode = mode, main = main, file = file, test_file = tests, scan = scan, running = true }
  st.result = result
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local pending = 0
  local function finish()
    pending = pending - 1
    result.running = pending > 0
    if not result.running then
      vim.fn.delete(dir, "rf")
    end
    publish(buf, result)
  end
  if main then
    pending = pending + 1
    local cmd = vim.list_extend({}, M.config.cmd)
    if mode == "verify" then
      vim.list_extend(cmd, { "verify", file, "--main", main, "--out-itf", dir .. "/trace.itf.json" })
      vim.list_extend(cmd, M.config.verify_args)
    else
      vim.list_extend(cmd, { "run", file, "--main", main, "--mbt", "--out-itf", dir .. "/trace_{seq}.itf.json" })
      vim.list_extend(cmd, M.config.run_args)
    end
    spawn(st, gen, cmd, dir, function(out)
      result.check = parse.check(out)
      local trace = vim.fn.glob(dir .. "/trace*.itf.json", false, true)[1]
      result.steps = trace and itf.read(trace) or nil
      finish()
    end)
  end
  if tests then
    pending = pending + 1
    local cmd = vim.list_extend(vim.list_extend({}, M.config.cmd), { "test", tests })
    spawn(st, gen, vim.list_extend(cmd, M.config.test_args), dir, function(out)
      result.tests, result.tests_check = parse.tests(out), parse.check(out)
      finish()
    end)
  end
  if pending == 0 then
    result.running = false
  end
  publish(buf, result)
end

function M.toggle()
  if panel.is_open() then
    panel.close()
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  panel.open(M.config.width)
  if vim.bo[buf].filetype == "quint" then
    panel.show(buf, state(buf).result)
  end
end

function M.pin(buf, main)
  state(buf).main = main ~= "" and main or nil
  vim.notify(main ~= "" and ("Quint main module: " .. main) or "Quint main module: module under the cursor")
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, marks_ns, 0, -1)
  vim.diagnostic.reset(diag_ns, buf)
  state(buf).result = nil
  panel.show(buf, nil)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  for name, link in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  panel.actions = {
    run = function(buf)
      M.check(buf, "run")
    end,
    verify = function(buf)
      M.check(buf, "verify")
    end,
  }
  local group = vim.api.nvim_create_augroup("QuintInfoview", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.qnt",
    callback = function(args)
      if M.config.on_save then
        M.check(args.buf, "run")
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*.qnt",
    callback = function(args)
      if panel.is_open() and args.buf ~= panel.source_buf then
        panel.show(args.buf, state(args.buf).result)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    pattern = "*.qnt",
    callback = function(args)
      states[args.buf] = nil
    end,
  })
end

return M
