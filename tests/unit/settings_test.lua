local h = require('tests.helpers')
local settings = require('novelist.settings')

local set_local = h.set_local_option
local get_local = h.get_local_option
local set_non_prose_values = h.set_non_prose_options
local assert_non_prose_values = h.assert_non_prose_options

h.test('settings applies prose defaults locally for supported buffers', function()
  h.with_buffer({ '# Scene', 'Words stay intact.' }, function(bufnr)
    vim.bo[bufnr].filetype = 'markdown'
    set_non_prose_values(bufnr)

    h.assert_true(settings.apply(bufnr, {}))

    h.assert_true(get_local(bufnr, 'spell'))
    h.assert_equal('en_us', get_local(bufnr, 'spelllang'))
    h.assert_true(get_local(bufnr, 'wrap'))
    h.assert_true(get_local(bufnr, 'linebreak'))
    h.assert_true(get_local(bufnr, 'breakindent'))
    h.assert_equal(0, get_local(bufnr, 'textwidth'))
    h.assert_equal('# Scene\nWords stay intact.', table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n'))
  end)
end)

h.test('settings applies configured spell language without mutating input', function()
  h.with_buffer(nil, function(bufnr)
    vim.bo[bufnr].filetype = 'text'
    local config = { spelllang = { 'en_gb', 'fr' } }

    h.assert_true(settings.apply(bufnr, config))

    h.assert_equal('en_gb,fr', get_local(bufnr, 'spelllang'))
    h.assert_equal('en_gb', config.spelllang[1])
    h.assert_equal('fr', config.spelllang[2])
  end)
end)

h.test('settings skips when disabled globally', function()
  h.with_buffer(nil, function(bufnr)
    vim.bo[bufnr].filetype = 'markdown'
    set_non_prose_values(bufnr)

    h.assert_false(settings.apply(bufnr, { enabled = false }))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings skips unsupported filetypes', function()
  h.with_buffer(nil, function(bufnr)
    vim.bo[bufnr].filetype = 'lua'
    set_non_prose_values(bufnr)

    h.assert_false(settings.apply(bufnr, {}))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings skips buffer opt-out', function()
  h.with_buffer(nil, function(bufnr)
    vim.bo[bufnr].filetype = 'markdown'
    set_non_prose_values(bufnr)
    vim.b[bufnr].novelist_disable = true

    h.assert_false(settings.apply(bufnr, {}))

    assert_non_prose_values(bufnr)
  end)
end)

h.test('settings leaves unrelated local options and global options unchanged', function()
  h.with_buffer({ 'One', 'Two' }, function(bufnr)
    vim.bo[bufnr].filetype = 'markdown'
    local global_textwidth = vim.go.textwidth
    local global_shiftwidth = vim.go.shiftwidth
    vim.bo[bufnr].shiftwidth = 6

    h.assert_true(settings.apply(bufnr, {}))

    h.assert_equal(6, vim.bo[bufnr].shiftwidth)
    h.assert_equal(global_textwidth, vim.go.textwidth)
    h.assert_equal(global_shiftwidth, vim.go.shiftwidth)
    h.assert_equal('One\nTwo', table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n'))
  end)
end)
