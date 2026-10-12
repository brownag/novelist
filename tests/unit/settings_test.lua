local h = require('tests.helpers')
local settings = require('novelist.settings')

local function win_for(bufnr)
  local winid = vim.fn.bufwinid(bufnr)
  h.assert_true(winid ~= -1, 'test buffer must be visible')
  return winid
end

local function set_local(bufnr, name, value)
  local ok = pcall(vim.api.nvim_set_option_value, name, value, { buf = bufnr })
  if not ok then
    vim.api.nvim_set_option_value(name, value, { win = win_for(bufnr) })
  end
end

local function get_local(bufnr, name)
  local ok, value = pcall(vim.api.nvim_get_option_value, name, { buf = bufnr })
  if ok then
    return value
  end
  return vim.api.nvim_get_option_value(name, { win = win_for(bufnr) })
end

local function make_buffer(filetype, lines)
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = filetype
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { 'Draft text.' })
  return bufnr, previous
end

local function cleanup(bufnr, previous)
  if vim.api.nvim_buf_is_valid(previous) then
    vim.api.nvim_set_current_buf(previous)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

local function with_buffer(filetype, lines, fn)
  local bufnr, previous = make_buffer(filetype, lines)
  local ok, err = xpcall(function()
    fn(bufnr)
  end, debug.traceback)
  cleanup(bufnr, previous)
  if not ok then
    error(err, 0)
  end
end

local function set_non_prose_values(bufnr)
  set_local(bufnr, 'spell', false)
  set_local(bufnr, 'spelllang', 'en_gb')
  set_local(bufnr, 'wrap', false)
  set_local(bufnr, 'linebreak', false)
  set_local(bufnr, 'breakindent', false)
  set_local(bufnr, 'textwidth', 72)
end

local function assert_non_prose_values(bufnr)
  h.assert_false(get_local(bufnr, 'spell'))
  h.assert_equal('en_gb', get_local(bufnr, 'spelllang'))
  h.assert_false(get_local(bufnr, 'wrap'))
  h.assert_false(get_local(bufnr, 'linebreak'))
  h.assert_false(get_local(bufnr, 'breakindent'))
  h.assert_equal(72, get_local(bufnr, 'textwidth'))
end

h.test('settings applies prose defaults locally for supported buffers', function()
  with_buffer('markdown', { '# Scene', 'Words stay intact.' }, function(bufnr)
    set_non_prose_values(bufnr)

    h.assert_true(settings.apply(bufnr, {}))

    h.assert_true(get_local(bufnr, 'spell'))
    h.assert_equal('en_us', get_local(bufnr, 'spelllang'))
    h.assert_true(get_local(bufnr, 'wrap'))
    h.assert_true(get_local(bufnr, 'linebreak'))
    h.assert_true(get_local(bufnr, 'breakindent'))
    h.assert_equal(0, get_local(bufnr, 'textwidth'))
    h.assert_equal('# Scene\nWords stay intact.', table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n'))
  end)
end)

h.test('settings applies configured spell language without mutating input', function()
  with_buffer('text', nil, function(bufnr)
    local config = { spelllang = { 'en_gb', 'fr' } }

    h.assert_true(settings.apply(bufnr, config))

    h.assert_equal('en_gb,fr', get_local(bufnr, 'spelllang'))
    h.assert_equal('en_gb', config.spelllang[1])
    h.assert_equal('fr', config.spelllang[2])
  end)
end)

h.test('settings skips when disabled globally', function()
  with_buffer('markdown', nil, function(bufnr)
    set_non_prose_values(bufnr)

    h.assert_false(settings.apply(bufnr, { enabled = false }))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings skips unsupported filetypes', function()
  with_buffer('lua', nil, function(bufnr)
    set_non_prose_values(bufnr)

    h.assert_false(settings.apply(bufnr, {}))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings skips buffer opt-out', function()
  with_buffer('markdown', nil, function(bufnr)
    set_non_prose_values(bufnr)
    vim.b[bufnr].novelist_disable = true

    h.assert_false(settings.apply(bufnr, {}))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings leaves unrelated local options and global options unchanged', function()
  with_buffer('markdown', { 'One', 'Two' }, function(bufnr)
    local global_textwidth = vim.go.textwidth
    local global_shiftwidth = vim.go.shiftwidth
    vim.bo[bufnr].shiftwidth = 6

    h.assert_true(settings.apply(bufnr, {}))

    h.assert_equal(6, vim.bo[bufnr].shiftwidth)
    h.assert_equal(global_textwidth, vim.go.textwidth)
    h.assert_equal(global_shiftwidth, vim.go.shiftwidth)
    h.assert_equal('One\nTwo', table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n'))
  end)
end)
