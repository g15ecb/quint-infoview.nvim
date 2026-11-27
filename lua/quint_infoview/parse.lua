local M = {}

local function lines(text)
  return vim.split(text, "\n", { plain = true })
end

local function location(line)
  local file, row, col = line:match("^%s*at (.-):(%d+):(%d+)%s*$")
  if file then
    return { file = file, line = tonumber(row), col = tonumber(col) }
  end
end

function M.check(text)
  local r = { violated = {}, checked = {}, observations = {}, errors = {}, output = {} }
  for _, line in ipairs(lines(text)) do
    local status, headline = line:match("^%[(%a+)%] (.*)$")
    if status and not r.status then
      r.status, r.headline = status, headline
    end
    local violated = line:match("^%s+❌ (%S+)")
    if violated then
      table.insert(r.violated, violated)
    end
    local checked = line:match("^Checked invariants: (.+)$")
    if checked then
      r.checked = vim.split(checked, ",%s*")
    end
    local name, seen, total, pct =
      line:match("^(%S+) was observed in (%d+) trace%(s%) out of (%d+) explored %(([%d.]+)%%%)")
    if name then
      table.insert(r.observations, { name = name, seen = tonumber(seen), total = tonumber(total), pct = pct })
    end
    r.location = r.location or location(line)
    local err = line:match("^error: (.+)$")
    if err then
      table.insert(r.errors, err)
    end
    if line:match("%S") and not line:match("I@[%d:.]+%s*$") then
      table.insert(r.output, line)
    end
  end
  return r
end

function M.tests(text)
  local tests, by_name, current = {}, {}, nil
  for _, line in ipairs(lines(text)) do
    local passed = line:match("^%s+ok (%S+) passed")
    local failed = line:match("^%s+%d+%) (%S+) failed")
    if passed or failed then
      local t = { name = passed or failed, ok = passed ~= nil }
      table.insert(tests, t)
      by_name[t.name] = t
    end
    local detail = line:match("^%s+%d+%) (%S+):$")
    if detail then
      current = by_name[detail]
    elseif current then
      current.message = current.message or line:match("Error %[QNT%d+%]: (.+)$")
      current.location = current.location or location(line)
    end
  end
  return tests
end

return M
