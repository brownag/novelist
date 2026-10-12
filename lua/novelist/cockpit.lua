local M = {}

M.default_markers = {
  who = 'Viewpoint character first, followed by other important people in the scene.',
  what = 'Central event, conflict, or change in the scene.',
  where = 'Scene location.',
  when = 'Placement in the story chronology.',
  why = 'Why the scene matters: its purpose, stakes, or cause in the story.',
  todo = 'Unresolved drafting/revision task; may appear anywhere and repeat.',
}

function M.resolve_markers(markers)
  local resolved = {}

  for name, description in pairs(M.default_markers) do
    resolved[name] = description
  end

  if markers then
    for name, description in pairs(markers) do
      if description == false then
        resolved[name] = nil
      else
        resolved[name] = description
      end
    end
  end

  return resolved
end

local function normalize_markers(markers)
  if markers == nil then
    return M.resolve_markers()
  end
  return M.resolve_markers(markers)
end

local function parse_heading(line, line_number)
  local _, hashes, _, text = line:match('^(%s*)(#+)(%s+)(.*)$')
  if not hashes then
    return nil
  end

  local level = #hashes
  if level < 1 or level > 6 then
    return nil
  end

  return {
    line = line_number,
    level = level,
    text = text,
    raw = line,
  }
end

function M.headings(lines)
  local headings = {}

  for index, line in ipairs(lines or {}) do
    local heading = parse_heading(line, index)
    if heading then
      table.insert(headings, heading)
    end
  end

  return headings
end

function M.sections(lines)
  lines = lines or {}
  local headings = M.headings(lines)

  if #headings == 0 then
    return {
      {
        start_line = 1,
        end_line = #lines,
        heading = nil,
      },
    }
  end

  local sections = {}
  for index, heading in ipairs(headings) do
    local next_heading = headings[index + 1]
    table.insert(sections, {
      start_line = heading.line,
      end_line = next_heading and (next_heading.line - 1) or #lines,
      heading = heading,
    })
  end

  return sections
end

function M.section_at(lines, line_number)
  line_number = line_number or 1
  local sections = M.sections(lines)
  local fallback = sections[#sections]

  for _, section in ipairs(sections) do
    if line_number >= section.start_line and line_number <= section.end_line then
      return section
    end
  end

  if sections[1] and line_number < sections[1].start_line then
    return sections[1]
  end

  return fallback
end

function M.next_heading(lines, line_number)
  for _, heading in ipairs(M.headings(lines)) do
    if heading.line > line_number then
      return heading
    end
  end

  return nil
end

function M.previous_heading(lines, line_number)
  local previous = nil

  for _, heading in ipairs(M.headings(lines)) do
    if heading.line >= line_number then
      return previous
    end
    previous = heading
  end

  return previous
end

local function marker_match(line, markers)
  local name, value = line:match('^%s*@([%w_-]+):%s*(.-)%s*$')
  if not name or markers[name] == nil then
    return nil
  end

  return {
    name = name,
    value = value,
    raw = line,
    text = line,
    description = markers[name],
  }
end

local function count_line_words(line)
  local count = 0
  for _ in line:gmatch('%S+') do
    count = count + 1
  end
  return count
end

local function countable_line(line, line_number, markers)
  if marker_match(line, markers) then
    return nil
  end

  local heading = parse_heading(line, line_number)
  if heading then
    return heading.text
  end

  return line
end

function M.count_words_in_range(lines, start_line, end_line, markers)
  lines = lines or {}
  markers = normalize_markers(markers)

  local count = 0
  start_line = math.max(start_line or 1, 1)
  end_line = math.min(end_line or #lines, #lines)

  for line_number = start_line, end_line do
    local line = countable_line(lines[line_number] or '', line_number, markers)
    if line then
      count = count + count_line_words(line)
    end
  end

  return count
end

function M.document_word_count(lines, markers)
  return M.count_words_in_range(lines, 1, #(lines or {}), markers)
end

function M.section_word_count(lines, line_number, markers)
  local section = M.section_at(lines, line_number or 1)
  return M.count_words_in_range(lines, section.start_line, section.end_line, markers)
end

function M.find_markers(lines, markers, filter_name)
  markers = normalize_markers(markers)
  local occurrences = {}

  for line_number, line in ipairs(lines or {}) do
    local occurrence = marker_match(line, markers)
    if occurrence and (not filter_name or occurrence.name == filter_name) then
      occurrence.line = line_number
      table.insert(occurrences, occurrence)
    end
  end

  return occurrences
end

return M
