local parse = require("quint_infoview.parse")
local H = dofile(_G.fixtures .. "/../helpers.lua")

local function each(name, fn)
  local versions = H.versions()
  H.truthy(#versions >= 2, "fixture versions")
  for _, dir in ipairs(versions) do
    local path = dir .. "/" .. name
    if vim.uv.fs_stat(path) then
      fn(parse.check(H.read(path)), H.read(path), vim.fs.basename(dir))
    end
  end
end

return {
  ["run violation names the invariant and observations"] = function()
    each("run-violation.txt", function(r, _, v)
      H.eq("violation", r.status, v)
      H.eq({ "atMostOneCritical" }, r.violated, v)
      H.eq({}, r.checked, v)
      H.truthy(r.headline:find("^Found an issue"), v)
      H.eq("twoWaiting", r.observations[1].name, v)
      H.truthy(r.observations[1].seen <= r.observations[1].total, v)
    end)
  end,
  ["run ok lists every checked invariant"] = function()
    each("run-ok.txt", function(r, _, v)
      H.eq("ok", r.status, v)
      H.eq({ "freeMeansNobodyCritical", "atMostOneCritical" }, r.checked, v)
      H.eq({}, r.violated, v)
      H.truthy(r.observations[1].seen > 0, v)
    end)
  end,
  ["run warning reports the unreached observation"] = function()
    each("run-warning.txt", function(r, _, v)
      H.eq("warning", r.status, v)
      H.eq({ name = "threeCritical", seen = 0, total = 10000, pct = "0.00" }, r.observations[1], v)
    end)
  end,
  ["runtime error has a location and output"] = function()
    each("run-runtime-error.txt", function(r, _, v)
      H.eq("error", r.status, v)
      H.eq({ file = "SPEC/mutex.qnt", line = 18, col = 11 }, r.location, v)
      H.has_line(r.output, "QNT500", v)
    end)
  end,
  ["type error has no status but a location"] = function()
    each("run-type-error.txt", function(r, _, v)
      H.eq(nil, r.status, v)
      H.eq({ "typechecking failed" }, r.errors, v)
      H.eq(3, r.location.line, v)
    end)
  end,
  ["tests report pass, failure message and location"] = function()
    each("test.txt", function(_, text, v)
      local t = parse.tests(text)
      H.eq(2, #t, v)
      H.eq({ name = "handOverTest", ok = true }, t[1], v)
      H.eq("wrongOwnerTest", t[2].name, v)
      H.eq(false, t[2].ok, v)
      H.eq("Expect condition does not hold true", t[2].message, v)
      H.eq("SPEC/mutex_test.qnt", t[2].location.file, v)
      H.truthy(t[2].location.line >= 13, v)
    end)
  end,
  ["verify violation and ok"] = function()
    each("verify-violation.txt", function(r, _, v)
      H.eq("violation", r.status, v)
      H.eq({ "atMostOneCritical" }, r.violated, v)
      for _, line in ipairs(r.output) do
        H.truthy(not line:find("I@%d"), v .. " apalache log lines dropped")
      end
    end)
    each("verify-ok.txt", function(r, _, v)
      H.eq("ok", r.status, v)
    end)
  end,
}
