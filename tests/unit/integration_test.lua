local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local function require_fresh_novelist(opts)
  package.loaded['novelist'] = nil
  local novelist = require('novelist')
  novelist.setup(opts or {})
  return novelist
end

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

local function make_buffer(lines, name)
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  if name then
    vim.api.nvim_buf_set_name(bufnr, name)
  end
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { 'Draft text.' })
  return bufnr, previous
end

local function cleanup(bufnr, previous)
  pcall(vim.cmd, 'cclose')
  if vim.api.nvim_buf_is_valid(previous) then
    pcall(vim.api.nvim_set_current_buf, previous)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

local function with_buffer(lines, fn, name)
  local bufnr, previous = make_buffer(lines, name)
  local ok, err = xpcall(function()
    fn(bufnr)
  end, debug.traceback)
  cleanup(bufnr, previous)
  if not ok then
    error(err, 0)
  end
end

local function qf_window_count()
  local count = 0
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.bo[bufnr].buftype == 'quickfix' then
      count = count + 1
    end
  end
  return count
end

local function keymap_count()
  local count = 0
  for _, mode in ipairs({ 'n', 'i', 'v', 'x', 'o' }) do
    count = count + #vim.api.nvim_get_keymap(mode)
  end
  return count
end

h.test('plugin runtime and repeated setup register lifecycle once and update config', function()
  package.loaded['novelist'] = nil
  dofile(root .. '/plugin/novelist.lua')

  local novelist = require('novelist')
  novelist.setup({ prose = { spelllang = { 'en_gb' } } })
  novelist.setup({ prose = { spelllang = { 'fr' } } })

  h.assert_equal('fr', novelist.get_config().prose.spelllang[1])

  local autocmds = vim.api.nvim_get_autocmds({ group = 'novelist_settings', event = 'FileType' })
  h.assert_equal(2, #autocmds)

  local commands = vim.api.nvim_get_commands({ builtin = false })
  h.assert_true(commands.NovelistSceneNext ~= nil)
  h.assert_true(commands.NovelistScenePrev ~= nil)
  h.assert_true(commands.NovelistWordCount ~= nil)
  h.assert_true(commands.NovelistMarkers ~= nil)
end)

h.test('repeated setup can replace filetypes with an empty list', function()
  local novelist = require_fresh_novelist()
  novelist.setup({ prose = { filetypes = { 'markdown' } } })
  novelist.setup({ prose = { filetypes = {} } })

  h.assert_equal(0, #novelist.get_config().prose.filetypes)
  local autocmds = vim.api.nvim_get_autocmds({ group = 'novelist_settings', event = 'FileType' })
  h.assert_equal(0, #autocmds)

  with_buffer({ '# Scene' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.bo[bufnr].filetype = 'markdown'

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings lifecycle applies on markdown and text FileType only', function()
  require_fresh_novelist()

  with_buffer({ '# Scene', 'Words.' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.bo[bufnr].filetype = 'markdown'

    h.assert_true(get_local(bufnr, 'spell'))
    h.assert_equal('en_us', get_local(bufnr, 'spelllang'))
    h.assert_true(get_local(bufnr, 'wrap'))
    h.assert_true(get_local(bufnr, 'linebreak'))
    h.assert_true(get_local(bufnr, 'breakindent'))
    h.assert_equal(0, get_local(bufnr, 'textwidth'))
  end)

  with_buffer({ 'Plain text.' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.bo[bufnr].filetype = 'text'

    h.assert_true(get_local(bufnr, 'spell'))
    h.assert_equal('en_us', get_local(bufnr, 'spelllang'))
  end)

  with_buffer({ 'print("no prose")' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.bo[bufnr].filetype = 'lua'

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings lifecycle honors global and buffer opt-outs', function()
  require_fresh_novelist({ prose = { enabled = false } })

  with_buffer({ '# Scene' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.bo[bufnr].filetype = 'markdown'

    assert_non_prose_values(bufnr)
  end)

  require_fresh_novelist()

  with_buffer({ '# Scene' }, function(bufnr)
    set_non_prose_values(bufnr)
    vim.b[bufnr].novelist_disable = true
    vim.bo[bufnr].filetype = 'markdown'

    assert_non_prose_values(bufnr)
  end)
end)

h.test('scene commands navigate headings and handle headingless buffers', function()
  require_fresh_novelist()

  with_buffer({ 'Preface', '# One', 'Body', '## Two', 'More' }, function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd('NovelistSceneNext')
    h.assert_equal(2, vim.api.nvim_win_get_cursor(0)[1])

    vim.cmd('NovelistSceneNext')
    h.assert_equal(4, vim.api.nvim_win_get_cursor(0)[1])

    vim.cmd('NovelistScenePrev')
    h.assert_equal(2, vim.api.nvim_win_get_cursor(0)[1])

    vim.cmd('NovelistScenePrev')
    h.assert_equal(2, vim.api.nvim_win_get_cursor(0)[1])
  end)

  with_buffer({ 'No headings here.' }, function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd('NovelistSceneNext')
    h.assert_equal(1, vim.api.nvim_win_get_cursor(0)[1])
  end)
end)

h.test('word count command notifies current section and document totals', function()
  require_fresh_novelist()

  local original_notify = vim.notify
  local messages = {}
  vim.notify = function(message, level)
    table.insert(messages, { message = message, level = level })
  end

  with_buffer({ '# One', 'two words', '@todo: ignored marker', '# Two', 'three words here' }, function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd('NovelistWordCount')
  end)

  vim.notify = original_notify

  h.assert_equal(1, #messages)
  h.assert_true(messages[1].message:match('section words: 3') ~= nil)
  h.assert_true(messages[1].message:match('document words: 7') ~= nil)
end)

h.test('marker command populates quickfix with filename line text and opens only on matches', function()
  require_fresh_novelist()

  local filename = root .. '/tests/unit/sample-markers.md'
  with_buffer({ '# One', '@who: Mira', 'Body', '@todo: Revise ending' }, function()
    vim.cmd('NovelistMarkers todo')

    local items = vim.fn.getqflist()
    h.assert_equal(1, #items)
    h.assert_equal(4, items[1].lnum)
    h.assert_equal('@todo: Revise ending', items[1].text)
    h.assert_equal(vim.fn.fnamemodify(filename, ':p'), vim.fn.fnamemodify(vim.fn.bufname(items[1].bufnr), ':p'))
    h.assert_true(qf_window_count() > 0)

    vim.cmd('cclose')
    vim.cmd('NovelistMarkers why')
    h.assert_equal(0, #vim.fn.getqflist())
    h.assert_equal(0, qf_window_count())
  end, filename)
end)

h.test('setup installs no default keymaps', function()
  local before = keymap_count()
  require_fresh_novelist()
  h.assert_equal(before, keymap_count())
  h.assert_equal('', vim.fn.maparg('<Plug>(novelist-scene-next)', 'n'))
end)
