local M = {}

-- Ordered default action definitions for the opt-in `suggested` preset.
M.actions = {
  {
    id = 'scene_next',
    command = 'NovelistSceneNext',
    lhs = '<leader>nn',
    mode = 'n',
    desc = 'Novelist: go to the next section heading',
  },
  {
    id = 'scene_prev',
    command = 'NovelistScenePrev',
    lhs = '<leader>np',
    mode = 'n',
    desc = 'Novelist: go to the previous section heading',
  },
  {
    id = 'word_count',
    command = 'NovelistWordCount',
    lhs = '<leader>nw',
    mode = 'n',
    desc = 'Novelist: report section and document word counts',
  },
  {
    id = 'markers',
    command = 'NovelistMarkers',
    lhs = '<leader>nm',
    mode = 'n',
    desc = 'Novelist: list markers in the quickfix list',
  },
  {
    id = 'document_map',
    command = 'NovelistDocumentMap',
    lhs = '<leader>no',
    mode = 'n',
    desc = 'Novelist: open the document map outline',
  },
}

-- Registry of mappings Novelist installed, keyed by action id. Each record stores
-- the signature needed to prove a mapping is still Novelist-owned before deleting it.
local state = {
  installed = {},
}

local function map_dict(lhs, mode)
  local dict = vim.fn.maparg(lhs, mode, false, true)
  if type(dict) == 'table' and dict.lhs and dict.lhs ~= '' then
    return dict
  end
  return nil
end

local function is_owned(record, dict)
  return dict ~= nil
    and dict.lhs == record.expanded
    and dict.rhs == record.rhs
    and dict.desc == record.desc
end

local function resolve_desired(config)
  if type(config) ~= 'table' or config.preset ~= 'suggested' then
    return {}
  end

  local overrides = config.mappings or {}
  local desired = {}
  for _, action in ipairs(M.actions) do
    local override = overrides[action.id]
    if override ~= false then
      local spec = {
        id = action.id,
        command = action.command,
        lhs = action.lhs,
        mode = action.mode,
        desc = action.desc,
      }
      if type(override) == 'table' then
        if override.lhs then
          spec.lhs = override.lhs
        end
        if override.mode then
          spec.mode = override.mode
        end
        if override.desc then
          spec.desc = override.desc
        end
      end
      spec.rhs = string.format('<cmd>%s<cr>', spec.command)
      desired[action.id] = spec
    end
  end
  return desired
end

local function remove_owned(action_id)
  local record = state.installed[action_id]
  if not record then
    return
  end

  local dict = map_dict(record.expanded, record.mode)
  if is_owned(record, dict) then
    vim.keymap.del(record.mode, record.expanded)
  end
  state.installed[action_id] = nil
end

local function install(spec)
  local existing = map_dict(spec.lhs, spec.mode)
  if existing then
    return spec.lhs
  end

  vim.keymap.set(spec.mode, spec.lhs, spec.rhs, { desc = spec.desc })
  local dict = map_dict(spec.lhs, spec.mode)
  state.installed[spec.id] = {
    configured = spec.lhs,
    mode = spec.mode,
    expanded = dict and dict.lhs or spec.lhs,
    rhs = dict and dict.rhs or spec.rhs,
    desc = dict and dict.desc or spec.desc,
  }
  return nil
end

local function drop_replaced(action_id)
  local record = state.installed[action_id]
  if not record then
    return
  end

  local dict = map_dict(record.expanded, record.mode)
  if not is_owned(record, dict) then
    -- A user or another plugin now owns this key; stop claiming it.
    state.installed[action_id] = nil
  end
end

function M.setup(config)
  local desired = resolve_desired(config)
  local conflicts = {}

  -- Forget owned mappings that are disabled, moved, or whose description changed.
  for action_id, record in pairs(state.installed) do
    local spec = desired[action_id]
    if not spec or spec.lhs ~= record.configured or spec.mode ~= record.mode or spec.desc ~= record.desc then
      remove_owned(action_id)
    end
  end

  -- Stop claiming keys a user has remapped since the last setup.
  for action_id in pairs(state.installed) do
    drop_replaced(action_id)
  end

  for _, action in ipairs(M.actions) do
    local spec = desired[action.id]
    if spec and not state.installed[action.id] then
      local conflict = install(spec)
      if conflict then
        table.insert(conflicts, conflict)
      end
    end
  end

  for _, lhs in ipairs(conflicts) do
    vim.notify(string.format('novelist: %s already mapped; skipping', lhs), vim.log.levels.WARN)
  end
end

return M
