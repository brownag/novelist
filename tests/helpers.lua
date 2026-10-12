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
