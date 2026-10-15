local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local function require_fresh_novelist(opts)
  package.loaded['novelist'] = nil
  local novelist = require('novelist')
  novelist.setup(opts or {})
  return novelist
end

local function map(lhs, mode)
  local dict = vim.fn.maparg(lhs, mode or 'n', false, true)
  if type(dict) == 'table' and dict.lhs and dict.lhs ~= '' then
    return dict
  end
  return nil
end

local function keymap_count()
  local count = 0
  for _, mode in ipairs({ 'n', 'i', 'v', 'x', 'o' }) do
    count = count + #vim.api.nvim_get_keymap(mode)
  end
  return count
end

local suggested_keys = {
  { '<leader>nn', 'NovelistSceneNext' },
  { '<leader>np', 'NovelistScenePrev' },
  { '<leader>nw', 'NovelistWordCount' },
  { '<leader>nm', 'NovelistMarkers' },
  { '<leader>no', 'NovelistDocumentMap' },
}

local override_keys = { '<leader>na', '<leader>nz' }

local function clear_all()
  require('novelist.keymaps').setup({ preset = false })
  for _, entry in ipairs(suggested_keys) do
    pcall(vim.keymap.del, 'n', entry[1])
    pcall(vim.keymap.del, 'i', entry[1])
  end
  for _, lhs in ipairs(override_keys) do
    pcall(vim.keymap.del, 'n', lhs)
    pcall(vim.keymap.del, 'i', lhs)
  end
end

h.test('suggested mappings are opt-in and install five global normal-mode maps', function()
  clear_all()

  local before = keymap_count()
  require_fresh_novelist()
  h.assert_equal(before, keymap_count())
  h.assert_true(map('<leader>nn', 'n') == nil)

  require_fresh_novelist({ keymaps = { preset = 'suggested' } })
  local commands = vim.api.nvim_get_commands({ builtin = false })
  for _, entry in ipairs(suggested_keys) do
    local lhs, command = entry[1], entry[2]
    local dict = map(lhs, 'n')
    h.assert_true(dict ~= nil, lhs .. ' should be mapped')
    h.assert_equal(0, dict.buffer)
    h.assert_equal('<Cmd>' .. command .. '<CR>', vim.fn.maparg(lhs, 'n'))
    h.assert_true(dict.desc ~= nil and dict.desc ~= '', lhs .. ' should carry a description')
    h.assert_true(commands[command] ~= nil, command .. ' should be registered')
  end

  clear_all()
  h.assert_equal(before, keymap_count())
end)

h.test('overrides change key, mode, and description, and false disables an action', function()
  clear_all()

  require_fresh_novelist({
    keymaps = {
      preset = 'suggested',
      mappings = {
        scene_next = { lhs = '<leader>na' },
        scene_prev = { desc = 'novelist custom previous' },
        word_count = { mode = 'i' },
        markers = false,
      },
    },
  })

  h.assert_true(map('<leader>nn', 'n') == nil, 'overridden lhs must be removed')
  local moved = map('<leader>na', 'n')
  h.assert_true(moved ~= nil, 'override lhs should be mapped')
  h.assert_equal('<Cmd>NovelistSceneNext<CR>', vim.fn.maparg('<leader>na', 'n'))

  local relabeled = map('<leader>np', 'n')
  h.assert_true(relabeled ~= nil)
  h.assert_equal('novelist custom previous', relabeled.desc)

  local insert = map('<leader>nw', 'i')
  h.assert_true(insert ~= nil, 'override mode should map in insert mode')
  h.assert_equal('<Cmd>NovelistWordCount<CR>', vim.fn.maparg('<leader>nw', 'i'))
  h.assert_true(map('<leader>nw', 'n') == nil, 'default mode should no longer be mapped')

  h.assert_true(map('<leader>nm', 'n') == nil, 'disabled action must not be mapped')
  h.assert_true(map('<leader>no', 'n') ~= nil, 'other actions must remain mapped')

  clear_all()
end)

h.test('pre-existing user mappings win, are reported, and unrelated maps are untouched', function()
  clear_all()

  vim.keymap.set('n', '<leader>nn', '<cmd>echo "user"<cr>', { desc = 'user scene next' })
  vim.keymap.set('n', '<leader>nz', '<cmd>echo "unrelated"<cr>', { desc = 'unrelated map' })
  local user_before = map('<leader>nn', 'n')

  local messages = {}
  local original_notify = vim.notify
  vim.notify = function(message, level)
    table.insert(messages, { message = message, level = level })
  end
  local ok, err = pcall(function()
    require_fresh_novelist({ keymaps = { preset = 'suggested' } })
  end)
  vim.notify = original_notify
  if not ok then
    error(err, 0)
  end

  local user_after = map('<leader>nn', 'n')
  h.assert_equal(user_before.rhs, user_after.rhs)
  h.assert_equal(user_before.desc, user_after.desc)

  h.assert_true(#messages >= 1, 'conflict must be reported')
  h.assert_true(messages[1].message:find('<leader>nn', 1, true) ~= nil)
  h.assert_equal(vim.log.levels.WARN, messages[1].level)

  h.assert_true(map('<leader>np', 'n') ~= nil)
  h.assert_true(map('<leader>nw', 'n') ~= nil)
  h.assert_true(map('<leader>nm', 'n') ~= nil)
  h.assert_true(map('<leader>no', 'n') ~= nil)

  h.assert_equal('unrelated map', map('<leader>nz', 'n').desc)

  clear_all()
end)

h.test('repeated setup updates owned maps, keeps unrelated maps, and disable respects ownership', function()
  clear_all()

  vim.keymap.set('n', '<leader>nz', '<cmd>echo "keep"<cr>', { desc = 'keep me' })
  local baseline = keymap_count()

  require_fresh_novelist({ keymaps = { preset = 'suggested' } })
  h.assert_equal(baseline + 5, keymap_count())

  require('novelist').setup({ keymaps = { preset = 'suggested' } })
  h.assert_equal(baseline + 5, keymap_count(), 'repeated setup must not duplicate maps')

  require('novelist').setup({
    keymaps = { preset = 'suggested', mappings = { scene_next = { lhs = '<leader>na' } } },
  })
  h.assert_true(map('<leader>nn', 'n') == nil, 'old lhs must be removed on update')
  h.assert_true(map('<leader>na', 'n') ~= nil, 'new lhs must be installed on update')
  h.assert_equal(baseline + 5, keymap_count())

  vim.keymap.set('n', '<leader>np', '<cmd>echo "mine"<cr>', { desc = 'mine now' })
  require('novelist').setup({ keymaps = { preset = false } })

  h.assert_true(map('<leader>na', 'n') == nil)
  h.assert_true(map('<leader>nw', 'n') == nil)
  h.assert_true(map('<leader>nm', 'n') == nil)
  h.assert_true(map('<leader>no', 'n') == nil)

  local mine = map('<leader>np', 'n')
  h.assert_true(mine ~= nil, 'user overwrite must survive disable')
  h.assert_equal('mine now', mine.desc)
  h.assert_equal('keep me', map('<leader>nz', 'n').desc)

  clear_all()
  h.assert_true(map('<leader>nz', 'n') == nil)
end)
