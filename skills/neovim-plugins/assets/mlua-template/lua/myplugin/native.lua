-- Loads the Rust module by absolute path with package.loadlib rather than
-- require(), so a stale copy elsewhere on package.cpath can't shadow it.
-- Returns the module table, or nil plus an error message; callers should fall
-- back to pure Lua (or disable the feature) when it's nil.
local M = {}

local LIB = 'myplugin_native'
local cached, cached_err

local function plugin_root()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(source, ':p:h:h:h') -- lua/myplugin/native.lua -> root
end

local function candidates(root)
  local is_win = jit.os == 'Windows'
  local cargo_file = (is_win and '' or 'lib') .. LIB .. '.' .. (is_win and 'dll' or jit.os == 'OSX' and 'dylib' or 'so')
  local target_dir = vim.env.CARGO_TARGET_DIR or (root .. '/target')
  return {
    -- Installed/downloaded binary (what release builds or a build hook produce).
    root .. '/lib/' .. LIB .. '.' .. (is_win and 'dll' or 'so'),
    -- Local cargo builds, so `cargo build --release` + restart is the dev loop.
    target_dir .. '/release/' .. cargo_file,
    target_dir .. '/debug/' .. cargo_file,
  }
end

function M.load()
  if cached or cached_err then
    return cached, cached_err
  end
  local tried = {}
  for _, path in ipairs(candidates(plugin_root())) do
    if vim.uv.fs_stat(path) then
      local init, err = package.loadlib(path, 'luaopen_' .. LIB)
      if init then
        local ok, mod = pcall(init)
        if ok then
          cached = mod
          return cached
        end
        err = mod
      end
      table.insert(tried, path .. ': ' .. tostring(err))
    end
  end
  cached_err = #tried > 0 and table.concat(tried, '\n') or ('no ' .. LIB .. ' binary found; run `cargo build --release`')
  return nil, cached_err
end

return M
