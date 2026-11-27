if vim.g.loaded_quint_infoview then
  return
end
vim.g.loaded_quint_infoview = true

local subcommands = {
  toggle = function()
    require("quint_infoview").toggle()
  end,
  run = function()
    require("quint_infoview").check(0, "run")
  end,
  verify = function()
    require("quint_infoview").check(0, "verify")
  end,
  main = function(arg)
    require("quint_infoview").pin(vim.api.nvim_get_current_buf(), arg)
  end,
  clear = function()
    require("quint_infoview").clear(vim.api.nvim_get_current_buf())
  end,
}

vim.api.nvim_create_user_command("QuintInfo", function(opts)
  local name, arg = opts.args:match("^(%S*)%s*(.-)%s*$")
  local fn = subcommands[name ~= "" and name or "toggle"]
  if not fn then
    vim.notify("QuintInfo: unknown subcommand " .. name, vim.log.levels.ERROR)
    return
  end
  fn(arg)
end, {
  nargs = "*",
  complete = function(lead, line)
    if line:match("^%S+%s+main%s") then
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      return vim.tbl_map(function(m)
        return m.name
      end, require("quint_infoview.source").scan(lines).modules)
    end
    return vim.tbl_filter(function(s)
      return s:find("^" .. vim.pesc(lead))
    end, vim.tbl_keys(subcommands))
  end,
})
