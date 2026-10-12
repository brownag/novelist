local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

require('tests.helpers').run(root)
