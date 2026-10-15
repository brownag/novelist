local cockpit = require('novelist.cockpit')

local M = {}

M.kinds = {
  heading = 'heading',
  code_block = 'code_block',
  list_item = 'list_item',
  block_quote = 'block_quote',
  table = 'table',
  marker = 'marker',
}

local heading_marker_levels = {
  atx_h1_marker = 1,
  atx_h2_marker = 2,
  atx_h3_marker = 3,
  atx_h4_marker = 4,
  atx_h5_marker = 5,
  atx_h6_marker = 6,
}

local function line_text(lines, row)
  return lines[row + 1] or ''
end

local function first_line_text(lines, start_row, start_col, end_row, end_col)
  local text = line_text(lines, start_row)
  if start_row == end_row then
    return vim.trim(text:sub(start_col + 1, end_col))
  end
  return vim.trim(text:sub(start_col + 1))
end

local function node_text(lines, node)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row == end_row then
    return line_text(lines, start_row):sub(start_col + 1, end_col)
  end

  local parts = { line_text(lines, start_row):sub(start_col + 1) }
  for row = start_row + 1, end_row - 1 do
    table.insert(parts, line_text(lines, row))
  end
  table.insert(parts, line_text(lines, end_row):sub(1, end_col))
  return table.concat(parts, '\n')
end

local function child_of_type(node, wanted)
  for child in node:iter_children() do
    if child:type() == wanted then
      return child
    end
  end
  return nil
end

local function heading_level(node)
  for child in node:iter_children() do
    local level = heading_marker_levels[child:type()]
    if level then
      return level
    end
  end
  return nil
end

local function strip_atx(text)
  local stripped = text:gsub('^%s*#+%s?', '')
  stripped = stripped:gsub('%s*#+%s*$', '')
  return vim.trim(stripped)
end

local function strip_list_marker(text)
  local stripped = text:gsub('^%s*[-*+]%s+', '')
  stripped = stripped:gsub('^%s*%d+[.)]%s+', '')
  return vim.trim(stripped)
end

local function strip_quote_marker(text)
  return vim.trim((text:gsub('^%s*>%s?', '')))
end

local function fence_label(lines, node)
  local info = child_of_type(node, 'info_string')
  local language = info and vim.trim(node_text(lines, info)) or ''
  if language ~= '' then
    return string.format('code block (%s)', language)
  end
  return 'code block'
end

local function table_label(lines, node)
  local header = child_of_type(node, 'pipe_table_header')
  local cells = {}
  if header then
    for cell in header:iter_children() do
      if cell:type() == 'pipe_table_cell' then
        table.insert(cells, vim.trim(node_text(lines, cell)))
      end
    end
  end

  if #cells == 0 then
    return 'table'
  end
  return table.concat(cells, ' | ')
end

local function add_tree_entries(lines, root, entries)
  local function visit(node, list_depth)
    local node_type = node:type()
    local start_row, start_col, end_row, end_col = node:range()
    local line = start_row + 1
    local raw = line_text(lines, start_row)

    if node_type == 'atx_heading' then
      local level = heading_level(node) or 1
      table.insert(entries, {
        kind = M.kinds.heading,
        label = strip_atx(first_line_text(lines, start_row, start_col, end_row, end_col)),
        line = line,
        level = level,
        depth = level,
        raw = raw,
      })
    elseif node_type == 'fenced_code_block' then
      table.insert(entries, {
        kind = M.kinds.code_block,
        label = fence_label(lines, node),
        line = line,
        depth = 1,
        raw = raw,
      })
    elseif node_type == 'list_item' then
      table.insert(entries, {
        kind = M.kinds.list_item,
        label = strip_list_marker(first_line_text(lines, start_row, start_col, end_row, end_col)),
        line = line,
        depth = list_depth,
        raw = raw,
      })
    elseif node_type == 'block_quote' then
      table.insert(entries, {
        kind = M.kinds.block_quote,
        label = strip_quote_marker(first_line_text(lines, start_row, start_col, end_row, end_col)),
        line = line,
        depth = 1,
        raw = raw,
      })
    elseif node_type == 'pipe_table' then
      table.insert(entries, {
        kind = M.kinds.table,
        label = table_label(lines, node),
        line = line,
        depth = 1,
        raw = raw,
      })
    end

    local child_depth = node_type == 'list' and (list_depth + 1) or list_depth
    for child in node:iter_children() do
      visit(child, child_depth)
    end
  end

  visit(root, 0)
end

local function add_heading_entries(lines, entries)
  for _, heading in ipairs(cockpit.headings(lines)) do
    table.insert(entries, {
      kind = M.kinds.heading,
      label = heading.text,
      line = heading.line,
      level = heading.level,
      depth = heading.level,
      raw = heading.raw,
    })
  end
end

local function add_marker_entries(lines, markers, entries)
  for _, occurrence in ipairs(cockpit.find_markers(lines, markers)) do
    table.insert(entries, {
      kind = M.kinds.marker,
      label = string.format('@%s: %s', occurrence.name, occurrence.value),
      line = occurrence.line,
      depth = 1,
      marker = occurrence.name,
      value = occurrence.value,
      raw = occurrence.raw,
    })
  end
end

local function sort_entries(entries)
  local decorated = {}
  for index, entry in ipairs(entries) do
    decorated[index] = { entry = entry, sequence = index }
  end

  table.sort(decorated, function(left, right)
    if left.entry.line == right.entry.line then
      return left.sequence < right.sequence
    end
    return left.entry.line < right.entry.line
  end)

  local sorted = {}
  for index, item in ipairs(decorated) do
    sorted[index] = item.entry
  end
  return sorted
end

function M.markdown_tree(text)
  if not (vim.treesitter and vim.treesitter.get_string_parser) then
    return nil
  end

  local ok, parser = pcall(vim.treesitter.get_string_parser, text, 'markdown')
  if not ok or not parser then
    return nil
  end

  local parsed_ok, trees = pcall(function()
    return parser:parse()
  end)
  if not parsed_ok or type(trees) ~= 'table' or not trees[1] then
    return nil
  end

  return trees[1]
end

function M.build(lines, opts)
  opts = opts or {}
  lines = lines or {}

  local entries = {}
  local rich = false
  local reason = nil
  local root = nil

  if opts.filetype == nil or opts.filetype == 'markdown' then
    local get_tree = opts.get_tree or M.markdown_tree
    local ok, tree = pcall(get_tree, table.concat(lines, '\n'))
    if ok and tree then
      local root_ok, value = pcall(function()
        return tree:root()
      end)
      if root_ok then
        root = value
      end
    end
  end

  if root then
    add_tree_entries(lines, root, entries)
    rich = true
  else
    add_heading_entries(lines, entries)
    reason = 'markdown parser unavailable; showing headings only'
  end

  add_marker_entries(lines, opts.markers, entries)

  return {
    entries = sort_entries(entries),
    rich = rich,
    reason = reason,
  }
end

return M
