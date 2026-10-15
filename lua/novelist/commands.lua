local cockpit = require('novelist.cockpit')
local document_map = require('novelist.document_map')

local M = {}

local state = {
  outline_bufnr = nil,
  targets = {},
}

local get_config = function()
  return { markers = {} }
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

local function current_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    notify('novelist: current buffer is invalid', vim.log.levels.WARN)
    return nil
  end
  return bufnr
end

local function current_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function marker_config()
  local config = get_config() or {}
  return config.markers or {}
end

local function outline_buffer_name()
  return 'novelist://document-map'
end

local function jump_to_target()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local target = state.targets[row]
  if not target then
    return
  end

  local ok, err = pcall(function()
    if not vim.api.nvim_buf_is_valid(target.bufnr) then
      notify('novelist: source buffer is no longer available', vim.log.levels.WARN)
      return
    end

    local winid = vim.fn.bufwinid(target.bufnr)
    if winid == -1 then
      vim.api.nvim_win_set_buf(0, target.bufnr)
      winid = vim.api.nvim_get_current_win()
    end

    vim.api.nvim_set_current_win(winid)
    local line_count = vim.api.nvim_buf_line_count(target.bufnr)
    vim.api.nvim_win_set_cursor(winid, { math.min(target.line, math.max(line_count, 1)), 0 })
  end)

  if not ok then
    notify('novelist: could not jump to source line: ' .. tostring(err), vim.log.levels.WARN)
  end
end

local function find_outline_buffer()
  local bufnr = state.outline_bufnr
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    bufnr = vim.fn.bufnr(outline_buffer_name())
    if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end
  end
  return bufnr
end

local function ensure_outline_buffer()
  local bufnr = find_outline_buffer()
  if bufnr then
    state.outline_bufnr = bufnr
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, outline_buffer_name())
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  state.outline_bufnr = bufnr

  vim.keymap.set('n', '<CR>', jump_to_target, {
    buf = bufnr,
    desc = 'Jump to the source line for this outline entry',
  })

  return bufnr
end

local function render_outline(outline, bufnr)
  local lines = {}
  local targets = {}

  if not outline.rich then
    table.insert(lines, string.format('novelist: %s', outline.reason))
  end

  if #outline.entries == 0 then
    table.insert(lines, 'novelist: document has no outline entries')
  end

  for _, entry in ipairs(outline.entries) do
    local indent = string.rep('  ', math.max((entry.depth or 1) - 1, 0))
    table.insert(lines, string.format('%s%s  [%d]', indent, entry.label, entry.line))
    targets[#lines] = { bufnr = bufnr, line = entry.line }
  end

  return lines, targets
end

local function document_map_command()
  local bufnr = current_buffer()
  if not bufnr then
    return
  end

  if bufnr == find_outline_buffer() then
    notify('novelist: run :NovelistDocumentMap from a source buffer', vim.log.levels.WARN)
    return
  end

  local outline = document_map.build(current_lines(bufnr), {
    markers = marker_config(),
    filetype = vim.bo[bufnr].filetype,
  })

  local outline_bufnr = ensure_outline_buffer()
  local lines, targets = render_outline(outline, bufnr)

  vim.bo[outline_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(outline_bufnr, 0, -1, false, lines)
  vim.bo[outline_bufnr].modifiable = false
  state.targets = targets

  local winid = vim.fn.bufwinid(outline_bufnr)
  if winid == -1 then
    vim.cmd('vsplit')
    winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winid, outline_bufnr)
  end

  vim.api.nvim_set_current_win(winid)
  vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

local function move_to_heading(direction)
  local bufnr = current_buffer()
  if not bufnr then
    return
  end

  local lines = current_lines(bufnr)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local heading
  if direction == 'next' then
    heading = cockpit.next_heading(lines, line)
  else
    heading = cockpit.previous_heading(lines, line)
  end

  if not heading then
    notify('novelist: no ' .. direction .. ' section heading', vim.log.levels.WARN)
    return
  end

  vim.api.nvim_win_set_cursor(0, { heading.line, 0 })
end

local function word_count()
  local bufnr = current_buffer()
  if not bufnr then
    return
  end

  local lines = current_lines(bufnr)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local markers = marker_config()
  local section_count = cockpit.section_word_count(lines, line, markers)
  local document_count = cockpit.document_word_count(lines, markers)

  notify(string.format('novelist: section words: %d, document words: %d', section_count, document_count))
end

local function quickfix_filename(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= '' then
    return name
  end
  return '[No Name]'
end

local function list_markers(args)
  local bufnr = current_buffer()
  if not bufnr then
    return
  end

  local filter_name = nil
  if args and args.args and args.args ~= '' then
    filter_name = args.args
  end

  local filename = quickfix_filename(bufnr)
  local occurrences = cockpit.find_markers(current_lines(bufnr), marker_config(), filter_name)
  local items = {}
  for _, occurrence in ipairs(occurrences) do
    table.insert(items, {
      filename = filename,
      lnum = occurrence.line,
      col = 1,
      text = occurrence.raw,
    })
  end

  vim.fn.setqflist({}, ' ', {
    title = 'Novelist markers',
    items = items,
  })

  if #items == 0 then
    notify('novelist: no markers found', vim.log.levels.WARN)
    return
  end

  vim.cmd('copen')
end

local function complete_markers(arg_lead)
  local markers = cockpit.resolve_markers(marker_config())
  local names = {}
  for name in pairs(markers) do
    if arg_lead == '' or name:sub(1, #arg_lead) == arg_lead then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

function M.register(config_getter)
  get_config = config_getter or get_config

  vim.api.nvim_create_user_command('NovelistSceneNext', function()
    move_to_heading('next')
  end, { desc = 'Move to the next novelist section heading', force = true })

  vim.api.nvim_create_user_command('NovelistScenePrev', function()
    move_to_heading('previous')
  end, { desc = 'Move to the previous novelist section heading', force = true })

  vim.api.nvim_create_user_command('NovelistWordCount', word_count, {
    desc = 'Report current novelist section and document word counts',
    force = true,
  })

  vim.api.nvim_create_user_command('NovelistMarkers', list_markers, {
    nargs = '?',
    complete = complete_markers,
    desc = 'List novelist markers in the quickfix list',
    force = true,
  })

  vim.api.nvim_create_user_command('NovelistDocumentMap', document_map_command, {
    desc = 'Open the novelist document map outline',
    force = true,
  })
end

return M
