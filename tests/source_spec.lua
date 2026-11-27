local source = require("quint_infoview.source")
local H = dofile(_G.fixtures .. "/../helpers.lua")

local lines = vim.fn.readfile(_G.fixtures .. "/spec/mutex.qnt")
local scan = source.scan(lines)

return {
  ["modules and consts"] = function()
    H.eq({ "mutex", "mutexOk", "mutexUnreached", "mutexBuggy" }, vim.tbl_map(function(m) return m.name end, scan.modules))
    H.eq({ true, false, false, false }, vim.tbl_map(function(m) return m.const end, scan.modules))
  end,
  ["main module is the module under the cursor unless it has consts"] = function()
    H.eq("mutexBuggy", source.main_module(scan, 1))
    H.eq("mutexBuggy", source.main_module(scan, H.line_of(lines, "action acquire")))
    H.eq("mutexOk", source.main_module(scan, H.line_of(lines, "^module mutexOk") + 1))
    H.eq("mutexBuggy", source.main_module(scan, #lines))
    H.eq(nil, source.main_module(source.scan({ "module m {", "  const N: int", "}" }), 2))
  end,
  ["find prefers the main module"] = function()
    local ok = H.line_of(lines, "^module mutexOk")
    local buggy = H.line_of(lines, "^module mutexBuggy")
    H.truthy(source.find(scan, "atMostOneCritical", { "invariant" }, "mutexOk").line > ok)
    H.truthy(source.find(scan, "atMostOneCritical", { "invariant" }, "mutexBuggy").line > buggy)
    H.eq(H.line_of(lines, "pure def isFree"), source.find(scan, "isFree", { "def" }).line)
    H.eq(nil, source.find(scan, "atMostOneCritical", { "action" }))
  end,
  ["in_module lists declarations of a kind"] = function()
    H.eq({ "atMostOneCritical", "ownerIsClient" }, vim.tbl_map(function(d) return d.name end, source.in_module(scan, "invariant", "mutexBuggy")))
  end,
  ["block spans an action through its closing brace"] = function()
    local start = H.line_of(lines, "action acquire")
    H.eq({ start, start + 5 }, { source.block(lines, start) })
    local inv = H.line_of(lines, "invariant ownerIsClient")
    H.eq({ inv, inv + 3 }, { source.block(lines, inv) })
  end,
}
