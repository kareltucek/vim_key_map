local M = {}

local SECTION_MODES = {
  ['1']   = { 'i' },
  ['2']   = { 'n' },
  ['2.1'] = { 'x', 'o' },
  ['2.2'] = { 'n' },
  ['2.3'] = { 'n' },
  ['2.4'] = { 'n' },
  ['2.5'] = { 'n' },
  ['2.6'] = { 'o' },
  ['3']   = { 'x' },
  ['4']   = { 'c' },
  ['5']   = { 't' },
}

local function normalize_char_spec(s)
  local parts = {}
  for tok in s:gmatch('%S+') do table.insert(parts, tok) end
  local out = {}
  for _, tok in ipairs(parts) do
    local upper = tok:upper()
    if upper:match('^CTRL%-SHIFT%-') then
      table.insert(out, '<C-S-' .. tok:sub(12) .. '>')
    elseif upper:match('^CTRL%-') and #tok > 5 then
      table.insert(out, '<C-' .. tok:sub(6) .. '>')
    elseif upper:match('^META%-') or upper:match('^ALT%-') then
      table.insert(out, '<M-' .. tok:sub(6) .. '>')
    elseif upper:match('^SHIFT%-') then
      table.insert(out, '<S-' .. tok:sub(7) .. '>')
    else
      table.insert(out, tok)
    end
  end
  return table.concat(out, '')
end

local function parse_entry_line(line)
  local rest
  if line:sub(1, 1) == '|' or line:sub(1, 1) == '*' then
    local rem = line:match('^[|*][^|*]+[|*]%s+(.+)$')
    if not rem then return nil end
    rest = rem
  else
    rest = line:match('^%s+(%S.*)$')
    if not rest then return nil end
  end

  local char_spec, tail
  local tab_pos = rest:find('\t')
  if tab_pos then
    char_spec = rest:sub(1, tab_pos - 1)
    tail = rest:sub(tab_pos + 1):gsub('^%s+', '')
  else
    char_spec, tail = rest:match('^(%S+)%s%s+(.*)$')
    if not char_spec then return nil end
  end

  char_spec = char_spec:gsub('%s+$', '')
  if char_spec == '' then return nil end

  local note, desc = tail:match('^([12][,12]*)%s+(.*)$')
  if not note then desc = tail end

  desc = desc:gsub('%s+$', '')
  return char_spec, desc
end

local function is_continuation(line)
  local first = line:sub(1, 1)
  if first ~= '\t' and first ~= ' ' then return false end
  local stripped = line:gsub('^%s+', '')
  if stripped == '' then return false end
  if stripped:sub(1, 1) == '|' or stripped:sub(1, 1) == '*' then return false end
  if stripped:find('\t') then return false end
  if stripped:find('%S  +%S') then return false end
  return true
end

local function skip_placeholder(char_spec)
  if char_spec:match('^{') then return true end
  if char_spec:match('^CHAR$') or char_spec:match('^WORD$') then return true end
  return false
end

local cached

local function build()
  local files = vim.api.nvim_get_runtime_file('doc/index.txt', false)
  if not files or #files == 0 then return {} end
  local lines = {}
  local f = io.open(files[1], 'r')
  if not f then return {} end
  for line in f:lines() do table.insert(lines, line) end
  f:close()

  local by_mode = { n = {}, i = {}, x = {}, o = {}, c = {}, t = {} }
  local current_section = nil
  local in_table = false
  local last_entry = nil

  for _, line in ipairs(lines) do
    local num = line:match('^(%d+%.%d+)%s+%S') or line:match('^(%d+)%.%s+%S')
    if num then
      current_section = num
      in_table = false
      last_entry = nil
    elseif line:match('^%-%-%-%-%-') or line:match('^=====') then
      if line:match('^%-%-%-') then in_table = true end
      last_entry = nil
    elseif in_table and current_section and SECTION_MODES[current_section] then
      if line:match('^%s*$') then
        last_entry = nil
      elseif is_continuation(line) and last_entry then
        local cont = line:gsub('^%s+', ''):gsub('%s+$', '')
        if cont ~= '' then
          last_entry.desc = last_entry.desc .. ' ' .. cont
        end
      else
        local char_spec, desc = parse_entry_line(line)
        if char_spec and desc and desc ~= '' and not skip_placeholder(char_spec) then
          local lhs = normalize_char_spec(char_spec)
          local entry = { lhs = lhs, desc = desc, builtin = true }
          for _, mode in ipairs(SECTION_MODES[current_section]) do
            table.insert(by_mode[mode], entry)
          end
          last_entry = entry
        else
          last_entry = nil
        end
      end
    end
  end

  return by_mode
end

function M.get(mode)
  if not cached then cached = build() end
  return cached[mode] or {}
end

function M.all()
  if not cached then cached = build() end
  return cached
end

function M.reload()
  cached = nil
end

return M
