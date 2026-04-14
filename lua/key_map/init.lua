local M = {}

local MODES = {
  { code = 'n', name = 'Normal' },
  { code = 'i', name = 'Insert' },
  { code = 'v', name = 'Visual+Select' },
  { code = 'x', name = 'Visual' },
  { code = 's', name = 'Select' },
  { code = 'o', name = 'Operator-pending' },
  { code = 'c', name = 'Command-line' },
  { code = 't', name = 'Terminal' },
}

local VALID_MODES = {}
for _, m in ipairs(MODES) do VALID_MODES[m.code] = true end

local function base_key(lhs)
  if lhs == nil or lhs == '' then return '' end
  local first = lhs:sub(1, 1)
  if first == '<' then
    local close = lhs:find('>', 2, true)
    if not close then return first end
    local inner = lhs:sub(2, close - 1)
    local last_dash = 0
    for i = 1, #inner do
      if inner:sub(i, i) == '-' then last_dash = i end
    end
    if last_dash > 0 then
      local keyname = inner:sub(last_dash + 1)
      if #keyname == 1 then return keyname:lower() end
      return '<' .. keyname:lower() .. '>'
    end
    return '<' .. inner:lower() .. '>'
  end
  if first:match('%a') then return first:lower() end
  return first
end

local function sort_key(lhs)
  local bracketed = lhs:sub(1, 1) == '<' and 1 or 0
  return string.format('%d %04d %s', bracketed, #lhs, lhs)
end

local _source_cache

local function shorten_path(path)
  local home = vim.env.HOME
  if home and path:sub(1, #home) == home then
    path = '~' .. path:sub(#home + 1)
  end
  local parts = {}
  for p in path:gmatch('[^/]+') do table.insert(parts, p) end
  if #parts <= 2 then return path end
  return parts[#parts - 1] .. '/' .. parts[#parts]
end

local function get_source(m)
  if m._builtin then return 'vim-builtin' end
  if not _source_cache then
    _source_cache = {}
    local ok, infos = pcall(vim.fn.getscriptinfo)
    if ok and infos then
      for _, s in ipairs(infos) do _source_cache[s.sid] = s.name end
    end
  end
  local sid = m.sid
  local path
  if sid and sid > 0 then path = _source_cache[sid] end
  if not path and type(m.callback) == 'function' then
    local info = debug.getinfo(m.callback, 'S')
    if info and info.source and info.source:sub(1, 1) == '@' then
      path = info.source:sub(2)
    end
  end
  if not path or path == '' then return '?' end
  return shorten_path(path)
end

local function describe(m, show_mode)
  local prefix = ''
  if show_mode then prefix = '[' .. (m._mode or '?') .. '] ' end
  local tags = {}
  if m._buf_local then table.insert(tags, 'buffer-local') end
  local suffix = #tags > 0 and ('  (' .. table.concat(tags, ', ') .. ')') or ''
  if m.desc and m.desc ~= '' then
    return prefix .. m.desc .. suffix
  end
  if (not m.rhs or m.rhs == '') and m.callback then
    return prefix .. '\xe2\x86\x92 <Lua function>' .. suffix
  end
  local rhs = m.rhs or ''
  return prefix .. '\xe2\x86\x92 ' .. rhs .. suffix
end

local function reset_caches()
  _source_cache = nil
end

local defaults = require('key_map.defaults')

local function collect_mappings(mode, include_buffer, include_defaults)
  local by_lhs = {}
  if include_defaults then
    for _, d in ipairs(defaults.get(mode)) do
      by_lhs[d.lhs] = { lhs = d.lhs, desc = d.desc, _builtin = true }
    end
  end
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    by_lhs[m.lhs] = m
  end
  if include_buffer then
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
      m._buf_local = true
      by_lhs[m.lhs] = m
    end
  end
  local out = {}
  for _, m in pairs(by_lhs) do table.insert(out, m) end
  return out
end

local function group_mappings(mappings)
  local groups = {}
  for _, m in ipairs(mappings) do
    local k = base_key(m.lhs)
    groups[k] = groups[k] or {}
    table.insert(groups[k], m)
  end
  for _, g in pairs(groups) do
    table.sort(g, function(a, b)
      local sa, sb = sort_key(a.lhs), sort_key(b.lhs)
      if sa ~= sb then return sa < sb end
      return (a._mode or '') < (b._mode or '')
    end)
  end
  return groups
end

local function format_group(group, key, show_mode, desc_col_width)
  local lines = { '- ' .. key .. ':' }
  if not group then return lines end
  local max_lhs = 0
  for _, m in ipairs(group) do
    if #m.lhs > max_lhs then max_lhs = #m.lhs end
  end
  local lhs_col = math.max(max_lhs + 2, 11)
  for _, m in ipairs(group) do
    local lhs_pad = lhs_col - #m.lhs
    if lhs_pad < 1 then lhs_pad = 1 end
    local desc = describe(m, show_mode)
    local src = get_source(m)
    local desc_pad = desc_col_width - #desc
    if desc_pad < 2 then desc_pad = 2 end
    table.insert(lines,
      '    ' .. m.lhs .. string.rep(' ', lhs_pad) .. desc .. string.rep(' ', desc_pad) .. src)
  end
  return lines
end

local function build_output(mappings, header, show_mode)
  local groups = group_mappings(mappings)

  local desc_col_width = 0
  for _, group in pairs(groups) do
    for _, m in ipairs(group) do
      local d = #describe(m, show_mode)
      if d > desc_col_width then desc_col_width = d end
    end
  end
  desc_col_width = math.min(desc_col_width + 2, 70)

  local lines = {}
  if header then
    table.insert(lines, header)
    table.insert(lines, '')
  end

  local shown = {}
  local function emit(key, force)
    shown[key] = true
    if not force and not groups[key] then return end
    for _, ln in ipairs(format_group(groups[key], key, show_mode, desc_col_width)) do
      table.insert(lines, ln)
    end
    table.insert(lines, '')
  end

  for c = string.byte('a'), string.byte('z') do
    emit(string.char(c), true)
  end
  for c = string.byte('0'), string.byte('9') do
    emit(string.char(c), false)
  end

  local other = {}
  for k, _ in pairs(groups) do
    if not shown[k] then table.insert(other, k) end
  end
  table.sort(other)
  for _, k in ipairs(other) do
    emit(k, false)
  end

  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  return lines
end

local function open_buffer(lines, title)
  vim.cmd('vnew')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'keymap'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  pcall(vim.api.nvim_buf_set_name, buf, title)
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, silent = true })
end

function M.show_mode(mode, opts)
  reset_caches()
  mode = mode or 'n'
  opts = opts or {}
  if not VALID_MODES[mode] then
    vim.notify(('KeyMap: unknown mode %q'):format(mode), vim.log.levels.ERROR)
    return
  end
  local include_defaults = opts.defaults ~= false
  local mappings = collect_mappings(mode, true, include_defaults)
  local note = include_defaults
    and '(user mappings override defaults; empty slots are free)'
    or '(user mappings only; empty slots are free)'
  local header = ('Active key bindings for mode %q %s:'):format(mode, note)
  open_buffer(build_output(mappings, header, false), 'keymap://' .. mode)
end

function M.show_all(opts)
  reset_caches()
  opts = opts or {}
  local include_defaults = opts.defaults ~= false
  local by_key = {}
  for _, mode in ipairs(MODES) do
    for _, m in ipairs(collect_mappings(mode.code, true, include_defaults)) do
      m._mode = mode.code
      table.insert(by_key, m)
    end
  end
  local note = include_defaults
    and '(user mappings override defaults; empty slots are free)'
    or '(user mappings only; empty slots are free)'
  local header = 'Active key bindings across all modes ' .. note .. ':'
  open_buffer(build_output(by_key, header, true), 'keymap://all')
end

M._internal = {
  base_key = base_key,
  sort_key = sort_key,
  build_output = build_output,
  group_mappings = group_mappings,
}

return M
