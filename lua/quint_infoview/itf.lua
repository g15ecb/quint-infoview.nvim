local M = {}

local function is_unit(v)
  return type(v) == "table" and ((v["#tup"] ~= nil and #v["#tup"] == 0) or v.tag == "UNIT")
end

local function is_variant(v)
  return v.tag ~= nil and v.value ~= nil and vim.tbl_count(v) == 2
end

local function join(items)
  return table.concat(vim.tbl_map(M.show, items), ", ")
end

function M.show(v)
  if type(v) == "string" then
    return '"' .. v .. '"'
  end
  if type(v) ~= "table" then
    return tostring(v)
  end
  if v["#bigint"] then
    return v["#bigint"]
  end
  if v["#tup"] then
    return "(" .. join(v["#tup"]) .. ")"
  end
  if v["#set"] then
    return "Set(" .. join(v["#set"]) .. ")"
  end
  if v["#map"] then
    local pairs_ = vim.tbl_map(function(kv)
      return M.show(kv[1]) .. " -> " .. M.show(kv[2])
    end, v["#map"])
    return "Map(" .. table.concat(pairs_, ", ") .. ")"
  end
  if is_variant(v) then
    return is_unit(v.value) and v.tag or v.tag .. "(" .. M.show(v.value) .. ")"
  end
  if vim.islist(v) then
    return "[" .. join(v) .. "]"
  end
  local keys = vim.tbl_keys(v)
  table.sort(keys)
  local fields = vim.tbl_map(function(k)
    return k .. ": " .. M.show(v[k])
  end, keys)
  return "{ " .. table.concat(fields, ", ") .. " }"
end

local function picks(state)
  local out = {}
  for name, pick in pairs(state["mbt::nondetPicks"] or {}) do
    if pick.tag == "Some" then
      table.insert(out, name .. " = " .. M.show(pick.value))
    end
  end
  table.sort(out)
  return out
end

function M.steps(doc)
  local vars, seen = {}, {}
  for _, var in ipairs(doc.vars) do
    if not var:find("^mbt::") and not seen[var] then
      seen[var] = true
      table.insert(vars, var)
    end
  end
  local steps, prev = {}, {}
  for i, state in ipairs(doc.states) do
    local values = {}
    for _, var in ipairs(vars) do
      local value = M.show(state[var])
      table.insert(values, { name = var:match("([^:]+)$"), value = value, changed = prev[var] ~= value })
      prev[var] = value
    end
    table.insert(steps, { index = i - 1, action = state["mbt::actionTaken"], picks = picks(state), vars = values })
  end
  return steps
end

function M.read(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  local ok, doc = pcall(vim.json.decode, text)
  return ok and M.steps(doc) or nil
end

return M
