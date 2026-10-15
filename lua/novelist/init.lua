local settings = require('novelist.settings')

local M = {}

local augroup_name = 'novelist_settings'

local function copy_value(value)
  if type(value) ~= 'table' then
    return value
  end

  local copy = {}
  for key, child in pairs(value) do
    copy[key] = copy_value(child)
  end
  return copy
end

local function should_merge_table(target_value, source_value)
  if type(target_value) ~= 'table' or type(source_value) ~= 'table' then
    return false
  end
  return #target_value == 0 and #source_value == 0
end

local function merge_into(target, source)
  if type(source) ~= 'table' then
    return target
  end

  for key, value in pairs(source) do
    if should_merge_table(target[key], value) then
      merge_into(target[key], value)
    else
      target[key] = copy_value(value)
    end
  end

  return target
end

local function default_config()
  return {
    prose = copy_value(settings.defaults),
    markers = {},
    vale = { executable = 'vale' },
    keymaps = { preset = false, mappings = {} },
  }
end

M.config = default_config()

local function filetype_patterns(filetypes)
  local patterns = {}
  for key, value in pairs(filetypes or settings.defaults.filetypes) do
    if type(key) == 'string' and value then
      table.insert(patterns, key)
    elseif type(value) == 'string' then
      table.insert(patterns, value)
    end
  end
  table.sort(patterns)
  return patterns
end

local function register_autocmds()
  local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })
  local patterns = filetype_patterns(M.config.prose.filetypes)

  if #patterns == 0 then
    return
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = patterns,
    callback = function(args)
      settings.apply(args.buf, M.config.prose)
    end,
  })
end

function M.get_config()
  return M.config
end

function M.setup(opts)
  M.config = merge_into(M.config or default_config(), opts or {})
  register_autocmds()
  require('novelist.commands').register(M.get_config)
  require('novelist.keymaps').setup(M.config.keymaps)
  return M.config
end

return M
