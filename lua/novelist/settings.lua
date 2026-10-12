local M = {}

M.defaults = {
  enabled = true,
  filetypes = { 'markdown', 'text' },
  spell = true,
  spelllang = { 'en_us' },
  wrap = true,
  linebreak = true,
  breakindent = true,
  textwidth = 0,
}

local function copy_list(values)
  local copy = {}
  for index, value in ipairs(values) do
    copy[index] = value
  end
  return copy
end

local function normalize_spelllang(value)
  if type(value) == 'table' then
    return table.concat(value, ',')
  end
  return value
end

local function filetype_supported(filetypes, filetype)
  for key, value in pairs(filetypes) do
    if value == filetype then
      return true
    end
    if key == filetype and value then
      return true
    end
  end
  return false
end

local function with_default(settings, key)
  if settings[key] ~= nil then
    return settings[key]
  end
  local default = M.defaults[key]
  if type(default) == 'table' then
    return copy_list(default)
  end
  return default
end

local function normalize(settings)
  settings = settings or {}
  return {
    enabled = with_default(settings, 'enabled'),
    filetypes = with_default(settings, 'filetypes'),
    spell = with_default(settings, 'spell'),
    spelllang = with_default(settings, 'spelllang'),
    wrap = with_default(settings, 'wrap'),
    linebreak = with_default(settings, 'linebreak'),
    breakindent = with_default(settings, 'breakindent'),
    textwidth = with_default(settings, 'textwidth'),
  }
end

local function set_local_option(bufnr, name, value)
  local ok = pcall(vim.api.nvim_set_option_value, name, value, { buf = bufnr })
  if ok then
    return
  end

  local winid = vim.fn.bufwinid(bufnr)
  if winid ~= -1 then
    vim.api.nvim_set_option_value(name, value, { win = winid })
  end
end

function M.apply(bufnr, settings)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local resolved = normalize(settings)
  if resolved.enabled == false then
    return false
  end

  if vim.b[bufnr].novelist_disable then
    return false
  end

  if not filetype_supported(resolved.filetypes, vim.bo[bufnr].filetype) then
    return false
  end

  set_local_option(bufnr, 'spell', resolved.spell)
  set_local_option(bufnr, 'spelllang', normalize_spelllang(resolved.spelllang))
  set_local_option(bufnr, 'wrap', resolved.wrap)
  set_local_option(bufnr, 'linebreak', resolved.linebreak)
  set_local_option(bufnr, 'breakindent', resolved.breakindent)
  set_local_option(bufnr, 'textwidth', resolved.textwidth)

  return true
end

return M
