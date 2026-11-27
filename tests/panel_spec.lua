local itf = require("quint_infoview.itf")
local panel = require("quint_infoview.panel")
local parse = require("quint_infoview.parse")
local source = require("quint_infoview.source")
local H = dofile(_G.fixtures .. "/../helpers.lua")

local spec = _G.fixtures .. "/spec/mutex.qnt"
local scan = source.scan(vim.fn.readfile(spec))

local function result(dir, name, main, extra)
  return vim.tbl_extend("force", {
    mode = "run",
    main = main,
    file = spec,
    scan = scan,
    check = parse.check(H.read(dir .. "/" .. name)),
  }, extra or {})
end

return {
  ["violation shows invariants, observations and the counterexample"] = function()
    for _, dir in ipairs(H.versions()) do
      local r = result(dir, "run-violation.txt", "mutexBuggy", { steps = itf.read(dir .. "/run-violation_0.itf.json") })
      local b = panel.content(r)
      H.eq("Quint · mutexBuggy · run", b.lines[1])
      H.has_line(b.lines, "^✗ violation  Found an issue")
      local inv = H.has_line(b.lines, "^  ✗ atMostOneCritical$")
      H.eq({ name = "atMostOneCritical", kinds = { "invariant", "val" } }, b.items[inv])
      H.has_line(b.lines, "^  · ownerIsClient  held until the run stopped$")
      H.has_line(b.lines, "^  ● twoWaiting  %d+/%d+  [%d.]+%%$")
      H.has_line(b.lines, "^Counterexample  %d+ states$")
      local init = H.has_line(b.lines, "^  0 init$")
      H.eq("owner = Free", vim.trim(b.lines[init + 1]))
      local step = H.has_line(b.lines, '^  1 request  c = "%a"$')
      H.eq(b.items[step], b.items[step + 1])
      H.truthy(b.lines[step + 1]:find("^      pc = Map%("))
    end
  end,
  ["ok lists checked invariants and hides the sample trace"] = function()
    for _, dir in ipairs(H.versions()) do
      local b = panel.content(result(dir, "run-ok.txt", "mutexOk", { steps = {} }))
      H.has_line(b.lines, "^✓ ok  No violation found")
      H.has_line(b.lines, "^  ✓ freeMeansNobodyCritical$")
      H.has_line(b.lines, "^  ✓ atMostOneCritical$")
      H.eq(nil, H.line_of(b.lines, "Counterexample"))
    end
  end,
  ["unreached observation is a warning"] = function()
    for _, dir in ipairs(H.versions()) do
      local b = panel.content(result(dir, "run-warning.txt", "mutexUnreached"))
      H.has_line(b.lines, "^! warning  No violation found, but no trace reached threeCritical")
      H.has_line(b.lines, "^  ○ threeCritical  0/10000  0.00%%$")
    end
  end,
  ["errors show quint output with a jump target"] = function()
    for _, dir in ipairs(H.versions()) do
      local b = panel.content(result(dir, "run-type-error.txt", nil))
      H.has_line(b.lines, "^✗ failed  typechecking failed$")
      local out = H.has_line(b.lines, "^Output$")
      H.eq(3, b.items[out + 1].location.line)
    end
  end,
  ["tests section"] = function()
    for _, dir in ipairs(H.versions()) do
      local text = H.read(dir .. "/test.txt")
      local b = panel.content({ mode = "run", file = spec, scan = scan, test_file = "/x/mutex_test.qnt", tests = parse.tests(text), tests_check = parse.check(text) })
      H.has_line(b.lines, "^Tests  mutex_test%.qnt$")
      H.has_line(b.lines, "^  ✓ handOverTest$")
      H.has_line(b.lines, "^  ✗ wrongOwnerTest  Expect condition does not hold true$")
    end
  end,
  ["no result"] = function()
    H.eq({ "No results yet. Save the file or run :QuintInfo run" }, panel.content(nil).lines)
  end,
}
