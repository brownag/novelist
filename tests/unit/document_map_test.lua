local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local document_map = require('novelist.document_map')

local unpack_values = table.unpack or unpack

local function fake_node(node_type, range, children)
  local node = {
    _type = node_type,
    _range = range,
    _children = children or {},
  }

  function node:type()
    return self._type
  end

  function node:range()
    return unpack_values(self._range)
  end

  function node:named()
    return true
  end

  function node:iter_children()
    local index = 0
    return function()
      index = index + 1
      return self._children[index]
    end
  end

  return node
end

local function fake_tree(root_node)
  return {
    root = function()
      return root_node
    end,
  }
end

local function get_tree_returning(root_node)
  return function()
    return fake_tree(root_node)
  end
end

local function heading(lines, row, level)
  local hashes = string.rep('#', level)
  return fake_node('atx_heading', { row, 0, row, #lines[row + 1] }, {
    fake_node('atx_h' .. level .. '_marker', { row, 0, row, #hashes }, {}),
  })
end

h.test('builds a heading hierarchy with source lines from a parsed tree', function()
  local lines = { '# Chapter', 'Body.', '## Scene', 'Body.', '### Beat' }
  local root_node = fake_node('document', { 0, 0, #lines, 0 }, {
    heading(lines, 0, 1),
    heading(lines, 2, 2),
    heading(lines, 4, 3),
  })

  local outline = document_map.build(lines, {
    filetype = 'markdown',
    get_tree = get_tree_returning(root_node),
  })

  h.assert_true(outline.rich)
  h.assert_equal(3, #outline.entries)
  h.assert_equal('heading', outline.entries[1].kind)
  h.assert_equal(1, outline.entries[1].line)
  h.assert_equal(1, outline.entries[1].level)
  h.assert_equal(1, outline.entries[1].depth)
  h.assert_equal('Chapter', outline.entries[1].label)
  h.assert_equal(3, outline.entries[2].line)
  h.assert_equal(2, outline.entries[2].level)
  h.assert_equal(2, outline.entries[2].depth)
  h.assert_equal('Scene', outline.entries[2].label)
  h.assert_equal(5, outline.entries[3].line)
  h.assert_equal(3, outline.entries[3].level)
  h.assert_equal('Beat', outline.entries[3].label)
end)

h.test('classifies heading-like text inside a fence as a code block', function()
  local lines = { '# Title', '```lua', '# not a heading', 'print(1)', '```' }
  local fence = fake_node('fenced_code_block', { 1, 0, 4, 3 }, {
    fake_node('info_string', { 1, 3, 1, 6 }, {}),
  })
  local root_node = fake_node('document', { 0, 0, #lines, 0 }, { heading(lines, 0, 1), fence })

  local outline = document_map.build(lines, { get_tree = get_tree_returning(root_node) })

  local kinds = {}
  for _, entry in ipairs(outline.entries) do
    kinds[entry.line] = entry.kind
  end

  h.assert_true(outline.rich)
  h.assert_equal(2, #outline.entries)
  h.assert_equal('heading', kinds[1])
  h.assert_equal('code_block', kinds[2])
  h.assert_equal(nil, kinds[3])
  h.assert_equal('code block (lua)', outline.entries[2].label)
  h.assert_equal(2, outline.entries[2].line)
end)

h.test('extracts list, nested list, blockquote, and table entries', function()
  local lines = {
    '- first',
    '  - nested',
    '- second',
    '',
    '> quote here',
    '',
    '| a | b |',
    '| - | - |',
    '| 1 | 2 |',
  }

  local first_item = fake_node('list_item', { 0, 0, 1, 0 }, {
    fake_node('list', { 1, 2, 2, 0 }, {
      fake_node('list_item', { 1, 2, 2, 0 }, {}),
    }),
  })
  local second_item = fake_node('list_item', { 2, 0, 3, 0 }, {})
  local list = fake_node('list', { 0, 0, 3, 0 }, { first_item, second_item })

  local quote = fake_node('block_quote', { 4, 0, 5, 0 }, {})

  local table_node = fake_node('pipe_table', { 6, 0, 9, 0 }, {
    fake_node('pipe_table_header', { 6, 0, 6, 9 }, {
      fake_node('pipe_table_cell', { 6, 2, 6, 4 }, {}),
      fake_node('pipe_table_cell', { 6, 6, 6, 8 }, {}),
    }),
  })

  local root_node = fake_node('document', { 0, 0, #lines, 0 }, { list, quote, table_node })

  local outline = document_map.build(lines, { get_tree = get_tree_returning(root_node) })
  local entries = outline.entries

  h.assert_equal(5, #entries)
  h.assert_equal('list_item', entries[1].kind)
  h.assert_equal(1, entries[1].line)
  h.assert_equal('first', entries[1].label)
  h.assert_equal(1, entries[1].depth)
  h.assert_equal('list_item', entries[2].kind)
  h.assert_equal(2, entries[2].line)
  h.assert_equal('nested', entries[2].label)
  h.assert_equal(2, entries[2].depth)
  h.assert_equal('list_item', entries[3].kind)
  h.assert_equal(3, entries[3].line)
  h.assert_equal('second', entries[3].label)
  h.assert_equal(1, entries[3].depth)
  h.assert_equal('block_quote', entries[4].kind)
  h.assert_equal(5, entries[4].line)
  h.assert_equal('quote here', entries[4].label)
  h.assert_equal('table', entries[5].kind)
  h.assert_equal(7, entries[5].line)
  h.assert_equal('a | b', entries[5].label)
end)

h.test('merges configured markers and omits disabled ones', function()
  local lines = { '# Scene', '@todo: cut this', '@mood: tense', '@who: Mira' }
  local root_node = fake_node('document', { 0, 0, #lines, 0 }, { heading(lines, 0, 1) })

  local outline = document_map.build(lines, {
    get_tree = get_tree_returning(root_node),
    markers = { todo = false, mood = 'Scene mood.' },
  })

  h.assert_true(outline.rich)
  h.assert_equal(3, #outline.entries)
  h.assert_equal('marker', outline.entries[2].kind)
  h.assert_equal('mood', outline.entries[2].marker)
  h.assert_equal('@mood: tense', outline.entries[2].label)
  h.assert_equal(3, outline.entries[2].line)
  h.assert_equal('who', outline.entries[3].marker)
  h.assert_equal(4, outline.entries[3].line)
end)

h.test('falls back to line-based headings when the parser is unavailable', function()
  local lines = { '# Real heading', 'Body.', '```', '# fence text', '```' }

  local outline = document_map.build(lines, { get_tree = function() return nil end })

  h.assert_false(outline.rich)
  h.assert_true(type(outline.reason) == 'string')

  local heading_lines = {}
  for _, entry in ipairs(outline.entries) do
    if entry.kind == 'heading' then
      table.insert(heading_lines, entry.line)
    end
  end

  h.assert_equal(2, #heading_lines)
  h.assert_equal(1, heading_lines[1])
  h.assert_equal(4, heading_lines[2])
end)

h.test('falls back without raising when the parser errors', function()
  local lines = { '# Heading', '@todo: marker' }
  local outline = document_map.build(lines, {
    get_tree = function()
      error('parser exploded')
    end,
  })

  h.assert_false(outline.rich)
  h.assert_equal(2, #outline.entries)
  h.assert_equal('heading', outline.entries[1].kind)
  h.assert_equal('marker', outline.entries[2].kind)
end)

h.test('skips Tree-sitter for plain text buffers', function()
  local lines = { '# Heading', '- item' }
  local called = false
  local root_node = fake_node('document', { 0, 0, #lines, 0 }, {
    heading(lines, 0, 1),
    fake_node('list_item', { 1, 0, 2, 0 }, {}),
  })

  local outline = document_map.build(lines, {
    filetype = 'text',
    get_tree = function()
      called = true
      return fake_tree(root_node)
    end,
  })

  h.assert_false(called)
  h.assert_false(outline.rich)
  h.assert_equal(1, #outline.entries)
  h.assert_equal('heading', outline.entries[1].kind)
end)

local function has_markdown_parser()
  local ok, parser = pcall(vim.treesitter.get_string_parser, '# probe', 'markdown')
  return ok and parser ~= nil
end

if has_markdown_parser() then
  h.test('parses a real Markdown tree when the grammar is installed', function()
    local lines = {
      '# Title',
      'Body.',
      '',
      '```lua',
      '# not a heading',
      '```',
      '- item',
      '',
      '> quote',
    }

    local outline = document_map.build(lines, { filetype = 'markdown' })

    h.assert_true(outline.rich)
    local kinds = {}
    for _, entry in ipairs(outline.entries) do
      kinds[entry.line] = entry.kind
    end
    h.assert_equal('heading', kinds[1])
    h.assert_equal('code_block', kinds[4])
    h.assert_equal(nil, kinds[5])
    h.assert_equal('list_item', kinds[7])
    h.assert_equal('block_quote', kinds[9])
  end)
end
