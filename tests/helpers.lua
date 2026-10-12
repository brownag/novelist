local M = {
  cases = {},
}

function M.test(name, fn)
  assert(type(name) == 'string', 'test name must be a string')
  assert(type(fn) == 'function', 'test body must be a function')
  table.insert(M.cases, { name = name, fn = fn })
end

function M.assert_equal(expected, actual, message)
  if expected ~= actual then
    error(message or string.format('expected %q, got %q', tostring(expected), tostring(actual)), 2)
  end
end

function M.assert_true(value, message)
  if not value then
    error(message or string.format('expected a truthy value, got %s', tostring(value)), 2)
  end
end

function M.assert_false(value, message)
  if value then
    error(message or string.format('expected a falsy value, got %s', tostring(value)), 2)
  end
end

function M.win_for(bufnr)
  local winid = vim.fn.bufwinid(bufnr)
  M.assert_true(winid ~= -1, 'test buffer must be visible')
  return winid
end

function M.set_local_option(bufnr, name, value)
  local ok = pcall(vim.api.nvim_set_option_value, name, value, { buf = bufnr })
  if not ok then
    vim.api.nvim_set_option_value(name, value, { win = M.win_for(bufnr) })
  end
end

function M.get_local_option(bufnr, name)
  local ok, value = pcall(vim.api.nvim_get_option_value, name, { buf = bufnr })
  if ok then
    return value
  end
  return vim.api.nvim_get_option_value(name, { win = M.win_for(bufnr) })
end

function M.set_non_prose_options(bufnr)
  M.set_local_option(bufnr, 'spell', false)
  M.set_local_option(bufnr, 'spelllang', 'en_gb')
  M.set_local_option(bufnr, 'wrap', false)
  M.set_local_option(bufnr, 'linebreak', false)
  M.set_local_option(bufnr, 'breakindent', false)
  M.set_local_option(bufnr, 'textwidth', 72)
end

function M.assert_non_prose_options(bufnr)
  M.assert_false(M.get_local_option(bufnr, 'spell'))
  M.assert_equal('en_gb', M.get_local_option(bufnr, 'spelllang'))
  M.assert_false(M.get_local_option(bufnr, 'wrap'))
  M.assert_false(M.get_local_option(bufnr, 'linebreak'))
  M.assert_false(M.get_local_option(bufnr, 'breakindent'))
  M.assert_equal(72, M.get_local_option(bufnr, 'textwidth'))
end

function M.make_buffer(lines, name, filetype)
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  if name then
    vim.api.nvim_buf_set_name(bufnr, name)
  end
  vim.api.nvim_set_current_buf(bufnr)
  if filetype then
    vim.bo[bufnr].filetype = filetype
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { 'Draft text.' })
  return bufnr, previous
end

function M.cleanup_buffer(bufnr, previous, close_quickfix)
  if close_quickfix then
    pcall(vim.cmd, 'cclose')
  end
  if vim.api.nvim_buf_is_valid(previous) then
    pcall(vim.api.nvim_set_current_buf, previous)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

function M.with_buffer(lines, fn, opts)
  opts = opts or {}
  local bufnr, previous = M.make_buffer(lines, opts.name, opts.filetype)
  local ok, err = xpcall(function()
    fn(bufnr)
  end, debug.traceback)
  M.cleanup_buffer(bufnr, previous, opts.close_quickfix)
  if not ok then
    error(err, 0)
  end
end

function M.run(root)
  local files = vim.fn.globpath(root .. '/tests/unit', '*_test.lua', false, true)
  table.sort(files)

  for _, file in ipairs(files) do
    local ok, err = pcall(dofile, file)
    if not ok then
      table.insert(M.cases, {
        name = 'load ' .. vim.fn.fnamemodify(file, ':t'),
        error = err,
      })
    end
  end

  local passed, failed = 0, 0
  for _, case in ipairs(M.cases) do
    local ok, err
    if case.error then
      ok, err = false, case.error
    else
      ok, err = xpcall(case.fn, debug.traceback)
    end

    if ok then
      passed = passed + 1
    else
      failed = failed + 1
      io.stderr:write(string.format('FAIL %s\n%s\n', case.name, err))
    end
  end

  print(string.format('Tests: %d passed, %d failed', passed, failed))
  if failed > 0 then
    vim.cmd('cquit 1')
  else
    vim.cmd('qa!')
  end
end

return M
