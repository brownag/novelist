local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local cockpit = require('novelist.cockpit')

local function assert_nil(value, message)
  if value ~= nil then
    error(message or string.format('expected nil, got %s', tostring(value)), 2)
  end
end

h.test('parses ATX headings and section boundaries at any level', function()
  local lines = {
    '# Chapter One',
    'Opening words.',
    '  ## Scene A',
    'Scene words.',
    '### Beat',
    'Beat words.',
    '####### Not a heading',
    '# Chapter Two',
    'Closing words.',
  }

  local headings = cockpit.headings(lines)
  h.assert_equal(4, #headings)
  h.assert_equal(1, headings[1].line)
  h.assert_equal(1, headings[1].level)
  h.assert_equal('Chapter One', headings[1].text)
  h.assert_equal(3, headings[2].line)
  h.assert_equal(2, headings[2].level)
  h.assert_equal('Scene A', headings[2].text)
  h.assert_equal(5, headings[3].line)
  h.assert_equal(8, headings[4].line)

  local sections = cockpit.sections(lines)
  h.assert_equal(4, #sections)
  h.assert_equal(1, sections[1].start_line)
  h.assert_equal(2, sections[1].end_line)
  h.assert_equal(3, sections[2].start_line)
  h.assert_equal(4, sections[2].end_line)
  h.assert_equal(5, sections[3].start_line)
  h.assert_equal(7, sections[3].end_line)
  h.assert_equal(8, sections[4].start_line)
  h.assert_equal(9, sections[4].end_line)
end)

h.test('uses one implicit section for headingless documents', function()
  local sections = cockpit.sections({ 'No headings here.', '', 'Still one section.' })

  h.assert_equal(1, #sections)
  h.assert_equal(1, sections[1].start_line)
  h.assert_equal(3, sections[1].end_line)
  assert_nil(sections[1].heading)
end)

h.test('finds next and previous headings without including current heading', function()
  local lines = {
    'preface',
    '# First',
    'body',
    '## Second',
    'more',
    '# Third',
  }

  h.assert_equal(2, cockpit.next_heading(lines, 1).line)
  h.assert_equal(4, cockpit.next_heading(lines, 2).line)
  h.assert_equal(4, cockpit.next_heading(lines, 3).line)
  h.assert_equal(6, cockpit.next_heading(lines, 4).line)
  assert_nil(cockpit.next_heading(lines, 6))

  assert_nil(cockpit.previous_heading(lines, 1))
  assert_nil(cockpit.previous_heading(lines, 2))
  h.assert_equal(2, cockpit.previous_heading(lines, 3).line)
  h.assert_equal(2, cockpit.previous_heading(lines, 4).line)
  h.assert_equal(4, cockpit.previous_heading(lines, 5).line)
  h.assert_equal(4, cockpit.previous_heading(lines, 6).line)
  assert_nil(cockpit.next_heading({ 'only body' }, 1))
  assert_nil(cockpit.previous_heading({ 'only body' }, 1))
end)

h.test('counts document words with heading prefixes stripped and marker lines excluded', function()
  local lines = {
    '# First Scene',
    '@who: Mira, Ivo',
    'Mira trusts Ivo.',
    'Inline @todo: counts here.',
    '## Second Scene',
    'Two words',
  }

  h.assert_equal(13, cockpit.document_word_count(lines))
end)

h.test('counts the current section only', function()
  local lines = {
    '# First Scene',
    'first body words',
    '## Second Scene',
    '@todo: Cut this note',
    'second body',
    '# Third Scene',
    'third body words',
  }

  h.assert_equal(5, cockpit.section_word_count(lines, 2))
  h.assert_equal(4, cockpit.section_word_count(lines, 4))
  h.assert_equal(5, cockpit.section_word_count(lines, 7))
end)

h.test('resolves default marker metadata with overrides and disabled entries', function()
  h.assert_true(cockpit.default_markers.who:match('Viewpoint') ~= nil)
  h.assert_true(cockpit.default_markers.todo:match('revision task') ~= nil)

  local resolved = cockpit.resolve_markers({
    who = 'Cast present in the scene.',
    todo = false,
    mood = 'Scene mood.',
  })

  h.assert_equal('Cast present in the scene.', resolved.who)
  assert_nil(resolved.todo)
  h.assert_equal('Scene mood.', resolved.mood)
  h.assert_equal(cockpit.default_markers.what, resolved.what)
end)

h.test('extracts standalone configured markers with stable line numbers and raw text', function()
  local lines = {
    '  @who: Mira (POV), Ivo  ',
    'Text before @what: ignored',
    '@todo: Seed the seal earlier',
    '@unknown: ignored',
    '@todo: Tighten ending',
    ' @where: North bridge',
  }

  local occurrences = cockpit.find_markers(lines)
  h.assert_equal(4, #occurrences)
  h.assert_equal('who', occurrences[1].name)
  h.assert_equal(1, occurrences[1].line)
  h.assert_equal('  @who: Mira (POV), Ivo  ', occurrences[1].raw)
  h.assert_equal('Mira (POV), Ivo', occurrences[1].value)
  h.assert_equal('todo', occurrences[2].name)
  h.assert_equal(3, occurrences[2].line)
  h.assert_equal('Seed the seal earlier', occurrences[2].value)
  h.assert_equal('todo', occurrences[3].name)
  h.assert_equal(5, occurrences[3].line)
  h.assert_equal('where', occurrences[4].name)
  h.assert_equal(6, occurrences[4].line)
end)

h.test('honors configured, disabled, unknown, and filtered markers', function()
  local lines = {
    '@todo: disabled and counted',
    '@mood: tense',
    '@who: Mira',
    '@unknown: ignored',
  }
  local markers = { todo = false, mood = 'Scene mood.' }

  local occurrences = cockpit.find_markers(lines, markers)
  h.assert_equal(2, #occurrences)
  h.assert_equal('mood', occurrences[1].name)
  h.assert_equal(2, occurrences[1].line)
  h.assert_equal('who', occurrences[2].name)

  local mood_only = cockpit.find_markers(lines, markers, 'mood')
  h.assert_equal(1, #mood_only)
  h.assert_equal('mood', mood_only[1].name)

  h.assert_equal(6, cockpit.document_word_count(lines, markers))
end)
