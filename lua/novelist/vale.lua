local M = {}

function M.build_argv(opts)
  local argv = { opts.executable, '--output=JSON' }
  if opts.ext then
    table.insert(argv, '--ext=' .. opts.ext)
  end
  if opts.path then
    table.insert(argv, '--path=' .. opts.path)
  end
  table.insert(argv, '-')
  return argv
end

function M.process(argv, stdin, on_exit)
  return vim.system(argv, { stdin = stdin, text = true }, on_exit)
end

function M.parse_output(stdout)
  local ok, decoded = pcall(vim.json.decode, stdout)
  if not ok or type(decoded) ~= 'table' then
    return nil, 'could not parse Vale JSON output'
  end

  local diagnostics = {}
  for path, alerts in pairs(decoded) do
    if type(alerts) == 'table' then
      for _, alert in ipairs(alerts) do
        local span = alert.Span or {}
        table.insert(diagnostics, {
          path = path,
          line = alert.Line,
          col = span[1],
          end_col = span[2],
          severity = alert.Severity,
          message = alert.Message,
          check = alert.Check,
          match = alert.Match,
        })
      end
    end
  end

  return diagnostics
end

function M.check(opts, on_done)
  opts = opts or {}
  vim.validate('executable', opts.executable, 'string')
  vim.validate('lines', opts.lines, 'table')
  vim.validate('on_done', on_done, 'function')

  local function on_exit(result)
    local code = result.code
    if code ~= 0 and code ~= 1 then
      on_done({
        ok = false,
        error = string.format('Vale exited with code %s', tostring(code)),
        code = code,
        stdout = result.stdout,
        stderr = result.stderr,
      })
      return
    end

    local diagnostics, parse_error = M.parse_output(result.stdout or '')
    if not diagnostics then
      on_done({
        ok = false,
        error = parse_error,
        code = code,
        stdout = result.stdout,
        stderr = result.stderr,
      })
      return
    end

    on_done({
      ok = true,
      diagnostics = diagnostics,
      code = code,
      stdout = result.stdout,
      stderr = result.stderr,
    })
  end

  local ok, err = pcall(M.process, M.build_argv(opts), table.concat(opts.lines, '\n'), on_exit)
  if not ok then
    on_done({
      ok = false,
      error = string.format('could not run %s: %s', opts.executable, tostring(err)),
    })
  end
end

return M
