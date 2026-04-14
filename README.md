# vim_key_map

A Neovim plugin that lists active key bindings **grouped by base key**, so you
can see at a glance what `a` / `A` / `<C-a>` / `<C-S-a>` all do — and which
slots are still free.

Most `:map` listings are a flat, alphabetic dump. This one is organized the
way you actually think about key bindings: "what's bound to `g`?", "is `<C-t>`
free?".

## Features

- Three-column output: **lhs | description | source**
- Bindings grouped by the base key they start from (case-folded), so `A`, `a`,
  `<C-a>`, `<C-S-a>`, `aw`, `ap` all appear under `a:`.
- Empty slots for `a`–`z` are shown, so you can spot which keys are free.
- **Built-in Vim defaults are included** — parsed from your Neovim's shipped
  `:help index.txt` at runtime, so they stay in sync with your version.
- User mappings override defaults for the same lhs; no duplication.
- Source column tells you **where each mapping came from**: the plugin file,
  your config, or `vim-builtin`. Lua callbacks are resolved via
  `debug.getinfo`.
- Buffer-local mappings are marked `(buffer-local)`.

## Installation

**lazy.nvim:**
```lua
{ 'user/vim_key_map' }          -- from GitHub
-- or
{ dir = '/opt/vim_key_map' }    -- local checkout
```

**packer.nvim:**
```lua
use 'user/vim_key_map'
```

**vim-plug:**
```vim
Plug 'user/vim_key_map'
```

**No plugin manager:**
```lua
vim.opt.runtimepath:prepend('/path/to/vim_key_map')
```

Or symlink into a pack directory:
```bash
ln -s /path/to/vim_key_map ~/.config/nvim/pack/local/start/vim_key_map
```

## Usage

| Command         | What it does                                                        |
| --------------- | ------------------------------------------------------------------- |
| `:KeyMap`       | Normal-mode bindings (defaults + user + buffer-local)               |
| `:KeyMap {m}`   | Bindings for mode `m` — one of `n i v x s o c t`                    |
| `:KeyMap!`      | Same as above but **user mappings only** (no built-in defaults)     |
| `:KeyMapAll`    | All modes in one list, with `[mode]` tags                           |
| `:KeyMapAll!`   | All modes, user-only                                                |

Output opens in a read-only scratch split. Press `q` to close.

### Example

```
Active key bindings for mode "n" (user mappings override defaults; empty slots are free):

- a:
    A          append text after the end of the line N times     vim-builtin
    a          append-forward                                    init.lua
    <C-A>      add N to number at/after cursor                   vim-builtin

- b:
    B          cursor N WORDS backward                           vim-builtin
    b          cursor N words backward                           vim-builtin
    <C-B>      scroll N screens Backwards                        vim-builtin

- c:
    <C-C>      interrupt current (search) command                vim-builtin

...

- g:
    G          cursor to line N, default last line               vim-builtin
    g%         → <Plug>(MatchitNormalBackward)                   plugin/matchit.vim
    gT         go to the previous tab page                       vim-builtin
    gf         → tih0<Esc>                                       init.lua
    gg         cursor to line N, default first line              vim-builtin
    gt         go to the next tab page                           vim-builtin
```

## How source resolution works

For each mapping, the plugin determines its origin with this priority:

1. `sid` from `nvim_get_keymap` → looked up in `vim.fn.getscriptinfo()` for
   the defining script path.
2. For Lua callbacks without a useful `sid` (e.g. anonymous functions),
   `debug.getinfo(callback, 'S').source` gives the defining file.
3. Built-ins parsed from `runtime/doc/index.txt` are tagged `vim-builtin`.
4. Anything unresolvable shows `?`. This typically means the mapping was
   set via `:luafile` or via a string-`rhs` with no callback and a zero
   `sid` (rare).

Paths are shortened to their last two components, and `$HOME` is rendered
as `~`.

## How grouping works

The base key for an lhs is the first keystroke, lowercased:

| lhs           | base key |
| ------------- | -------- |
| `a`, `A`      | `a`      |
| `<C-a>`       | `a`      |
| `<C-S-e>`     | `e`      |
| `aw`, `ap`    | `a`      |
| `gT`, `gg`    | `g`      |
| `<leader>f`   | `\` (or whatever your leader is) |
| `<Plug>(foo)` | `<plug>` |
| `[d`, `]d`    | `[`, `]` |

Within a group, entries are sorted so plain keys come before bracketed ones,
then by length, then lexicographically.

## Modes

| Code | Mode              |
| ---- | ----------------- |
| `n`  | Normal            |
| `i`  | Insert            |
| `v`  | Visual + Select   |
| `x`  | Visual only       |
| `s`  | Select            |
| `o`  | Operator-pending  |
| `c`  | Command-line      |
| `t`  | Terminal          |

Defaults are loaded for `n`, `i`, `x`, `o`, `c`. The `v`/`s` modes inherit
visible mappings from `x` indirectly via user mappings (the `v` mode flag in
Vim covers both visual and select).

## License

Do whatever you want.
