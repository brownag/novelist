local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local with_buffer = h.with_buffer

local function require_fresh_novelist()
  package.loaded['novelist'] = nil
  local novelist = require('novelist')
  novelist.setup({})
  return novelist
end

local function outline_bufnr()
  local bufnr = vim.fn.bufnr('novelist://document-map')
  if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
  return nil
end

local function outline_lines()
  local bufnr = outline_bufnr()
  if not bufnr then
    return {}
  end
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function row_for(needle)
  for index, line in ipairs(outline_lines()) do
    if line:find(needle, 1, true) then
      return index
    end
  end
  return nil
end

local function close_outline()
  local bufnr = outline_bufnr()
  if not bufnr then
    return
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      pcall(vim.api.nvim_win_close, winid, true)
    end
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

local function with_map(lines, fn, opts)
  with_buffer(lines, function(source)
    local ok, err = xpcall(function()
      fn(source)
    end, debug.traceback)
    close_outline()
    if not ok then
      error(err, 0)
    end
  end, opts)
end

local function press_enter()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
end

local function has_markdown_parser()
  local ok, parser = pcall(vim.treesitter.get_string_parser, '# probe', 'markdown')
  return ok and parser ~= nil
end

h.test('document map falls back to heading rows and survives parser failure, empty documents, and a stale source', function()
  require_fresh_novelist()

  local before_windows = #vim.api.nvim_list_wins()

  with_map({ '# Chapter', 'Body.', '## Scene', '@todo: trim' }, function(source)
    vim.cmd('NovelistDocumentMap')

    h.assert_equal('row', vim.fn.winlayout()[1])
    h.assert_equal(before_windows + 1, #vim.api.nvim_list_wins())
    h.assert_true(vim.fn.bufwinid(source) ~= -1)
    h.assert_true(outline_bufnr() ~= nil)
    h.assert_true(outline_lines()[1]:find('parser unavailable', 1, true) ~= nil)
    h.assert_true(row_for('Chapter  [1]') ~= nil)
    h.assert_true(row_for('  Scene  [3]') ~= nil)
    h.assert_true(row_for('@todo: trim  [4]') ~= nil)
  end, { filetype = 'text' })

  local treesitter = vim.treesitter
  local original_parser = treesitter.get_string_parser
  treesitter.get_string_parser = function()
    error('no parser here')
  end
  local ok, err = pcall(function()
    with_map({ '# Heading', '@todo: marker' }, function(source)
      vim.cmd('NovelistDocumentMap')

      h.assert_true(outline_lines()[1]:find('parser unavailable', 1, true) ~= nil)
      h.assert_true(row_for('Heading  [1]') ~= nil)
      h.assert_true(row_for('@todo: marker  [2]') ~= nil)
      h.assert_true(vim.fn.bufwinid(source) ~= -1)
    end, { filetype = 'markdown' })
  end)
  treesitter.get_string_parser = original_parser
  if not ok then
    error(err, 0)
  end

  with_map({}, function()
    vim.cmd('NovelistDocumentMap')
    h.assert_true(row_for('no outline entries') ~= nil)
  end, { filetype = 'text' })

  with_map({ '# One', 'body' }, function(source)
    vim.cmd('NovelistDocumentMap')

    local row = row_for('One  [1]')
    h.assert_true(row ~= nil)

    local messages = {}
    local original_notify = vim.notify
    vim.notify = function(message, level)
      table.insert(messages, { message = message, level = level })
    end
    vim.api.nvim_buf_delete(source, { force = true })
    local map_window = vim.fn.bufwinid(outline_bufnr())
    if map_window ~= -1 then
      vim.api.nvim_set_current_win(map_window)
      vim.api.nvim_win_set_cursor(0, { row, 0 })
    end
    press_enter()
    vim.notify = original_notify

    h.assert_true(vim.api.nvim_buf_is_valid(outline_bufnr()))
    h.assert_true(#messages > 0)
    h.assert_true(messages[1].message:find('no longer available', 1, true) ~= nil)
  end, { filetype = 'text' })
end)

h.test('document map row jumps to the source buffer and line', function()
  require_fresh_novelist()

  with_map({ '# One', 'body', '## Two', 'body' }, function(source)
    vim.cmd('NovelistDocumentMap')

    local row = row_for('Two  [3]')
    h.assert_true(row ~= nil)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    press_enter()

    h.assert_equal(source, vim.api.nvim_get_current_buf())
    h.assert_equal(3, vim.api.nvim_win_get_cursor(0)[1])
  end, { filetype = 'text' })
end)

h.test('document map refreshes on re-run without live updates and reuses the outline buffer', function()
  require_fresh_novelist()

  with_map({ '# One', 'body' }, function(source)
    vim.cmd('NovelistDocumentMap')

    local mapbuf = outline_bufnr()
    h.assert_true(mapbuf ~= nil)
    h.assert_true(row_for('One  [1]') ~= nil)

    vim.api.nvim_buf_set_lines(source, -1, -1, false, { '# Two' })
    h.assert_true(row_for('Two') == nil)

    vim.api.nvim_set_current_win(vim.fn.bufwinid(source))
    vim.cmd('NovelistDocumentMap')

    h.assert_equal(mapbuf, outline_bufnr())
    h.assert_true(row_for('Two  [3]') ~= nil)
    h.assert_equal(2, #vim.api.nvim_list_wins())
  end, { filetype = 'text' })
end)

if has_markdown_parser() then
  h.test('document map renders rich markdown structure when a parser is available', function()
    require_fresh_novelist()

    with_map({
      '# Title',
      'Body.',
      '',
      '```lua',
      '# not a heading',
      'print(1)',
      '```',
      '',
      '- item',
      '',
      '> quote',
      '',
      '| a | b |',
      '| - | - |',
      '| 1 | 2 |',
    }, function()
      vim.cmd('NovelistDocumentMap')

      h.assert_true(row_for('Title  [1]') ~= nil)
      h.assert_true(row_for('code block (lua)  [4]') ~= nil)
      h.assert_true(row_for('not a heading') == nil)
      h.assert_true(row_for('item  [9]') ~= nil)
      h.assert_true(row_for('quote  [11]') ~= nil)
      h.assert_true(row_for('a | b  [13]') ~= nil)
      h.assert_true(table.concat(outline_lines(), '\n'):find('parser unavailable', 1, true) == nil)
    end, { filetype = 'markdown' })
  end)
end
