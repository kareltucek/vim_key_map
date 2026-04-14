if vim.g.loaded_key_map == 1 then return end
vim.g.loaded_key_map = 1

vim.api.nvim_create_user_command('KeyMap', function(opts)
  local mode = opts.args ~= '' and opts.args or 'n'
  require('key_map').show_mode(mode, { defaults = not opts.bang })
end, {
  nargs = '?',
  bang = true,
  complete = function()
    return { 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }
  end,
  desc = 'Show active key bindings for a single mode, grouped by base key (use ! to hide defaults)',
})

vim.api.nvim_create_user_command('KeyMapAll', function(opts)
  require('key_map').show_all({ defaults = not opts.bang })
end, {
  bang = true,
  desc = 'Show active key bindings across all modes (use ! to hide defaults)',
})
