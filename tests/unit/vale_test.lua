local h = require('tests.helpers')

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local vale = require('novelist.vale')

local function assert_list(expected, actual, message)
  h.assert_equal(#expected, #actual, message)
  for index, value in ipairs(expected) do
    h.assert_equal(value, actual[index], message)
  end
end

local function with_process(stub, fn)
  local original = vale.process
  vale.process = stub
  local ok, err = xpcall(fn, debug.traceback)
  vale.process = original
  if not ok then
    error(err, 0)
  end
end

local function process_result(result)
  local invocation = { argv = nil, stdin = nil }
  local function stub(argv, stdin, on_exit)
    invocation.argv = argv
    invocation.stdin = stdin
    on_exit({ code = result.code, stdout = result.stdout, stderr = result.stderr })
    return {}
  end
  return invocation, stub
end

h.test('adapter passes extension and path context and streams buffer lines to stdin', function()
  local invocation, stub = process_result({ code = 0, stdout = '{}', stderr = '' })
  local result
  with_process(stub, function()
    vale.check({
      executable = 'vale',
      lines = { 'First line.', 'Second line.' },
      path = '/tmp/draft.md',
      ext = '.md',
    }, function(value)
      result = value
    end)
  end)

  h.assert_true(result.ok)
  assert_list({ 'vale', '--output=JSON', '--ext=.md', '--path=/tmp/draft.md', '-' }, invocation.argv)
  h.assert_equal('First line.\nSecond line.', invocation.stdin)

  local unnamed, unnamed_stub = process_result({ code = 0, stdout = '{}', stderr = '' })
  with_process(unnamed_stub, function()
    vale.check({
      executable = '/opt/vale',
      lines = { 'Only line.' },
      ext = '.txt',
    }, function() end)
  end)

  assert_list({ '/opt/vale', '--output=JSON', '--ext=.txt', '-' }, unnamed.argv)
end)

h.test('parses Vale JSON findings into stable diagnostic records', function()
  local stdout = vim.json.encode({
    ['/tmp/draft.md'] = {
      {
        Action = { Name = 'edit', Params = { 'truncate', ' ' } },
        Span = { 5, 9 },
        Check = 'Vale.Repetition',
        Description = '',
        Link = '',
        Message = "'is' is repeated!",
        Severity = 'warning',
        Match = 'is is',
        Line = 3,
      },
    },
  })

  local _, stub = process_result({ code = 1, stdout = stdout, stderr = '' })
  local result
  with_process(stub, function()
    vale.check({
      executable = 'vale',
      lines = { 'x' },
      path = '/tmp/draft.md',
      ext = '.md',
    }, function(value)
      result = value
    end)
  end)

  h.assert_true(result.ok)
  h.assert_equal(1, result.code)
  h.assert_equal(1, #result.diagnostics)
  local diagnostic = result.diagnostics[1]
  h.assert_equal(3, diagnostic.line)
  h.assert_equal(5, diagnostic.col)
  h.assert_equal(9, diagnostic.end_col)
  h.assert_equal('warning', diagnostic.severity)
  h.assert_equal("'is' is repeated!", diagnostic.message)
  h.assert_equal('Vale.Repetition', diagnostic.check)
  h.assert_equal('is is', diagnostic.match)
  h.assert_equal('/tmp/draft.md', diagnostic.path)
end)

h.test('reports success with no diagnostics for empty Vale output', function()
  local _, stub = process_result({ code = 0, stdout = '{}', stderr = '' })
  local result
  with_process(stub, function()
    vale.check({ executable = 'vale', lines = { 'clean' } }, function(value)
      result = value
    end)
  end)

  h.assert_true(result.ok)
  h.assert_equal(0, result.code)
  h.assert_equal(0, #result.diagnostics)
end)

h.test('distinguishes process errors, malformed output, and launch failures', function()
  local _, stub = process_result({ code = 2, stdout = '', stderr = 'E201: no styles' })
  local failed
  with_process(stub, function()
    vale.check({ executable = 'vale', lines = { 'x' } }, function(value)
      failed = value
    end)
  end)

  h.assert_false(failed.ok)
  h.assert_true(failed.error:match('code 2') ~= nil)
  h.assert_equal(2, failed.code)
  h.assert_equal('', failed.stdout)
  h.assert_equal('E201: no styles', failed.stderr)

  local _, bad_stub = process_result({ code = 0, stdout = 'not json', stderr = '' })
  local malformed
  with_process(bad_stub, function()
    vale.check({ executable = 'vale', lines = { 'x' } }, function(value)
      malformed = value
    end)
  end)

  h.assert_false(malformed.ok)
  h.assert_true(malformed.error:match('parse') ~= nil)
  h.assert_equal(0, malformed.code)
  h.assert_true(malformed.diagnostics == nil)

  local launch
  with_process(function()
    error('spawn failed')
  end, function()
    vale.check({ executable = 'missing-vale', lines = { 'x' } }, function(value)
      launch = value
    end)
  end)

  h.assert_false(launch.ok)
  h.assert_true(launch.error:match('missing%-vale') ~= nil)
  h.assert_true(launch.error:match('spawn failed') ~= nil)
  h.assert_true(launch.diagnostics == nil)
end)
