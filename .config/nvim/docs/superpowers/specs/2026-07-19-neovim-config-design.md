# Neovim Config — Design

**Date:** 2026-07-19
**Status:** Approved

## Purpose

Build a personal Neovim configuration from scratch (not a pre-built distro) using
`lazy.nvim` as the plugin manager. The user is comfortable with Vim motions but
wants a fully-understood, general-purpose, multi-language setup — not tied to
one ecosystem.

## Non-goals

- Not a distro (no LazyVim/AstroNvim/NvChad dependency) — every plugin choice
  should be visible and swappable.
- Not pre-installing every language server up front — only `lua_ls` ships by
  default; other languages are added on demand via Mason.
- No dashboard/splash-screen plugin, no `noice.nvim`-style cmdline overhaul —
  kept out to stay lean; can be added later if wanted.

## Location

The config lives directly in `~/.config/nvim`, which is also the git repo root
(`git init` already run there). This project directory (`~/neovim`) is
unrelated to this task.

## Architecture

```
~/.config/nvim/
├── init.lua                  -- bootstraps lazy.nvim, requires core modules
├── lua/
│   ├── core/
│   │   ├── options.lua       -- vim.opt settings
│   │   ├── keymaps.lua       -- non-plugin keymaps
│   │   └── autocmds.lua      -- autocommands
│   └── plugins/
│       ├── lsp.lua           -- lspconfig + mason + mason-lspconfig
│       ├── completion.lua    -- blink.cmp
│       ├── treesitter.lua
│       ├── telescope.lua
│       ├── explorer.lua      -- neo-tree
│       ├── git.lua           -- gitsigns
│       ├── ui.lua            -- catppuccin, lualine, bufferline, which-key
│       ├── editing.lua       -- autopairs, indent-blankline
│       └── format.lua        -- conform.nvim
```

`lazy.nvim` is configured to auto-import every plugin spec file under
`lua/plugins/`, so adding a new plugin later means adding a new file — there is
no central plugin registry to edit.

## Plugin list

**Foundation**
- `lazy.nvim` — plugin manager, bootstrapped from `init.lua` on first launch
- `catppuccin` (mocha flavor) — colorscheme, with integrations enabled for
  telescope/lualine/bufferline/gitsigns/etc.

**LSP & completion**
- `nvim-lspconfig` + `mason.nvim` + `mason-lspconfig.nvim` — install/configure
  language servers via `:Mason`. `ensure_installed` starts with just `lua_ls`;
  adding another language is a one-line addition plus optional per-server
  settings table.
- `blink.cmp` — completion engine (chosen over `nvim-cmp` for minimal config
  and speed; `nvim-cmp` is the documented fallback if a specific completion
  source is only available for it).
- `conform.nvim` — format-on-save, per-filetype formatters installed via
  Mason as needed (e.g. `stylua` for Lua).

**Navigation & search**
- `telescope.nvim` + `telescope-fzf-native.nvim` — fuzzy find files, live
  grep, buffers, LSP references/symbols
- `neo-tree.nvim` — sidebar file explorer, toggled with `<leader>e`

**Editing**
- `nvim-treesitter` — treesitter-based highlighting/indent
- `gitsigns.nvim` — inline hunk signs, blame, stage/reset hunks
- `nvim-autopairs` — auto-close brackets/quotes
- native `gc` / `gcc` for comments (built into Neovim 0.10+, no plugin needed)
- `indent-blankline.nvim` — indent guides

**UI/discoverability**
- `lualine.nvim` — statusline
- `bufferline.nvim` — buffer tabs
- `which-key.nvim` — popup showing available keymaps as a prefix is typed

## Keymaps & options

- Leader: `<space>`
- Keymap conventions follow common kickstart/LazyVim-style groupings so
  external docs/cheatsheets mostly transfer:
  - `<leader>f*` — telescope (`ff` find files, `fg` live grep, `fb` buffers)
  - `<leader>e` — toggle neo-tree
  - `<leader>g*` — gitsigns hunk stage/reset/preview
  - `gd`, `gr`, `K`, `<leader>rn`, `<leader>ca` — LSP goto-def, references,
    hover, rename, code action
  - `[d` / `]d` — jump to prev/next diagnostic
- `core/options.lua` sets: relative number, 2-space indent, persistent undo,
  sensible split direction, `termguicolors`, system clipboard sync, mouse
  enabled.

## Testing / validation

- Launch `nvim` after initial setup and confirm `lazy.nvim` bootstraps and
  installs all plugins without error (`:Lazy` shows no failures).
- Open a `.lua` file and confirm: treesitter highlighting active, `lua_ls`
  attaches (`:LspInfo`), completion popup appears, format-on-save runs
  (`stylua` via conform).
- Confirm `<leader>ff`, `<leader>fg`, `<leader>e`, gitsigns signs in a git
  repo, and which-key popup on `<leader>` all work.
- No errors on `:checkhealth`.
