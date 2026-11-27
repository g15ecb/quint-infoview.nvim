local M = {}

local decl_kinds = { invariant = true, observation = true, action = true, run = true, val = true, def = true, temporal = true }

function M.scan(lines)
  local modules, decls, current = {}, {}, nil
  for i, line in ipairs(lines) do
    local module = line:match("^%s*module%s+([%w_]+)")
    if module then
      current = { name = module, line = i, const = false }
      table.insert(modules, current)
    else
      local kind, name = line:gsub("^%s*pure%s+", ""):match("^%s*(%a+)%s+([%w_]+)")
      if current and kind == "const" then
        current.const = true
      elseif decl_kinds[kind] then
        table.insert(decls, { kind = kind, name = name, line = i, module = current and current.name })
      end
    end
  end
  return { modules = modules, decls = decls }
end

function M.main_module(scan, row)
  local at
  for _, m in ipairs(scan.modules) do
    if m.line <= row then
      at = m
    end
  end
  if at and not at.const then
    return at.name
  end
  for i = #scan.modules, 1, -1 do
    if not scan.modules[i].const then
      return scan.modules[i].name
    end
  end
end

function M.find(scan, name, kinds, module)
  local first
  for _, d in ipairs(scan.decls) do
    if d.name == name and vim.tbl_contains(kinds, d.kind) then
      if d.module == module then
        return d
      end
      first = first or d
    end
  end
  return first
end

function M.in_module(scan, kind, module)
  return vim.tbl_filter(function(d)
    return d.kind == kind and d.module == module
  end, scan.decls)
end

local function indent(line)
  return #line:match("^%s*")
end

function M.block(lines, start)
  local base, last = indent(lines[start]), start
  for i = start + 1, #lines do
    local line = lines[i]
    if line:match("%S") then
      if indent(line) <= base and not line:match("^%s*[}%)%]]") then
        break
      end
      last = i
    end
  end
  return start, last
end

return M
