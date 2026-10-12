local cockpit = require('novelist.cockpit')

local M = {}

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
end

return M
