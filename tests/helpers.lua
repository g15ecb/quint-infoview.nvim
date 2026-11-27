local H = {}

function H.read(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

function H.versions()
  return vim.fn.glob(_G.fixtures .. "/quint-*", false, true)
end

function H.eq(want, got, what)
  if not vim.deep_equal(want, got) then
    error(("%s: want %s, got %s"):format(what or "value", vim.inspect(want), vim.inspect(got)), 2)
  end
end

function H.truthy(v, what)
  if not v then
    error((what or "value") .. " is falsy", 2)
  end
end

function H.has_line(lines, pattern, what)
  for i, l in ipairs(lines) do
    if l:find(pattern) then
      return i
    end
  end
  error(("%s: no line matches %q in\n%s"):format(what or "lines", pattern, table.concat(lines, "\n")), 2)
end

function H.line_of(lines, pattern)
  for i, l in ipairs(lines) do
    if l:find(pattern) then
      return i
    end
  end
end

return H
