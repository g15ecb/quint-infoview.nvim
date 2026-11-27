local itf = require("quint_infoview.itf")
local H = dofile(_G.fixtures .. "/../helpers.lua")

return {
  ["values render as quint literals"] = function()
    H.eq("Free", itf.show({ tag = "Free", value = { ["#tup"] = {} } }))
    H.eq("Free", itf.show({ tag = "Free", value = { tag = "UNIT" } }))
    H.eq('Held("a")', itf.show({ tag = "Held", value = "a" }))
    H.eq('Map("a" -> 1, "b" -> 2)', itf.show({ ["#map"] = { { "a", 1 }, { "b", 2 } } }))
    H.eq("Set(1, 2)", itf.show({ ["#set"] = { 1, 2 } }))
    H.eq('(1, "x")', itf.show({ ["#tup"] = { 1, "x" } }))
    H.eq("115792089237316195423570985008687907853269984665640564039457584007913129639935", itf.show({ ["#bigint"] = "115792089237316195423570985008687907853269984665640564039457584007913129639935" }))
    H.eq("[1, 2]", itf.show({ 1, 2 }))
    H.eq("{ a: 1, b: true }", itf.show({ b = true, a = 1 }))
  end,
  ["run trace has actions, picks and changed vars"] = function()
    for _, dir in ipairs(H.versions()) do
      local steps = itf.read(dir .. "/run-violation_0.itf.json")
      local v = vim.fs.basename(dir)
      H.truthy(steps and #steps >= 3, v)
      H.eq("init", steps[1].action, v)
      H.eq({}, steps[1].picks, v)
      H.eq({ "owner", "pc" }, vim.tbl_map(function(x) return x.name end, steps[1].vars), v)
      H.truthy(steps[1].vars[1].changed and steps[1].vars[2].changed, v)
      H.truthy(steps[2].picks[1]:match('^c = "%a"$'), v)
      local last = steps[#steps]
      H.eq("acquire", last.action, v)
      local _, criticals = last.vars[2].value:gsub("Critical", "")
      H.truthy(criticals >= 2, v .. " two clients critical at the end")
      for i = 2, #steps do
        local any = vim.iter(steps[i].vars):any(function(x) return x.changed end)
        H.truthy(any, v .. " every step changes a variable")
      end
    end
  end,
  ["verify trace has no mbt metadata"] = function()
    for _, dir in ipairs(H.versions()) do
      local steps = itf.read(dir .. "/verify-violation.itf.json")
      H.truthy(steps and #steps >= 2, dir)
      H.eq(nil, steps[1].action)
      H.eq("Free", steps[1].vars[vim.iter(steps[1].vars):enumerate():find(function(_, x) return x.name == "owner" end)].value)
    end
  end,
  ["missing or bad trace reads as nil"] = function()
    H.eq(nil, itf.read("/nonexistent.itf.json"))
    H.eq(nil, itf.read(_G.fixtures .. "/spec/mutex.qnt"))
  end,
}
