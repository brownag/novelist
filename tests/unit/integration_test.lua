local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local vale = require('novelist.vale')

local with_buffer = h.with_buffer
local get_local = h.get_local_option
local set_non_prose_values = h.set_non_prose_options
local assert_non_prose_values = h.assert_non_prose_options

local function require_fresh_novelist(opts)
  package.loaded['novelist'] = nil
  local novelist = require('novelist')
  novelist.setup(opts or {})
  return novelist
end

local function with_vale_process(stub, fn)
  local original = vale.process
  vale.process = stub
  local ok, err = xpcall(fn, debug.traceback)
  vale.process = original
  if not ok then
    error(err, 0)
  end
end

local function pump_until(predicate)
  return vim.wait(1000, predicate, 10)
end

local function with_loclist_cleanup(fn)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    vim.fn.setloclist(winid, {}, ' ')
  end
  local ok, err = xpcall(fn, debug.traceback)
  pcall(vim.cmd, 'lclose')
  if not ok then
    error(err, 0)
  end
end

local function capture_notifications(fn)
  local original = vim.notify
  local messages = {}
  vim.notify = function(message, level)
    table.insert(messages, { message = message, level = level })
  end
  local ok, err = xpcall(function()
    fn()
    vim.wait(50)
  end, debug.traceback)
  vim.notify = original
  if not ok then
    error(err, 0)
  end
  return messages
end

local function vale_stdout(path, alerts)
  return vim.json.encode({ [path] = alerts })
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
  end, { name = filename, close_quickfix = true })
end)

h.test('marker listing keeps focus in the source window so a filter can follow', function()
  require_fresh_novelist()

  with_buffer({ '# One', '@who: Mira', 'Body', '@todo: Revise ending' }, function(bufnr)
    local source_win = vim.api.nvim_get_current_win()

    vim.cmd('NovelistMarkers')
    h.assert_equal(2, #vim.fn.getqflist())
    h.assert_true(qf_window_count() > 0)
    h.assert_equal(source_win, vim.api.nvim_get_current_win(), 'focus should stay in the source window')
    h.assert_equal(bufnr, vim.api.nvim_get_current_buf())

    vim.cmd('NovelistMarkers todo')
    local items = vim.fn.getqflist()
    h.assert_equal(1, #items)
    h.assert_equal(4, items[1].lnum)
    h.assert_equal('@todo: Revise ending', items[1].text)

    vim.cmd('cclose')
    vim.fn.setqflist({}, 'r')
  end, { close_quickfix = true })
end)

h.test('setup installs no default keymaps', function()
  local before = keymap_count()
  require_fresh_novelist()
  h.assert_equal(before, keymap_count())
  h.assert_equal('', vim.fn.maparg('<Plug>(novelist-scene-next)', 'n'))
end)

h.test('vale command registers and rejects unsupported filetypes', function()
  require_fresh_novelist()

  local commands = vim.api.nvim_get_commands({ builtin = false })
  h.assert_true(commands.NovelistVale ~= nil)

  local calls = 0
  with_vale_process(function()
    calls = calls + 1
  end, function()
    local messages = capture_notifications(function()
      with_buffer({ 'local x = 1' }, function(bufnr)
        vim.bo[bufnr].filetype = 'lua'
        vim.cmd('NovelistVale')
      end)
    end)

    h.assert_equal(0, calls)
    h.assert_equal(1, #messages)
    h.assert_true(messages[1].message:match('markdown and text') ~= nil)
  end)
end)

h.test('vale command lints unsaved markdown lines into the invoking window location list', function()
  require_fresh_novelist()

  local filename = root .. '/tests/unit/sample-vale.md'
  local stdout = vale_stdout(filename, {
    {
      Span = { 4, 8 },
      Check = 'Vale.Repetition',
      Message = "'is' is repeated!",
      Severity = 'warning',
      Match = 'is is',
      Line = 2,
    },
  })
  local invocation = {}

  with_loclist_cleanup(function()
    with_buffer({ 'First line.', 'Placeholder.' }, function(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Edited first.', 'Edited second.' })

      with_vale_process(function(argv, stdin, on_exit)
        invocation.argv = argv
        invocation.stdin = stdin
        on_exit({ code = 1, stdout = stdout, stderr = '' })
      end, function()
        vim.cmd('NovelistVale')
      end)

      local winid = h.win_for(bufnr)
      h.assert_true(pump_until(function()
        return #vim.fn.getloclist(winid) > 0
      end))

      h.assert_equal('vale', invocation.argv[1])
      h.assert_equal('Edited first.\nEdited second.', invocation.stdin)

      local items = vim.fn.getloclist(winid)
      h.assert_equal(1, #items)
      h.assert_equal(2, items[1].lnum)
      h.assert_equal(4, items[1].col)
      h.assert_equal("'is' is repeated!", items[1].text)
      h.assert_equal(filename, vim.fn.bufname(items[1].bufnr))
      h.assert_equal(0, #vim.fn.getqflist())
    end, { name = filename, filetype = 'markdown' })
  end)
end)

h.test('vale command supports text buffers with extension and path context', function()
  require_fresh_novelist()

  local unnamed_invocation = {}
  local unnamed_stdout = vale_stdout('[No Name]', {
    { Span = { 1, 5 }, Check = 'Vale.Spelling', Message = 'Typo', Severity = 'error', Match = 'teh', Line = 1 },
  })

  with_loclist_cleanup(function()
    with_buffer({ 'teh cat.' }, function(bufnr)
      vim.bo[bufnr].filetype = 'text'

      with_vale_process(function(argv, stdin, on_exit)
        unnamed_invocation.argv = argv
        unnamed_invocation.stdin = stdin
        on_exit({ code = 1, stdout = unnamed_stdout, stderr = '' })
      end, function()
        vim.cmd('NovelistVale')
      end)

      local winid = h.win_for(bufnr)
      h.assert_true(pump_until(function()
        return #vim.fn.getloclist(winid) > 0
      end))

      h.assert_true(vim.tbl_contains(unnamed_invocation.argv, '--ext=.txt'))
      h.assert_equal('teh cat.', unnamed_invocation.stdin)
      h.assert_equal(1, #vim.fn.getloclist(winid))
    end)
  end)

  local filename = root .. '/tests/unit/sample-vale.txt'
  local named_invocation = {}
  local named_stdout = vale_stdout(filename, {
    { Span = { 2, 5 }, Check = 'Vale.Spelling', Message = 'Typo again', Severity = 'error', Match = 'teh', Line = 2 },
  })

  with_loclist_cleanup(function()
    with_buffer({ 'Fine.', 'teh cat.' }, function(bufnr)
      with_vale_process(function(argv, stdin, on_exit)
        named_invocation.argv = argv
        named_invocation.stdin = stdin
        on_exit({ code = 1, stdout = named_stdout, stderr = '' })
      end, function()
        vim.cmd('NovelistVale')
      end)

      local winid = h.win_for(bufnr)
      h.assert_true(pump_until(function()
        return #vim.fn.getloclist(winid) > 0
      end))

      h.assert_true(vim.tbl_contains(named_invocation.argv, '--path=' .. filename))
      local items = vim.fn.getloclist(winid)
      h.assert_equal(1, #items)
      h.assert_equal(2, items[1].lnum)
      h.assert_equal('Typo again', items[1].text)
      h.assert_equal(0, #vim.fn.getqflist())
    end, { name = filename, filetype = 'text' })
  end)
end)

h.test('vale command notifies when there are no findings and adds no items', function()
  require_fresh_novelist()

  local filename = root .. '/tests/unit/sample-vale.md'

  with_loclist_cleanup(function()
    with_buffer({ 'Clean text.' }, function(bufnr)
      with_vale_process(function(argv, stdin, on_exit)
        on_exit({ code = 0, stdout = '{}', stderr = '' })
      end, function()
        local messages = capture_notifications(function()
          vim.cmd('NovelistVale')
        end)

        local winid = h.win_for(bufnr)
        h.assert_equal(0, #vim.fn.getloclist(winid))
        h.assert_equal(1, #messages)
        h.assert_true(messages[1].message:match('no Vale findings') ~= nil)
      end)
    end, { name = filename, filetype = 'markdown' })
  end)
end)

h.test('vale executable override is used and failures preserve the prior location list', function()
  require_fresh_novelist({ vale = { executable = '/opt/custom-vale' } })

  local filename = root .. '/tests/unit/sample-vale.md'
  local stdout = vale_stdout(filename, {
    { Span = { 1, 4 }, Check = 'Vale.Style', Message = 'Finding', Severity = 'warning', Match = 'word', Line = 1 },
  })
  local invocation = {}

  with_loclist_cleanup(function()
    with_buffer({ 'First finding.' }, function(bufnr)
      with_vale_process(function(argv, stdin, on_exit)
        invocation.argv = argv
        on_exit({ code = 1, stdout = stdout, stderr = '' })
      end, function()
        vim.cmd('NovelistVale')
      end)

      local winid = h.win_for(bufnr)
      h.assert_true(pump_until(function()
        return #vim.fn.getloclist(winid) == 1
      end))
      h.assert_equal('/opt/custom-vale', invocation.argv[1])

      local before = vim.fn.getloclist(winid)
      h.assert_equal('Finding', before[1].text)

      local messages
      with_vale_process(function(argv, stdin, on_exit)
        on_exit({ code = 2, stdout = '', stderr = 'E201: no styles' })
      end, function()
        messages = capture_notifications(function()
          vim.cmd('NovelistVale')
        end)
      end)

      h.assert_equal(1, #messages)
      h.assert_true(messages[1].message:match('Vale check failed') ~= nil)

      local after = vim.fn.getloclist(winid)
      h.assert_equal(#before, #after)
      h.assert_equal(before[1].text, after[1].text)
      h.assert_equal(0, #vim.fn.getqflist())
    end, { name = filename, filetype = 'markdown' })
  end)
end)

h.test('vale results are not applied when the invoking window changes buffer', function()
  require_fresh_novelist()

  local filename = root .. '/tests/unit/sample-vale.md'
  local stdout = vale_stdout(filename, {
    { Span = { 1, 4 }, Check = 'Vale.Style', Message = 'Finding', Severity = 'warning', Match = 'word', Line = 1 },
  })
  local on_exit_ref

  with_loclist_cleanup(function()
    with_buffer({ 'Source line.' }, function(bufnr)
      local winid = h.win_for(bufnr)

      with_vale_process(function(argv, stdin, on_exit)
        on_exit_ref = on_exit
      end, function()
        vim.cmd('NovelistVale')
      end)

      local unrelated_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(winid, unrelated_bufnr)

      local messages = capture_notifications(function()
        on_exit_ref({ code = 1, stdout = stdout, stderr = '' })
      end)

      h.assert_equal(0, #vim.fn.getloclist(winid))
      h.assert_equal(1, #messages)
      h.assert_true(messages[1].message:match('could not be displayed') ~= nil)

      vim.api.nvim_buf_delete(unrelated_bufnr, { force = true })
    end, { name = filename, filetype = 'markdown' })
  end)
end)

h.test('closed invoking window leaves unrelated location lists unchanged', function()
  require_fresh_novelist()

  local filename = root .. '/tests/unit/sample-vale.md'
  local unrelated_name = root .. '/tests/unit/sample-unrelated.txt'
  local stdout = vale_stdout(filename, {
    { Span = { 1, 4 }, Check = 'Vale.Style', Message = 'Finding', Severity = 'warning', Match = 'word', Line = 1 },
  })
  local on_exit_ref

  local unrelated_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(unrelated_bufnr, unrelated_name)
  vim.api.nvim_buf_set_lines(unrelated_bufnr, 0, -1, false, { 'Unrelated text.' })
  local invoking_win = vim.api.nvim_get_current_win()

  local ok, err = xpcall(function()
    vim.cmd('split')
    local unrelated_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(unrelated_win, unrelated_bufnr)
    vim.fn.setloclist(unrelated_win, {}, ' ', {
      title = 'Unrelated',
      items = { { filename = unrelated_name, lnum = 1, col = 1, text = 'baseline' } },
    })

    vim.api.nvim_set_current_win(invoking_win)

    with_buffer({ 'Source line.' }, function(source_bufnr)
      local source_win = h.win_for(source_bufnr)

      with_vale_process(function(argv, stdin, on_exit)
        on_exit_ref = on_exit
      end, function()
        vim.api.nvim_set_current_win(source_win)
        vim.cmd('NovelistVale')
      end)

      local messages = capture_notifications(function()
        vim.api.nvim_set_current_win(source_win)
        vim.cmd('close!')
        on_exit_ref({ code = 1, stdout = stdout, stderr = '' })
      end)

      local remaining = vim.fn.getloclist(unrelated_win)
      h.assert_equal(1, #remaining)
      h.assert_equal('baseline', remaining[1].text)
      h.assert_equal(1, #messages)
      h.assert_true(messages[1].message:match('could not be displayed') ~= nil)
    end, { name = filename, filetype = 'markdown' })
  end, debug.traceback)

  if vim.api.nvim_buf_is_valid(unrelated_bufnr) then
    vim.api.nvim_buf_delete(unrelated_bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)

h.test('plugin exposes a semver version and NovelistVersion reports it', function()
  local novelist = require_fresh_novelist()

  h.assert_true(type(novelist.version) == 'string')
  h.assert_true(novelist.version:match('^%d+%.%d+%.%d+$') ~= nil, 'version must be MAJOR.MINOR.PATCH')

  local commands = vim.api.nvim_get_commands({ builtin = false })
  h.assert_true(commands.NovelistVersion ~= nil)

  local messages = capture_notifications(function()
    vim.cmd('NovelistVersion')
  end)
  h.assert_equal(1, #messages)
  h.assert_equal('novelist ' .. novelist.version, messages[1].message)
end)
