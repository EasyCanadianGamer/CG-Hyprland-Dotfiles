# Neovim Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a from-scratch, modular Neovim configuration in `~/.config/nvim` using `lazy.nvim`, covering LSP/completion, fuzzy finding, file explorer, git signs, formatting, and UI polish.

**Architecture:** `init.lua` bootstraps `lazy.nvim` and requires three `core/` modules (options, keymaps, autocmds), then `lazy.nvim` auto-imports every plugin spec file under `lua/plugins/`. Each plugin (or tightly related plugin group) gets its own spec file — no central plugin registry.

**Tech Stack:** Neovim 0.12.4, `lazy.nvim`, Lua. Plugins: catppuccin, lualine.nvim, bufferline.nvim, which-key.nvim, nvim-treesitter, telescope.nvim (+telescope-fzf-native), neo-tree.nvim, blink.cmp, nvim-lspconfig + mason.nvim + mason-lspconfig.nvim, conform.nvim, gitsigns.nvim, nvim-autopairs, indent-blankline.nvim (`ibl`).

## Global Constraints

- Config root and git repo: `~/.config/nvim` (already `git init`'d).
- Leader key: `<space>`.
- Plugin manager: `lazy.nvim`, auto-importing `lua/plugins/*.lua`.
- Colorscheme: `catppuccin`, mocha flavor.
- File explorer: `neo-tree.nvim` (not oil.nvim), toggled with `<leader>e`.
- Completion engine: `blink.cmp` (not nvim-cmp).
- LSP: `nvim-lspconfig` + `mason.nvim` + `mason-lspconfig.nvim`, using Neovim's native `vim.lsp.config`/`vim.lsp.enable` API (Neovim 0.11+). `ensure_installed` starts with only `lua_ls`.
- Keymap groups: `<leader>f*` telescope, `<leader>e` explorer, `<leader>g*` git, `gd`/`gr`/`K`/`<leader>rn`/`<leader>ca`/`[d`/`]d` LSP.
- No dashboard plugin, no cmdline-replacement plugin (e.g. noice.nvim) — out of scope.
- There is no automated test suite for a Neovim config. "Testing" in each task means: (a) an automatable headless-Neovim check that plugins load with no Lua errors, and (b) a manual interactive check of the actual feature. Both are required before a task is considered done.

---

### Task 1: Bootstrap lazy.nvim and core settings

**Files:**
- Create: `init.lua`
- Create: `lua/core/options.lua`
- Create: `lua/core/keymaps.lua`
- Create: `lua/core/autocmds.lua`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `vim.g.mapleader = " "` and `vim.g.maplocalleader = " "` (set before lazy.nvim loads — every later plugin task relies on this for its `<leader>...` keymaps). `lazy.nvim` available as the `lazy` module, configured with `{ import = "plugins" }` so any file later added under `lua/plugins/` is auto-loaded.

- [ ] **Step 1: Write `lua/core/options.lua`**

```lua
local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.splitright = true
opt.splitbelow = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.updatetime = 250
opt.timeoutlen = 300
```

- [ ] **Step 2: Write `lua/core/keymaps.lua`**

```lua
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- keep selection when indenting in visual mode
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })
```

- [ ] **Step 3: Write `lua/core/autocmds.lua`**

```lua
-- highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = vim.api.nvim_create_augroup("user-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- restore cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Restore cursor position",
  group = vim.api.nvim_create_augroup("user-restore-cursor", { clear = true }),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})
```

- [ ] **Step 4: Write `init.lua`**

```lua
require("core.keymaps")
require("core.options")
require("core.autocmds")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "default" } },
  checker = { enabled = false },
})
```

Note: `lua/plugins/` doesn't exist yet, so `{ import = "plugins" }` currently imports zero specs — that's expected until Task 2.

- [ ] **Step 5: Verify no Lua errors on startup**

Run: `nvim --headless -c "lua print('OK')" -c "qa" 2>&1`
Expected: prints `OK` with no error traceback. (First run also clones `lazy.nvim` — expect a few seconds of git clone output, that's normal.)

- [ ] **Step 6: Manual check**

Open `nvim` interactively. Confirm: line numbers are relative, `<space>w` saves, `<C-h/j/k/l>` would move between splits (open `:vsplit` to try it), no error messages on startup.

- [ ] **Step 7: Commit**

```bash
cd ~/.config/nvim
git add init.lua lua/core
git commit -m "Bootstrap lazy.nvim and core options/keymaps/autocmds"
```

---

### Task 2: Colorscheme and UI (catppuccin, lualine, bufferline, which-key)

**Files:**
- Create: `lua/plugins/ui.lua`

**Interfaces:**
- Consumes: `vim.g.mapleader` from Task 1 (which-key needs it set before it's `require`d, already guaranteed since `core/keymaps.lua` loads before `lazy.setup`).
- Produces: active colorscheme `catppuccin-mocha`. Later plugin tasks (telescope, neo-tree, gitsigns, blink.cmp) will each set `enabled = true` under `opts.integrations`/similar in this same file's `catppuccin` block as those plugins are added — noted in each relevant task.

- [ ] **Step 1: Write `lua/plugins/ui.lua`**

```lua
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = {
        cmp = false, -- blink.cmp integration enabled in Task 6
        gitsigns = false, -- enabled in Task 9
        treesitter = true,
        telescope = { enabled = false }, -- enabled in Task 4
        which_key = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = { theme = "catppuccin" },
    },
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = { diagnostics = "nvim_lsp" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
```

- [ ] **Step 2: Sync plugins headlessly and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: output shows catppuccin, lualine.nvim, bufferline.nvim, which-key.nvim, nvim-web-devicons installed, no `Error` lines.

- [ ] **Step 3: Manual check**

Open `nvim`. Confirm: catppuccin mocha colors are active, a statusline is visible at the bottom (lualine), a buffer tab line appears at the top when 2+ files are open (`:e file1`, `:e file2`, `:bufferline`... just open two files and look at the top), and pressing `<space>` and waiting briefly pops up the which-key window.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/ui.lua
git commit -m "Add catppuccin colorscheme, lualine, bufferline, which-key"
```

---

### Task 3: Treesitter

**Files:**
- Create: `lua/plugins/treesitter.lua`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: treesitter parsers installed for a base set of languages; later LSP task does not depend on this but benefits from it (better folding/indent context).

- [ ] **Step 1: Write `lua/plugins/treesitter.lua`**

```lua
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  opts = {
    ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
    auto_install = true,
    highlight = { enable = true },
    indent = { enable = true },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
```

- [ ] **Step 2: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `nvim-treesitter` installed, listed parsers compiled with no `Error` lines. (Compiling parsers needs a C compiler — if this fails with a missing-compiler error, note it and continue; `auto_install` will retry per-filetype later.)

- [ ] **Step 3: Manual check**

Open a `.lua` file (e.g. `init.lua`) in `nvim`. Confirm syntax highlighting looks richer than plain Lua keyword highlighting (e.g. function calls, table keys colored distinctly). Run `:InspectTree` and confirm a syntax tree window opens.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/treesitter.lua
git commit -m "Add nvim-treesitter with base parser set"
```

---

### Task 4: Telescope

**Files:**
- Create: `lua/plugins/telescope.lua`
- Modify: `lua/plugins/ui.lua:11` (flip `telescope = { enabled = false }` to `true` in the catppuccin integrations table)

**Interfaces:**
- Consumes: catppuccin plugin spec from Task 2 (modifies its `opts`).
- Produces: `<leader>ff`, `<leader>fg`, `<leader>fb`, `<leader>fh` global keymaps. Later LSP task (Task 7) uses `require("telescope.builtin")` for `<leader>fr`/references-style pickers if desired, but that's optional — not a hard dependency.

- [ ] **Step 1: Write `lua/plugins/telescope.lua`**

```lua
return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({})
    pcall(telescope.load_extension, "fzf")
  end,
}
```

- [ ] **Step 2: Update `lua/plugins/ui.lua`**

Change:
```lua
        telescope = { enabled = false }, -- enabled in Task 4
```
To:
```lua
        telescope = { enabled = true },
```

- [ ] **Step 3: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `telescope.nvim`, `plenary.nvim`, `telescope-fzf-native.nvim` installed, `make` build step for fzf-native completes with no `Error` lines. (If `make`/a C compiler isn't available, fzf-native's build will fail — telescope still works with its default sorter, just slower; not a blocker.)

- [ ] **Step 4: Manual check**

Open `nvim` inside `~/.config/nvim`. Press `<leader>ff`, confirm a file picker opens listing `init.lua`, `lua/...`. Press `<leader>fg`, type `mapleader`, confirm it finds the line in `lua/core/keymaps.lua`. Close pickers with `<Esc>`.

- [ ] **Step 5: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/telescope.lua lua/plugins/ui.lua
git commit -m "Add telescope fuzzy finder with fzf-native sorter"
```

---

### Task 5: Neo-tree file explorer

**Files:**
- Create: `lua/plugins/explorer.lua`

**Interfaces:**
- Consumes: nothing from prior tasks (uses `nvim-web-devicons`, already installed as a dependency in Task 2).
- Produces: `<leader>e` global keymap toggling the explorer.

- [ ] **Step 1: Write `lua/plugins/explorer.lua`**

```lua
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
  },
  opts = {
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
    },
  },
}
```

- [ ] **Step 2: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `neo-tree.nvim`, `nui.nvim` installed (plenary/devicons already present), no `Error` lines.

- [ ] **Step 3: Manual check**

Open `nvim` inside `~/.config/nvim`. Press `<leader>e`, confirm a sidebar tree opens showing `init.lua`, `lua/`. Navigate into `lua/plugins/`, press `<Enter>` on a file to open it, confirm it opens in the main window. Press `<leader>e` again to close the sidebar.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/explorer.lua
git commit -m "Add neo-tree file explorer"
```

---

### Task 6: Completion (blink.cmp)

**Files:**
- Create: `lua/plugins/completion.lua`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: `require("blink.cmp").get_lsp_capabilities()` — Task 7 (LSP) calls this function to merge completion capabilities into `vim.lsp.config('*', ...)`.

- [ ] **Step 1: Write `lua/plugins/completion.lua`**

```lua
return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "InsertEnter",
  opts = {
    keymap = { preset = "default" },
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      documentation = { auto_show = true },
    },
    signature = { enabled = true },
  },
}
```

- [ ] **Step 2: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `blink.cmp` installed (its Rust fuzzy-matcher prebuilt binary downloads automatically), no `Error` lines.

- [ ] **Step 3: Manual check**

Open any file in `nvim`, enter insert mode, type a few characters. Confirm a completion menu appears (it will be sourced from buffer words/paths until Task 7 adds LSP sources).

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/completion.lua
git commit -m "Add blink.cmp completion engine"
```

---

### Task 7: LSP (nvim-lspconfig + mason.nvim + mason-lspconfig.nvim)

**Files:**
- Create: `lua/plugins/lsp.lua`

**Interfaces:**
- Consumes: `require("blink.cmp").get_lsp_capabilities()` from Task 6.
- Produces: buffer-local LSP keymaps (`gd`, `gr`, `K`, `<leader>rn`, `<leader>ca`, `[d`, `]d`) set on `LspAttach`. `lua_ls` enabled and configured for editing this config (recognizes `vim` global).

- [ ] **Step 1: Write `lua/plugins/lsp.lua`**

```lua
return {
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "mason-org/mason.nvim",
      "saghen/blink.cmp",
    },
    opts = {
      ensure_installed = { "lua_ls" },
    },
    config = function(_, opts)
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      require("mason-lspconfig").setup(opts)

      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "Set LSP buffer keymaps",
        group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
        callback = function(args)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
          end
          map("n", "gd", vim.lsp.buf.definition, "Go to definition")
          map("n", "gr", vim.lsp.buf.references, "Go to references")
          map("n", "K", vim.lsp.buf.hover, "Hover docs")
          map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
          map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
        end,
      })
    end,
  },
}
```

- [ ] **Step 2: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `mason.nvim`, `mason-lspconfig.nvim`, `nvim-lspconfig` installed, no `Error` lines.

- [ ] **Step 3: Verify lua_ls installs and attaches**

Run: `nvim --headless "+MasonInstall lua_ls" +qa 2>&1`
Expected: output shows `lua_ls` installed successfully (or `already installed` on a re-run).

- [ ] **Step 4: Manual check**

Open `init.lua` in `nvim`. Run `:LspInfo`, confirm `lua_ls` is listed as attached. Hover over `vim.opt` with cursor on `opt` and press `K`, confirm a hover doc popup appears. Confirm no "undefined global `vim`" diagnostic appears anywhere in the file.

- [ ] **Step 5: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/lsp.lua
git commit -m "Add LSP via mason.nvim + mason-lspconfig.nvim, wire blink.cmp capabilities"
```

---

### Task 8: Formatting (conform.nvim)

**Files:**
- Create: `lua/plugins/format.lua`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: format-on-save for `lua` filetype via `stylua`; `<leader>cf` manual format keymap.

- [ ] **Step 1: Write `lua/plugins/format.lua`**

```lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  },
}
```

- [ ] **Step 2: Install stylua and sync**

Run: `nvim --headless "+MasonInstall stylua" "+Lazy! sync" +qa 2>&1`
Expected: `stylua` and `conform.nvim` installed, no `Error` lines.

- [ ] **Step 3: Manual check**

Open `lua/core/options.lua`, mess up its indentation on one line (add extra spaces), save with `:w`. Confirm the indentation is auto-corrected on save. Undo with `u` if needed to restore the original.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/format.lua
git commit -m "Add conform.nvim for format-on-save (stylua for Lua)"
```

---

### Task 9: Git integration (gitsigns.nvim)

**Files:**
- Create: `lua/plugins/git.lua`
- Modify: `lua/plugins/ui.lua:10` (flip `gitsigns = false` to `true`)

**Interfaces:**
- Consumes: catppuccin plugin spec from Task 2 (modifies its `opts`).
- Produces: `<leader>gp`, `<leader>gs`, `<leader>gr` keymaps for hunk preview/stage/reset.

- [ ] **Step 1: Write `lua/plugins/git.lua`**

```lua
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end
      map("n", "<leader>gp", gitsigns.preview_hunk, "Preview hunk")
      map("n", "<leader>gs", gitsigns.stage_hunk, "Stage hunk")
      map("n", "<leader>gr", gitsigns.reset_hunk, "Reset hunk")
    end,
  },
}
```

- [ ] **Step 2: Update `lua/plugins/ui.lua`**

Change:
```lua
        gitsigns = false, -- enabled in Task 9
```
To:
```lua
        gitsigns = true,
```

- [ ] **Step 3: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `gitsigns.nvim` installed, no `Error` lines.

- [ ] **Step 4: Manual check**

Inside `~/.config/nvim` (already a git repo), edit a line in `lua/core/options.lua` and save (don't commit). Open the file in `nvim`, confirm a `~` or `|` sign appears in the sign column next to the changed line. Press `<leader>gp`, confirm a hunk diff preview popup appears. Press `<leader>gr` on that line to reset it back, confirm the sign disappears.

- [ ] **Step 5: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/git.lua lua/plugins/ui.lua
git commit -m "Add gitsigns for inline hunk signs and staging"
```

---

### Task 10: Editing quality-of-life (autopairs, indent guides)

**Files:**
- Create: `lua/plugins/editing.lua`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: nothing consumed by later tasks (this is the last plugin file).

- [ ] **Step 1: Write `lua/plugins/editing.lua`**

```lua
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}
```

- [ ] **Step 2: Sync and check for errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: `nvim-autopairs`, `indent-blankline.nvim` installed, no `Error` lines.

- [ ] **Step 3: Manual check**

Open a `.lua` file, enter insert mode, type `(`. Confirm `)` is auto-inserted. Confirm vertical indent guide lines are visible on indented blocks (e.g. inside a `function ... end`).

- [ ] **Step 4: Commit**

```bash
cd ~/.config/nvim
git add lua/plugins/editing.lua
git commit -m "Add nvim-autopairs and indent-blankline"
```

---

### Task 11: Final validation

**Files:** none created/modified — verification only.

**Interfaces:**
- Consumes: the entire config from Tasks 1–10.
- Produces: nothing (terminal task).

- [ ] **Step 1: Full headless sync with no errors**

Run: `nvim --headless "+Lazy! sync" +qa 2>&1`
Expected: no `Error` lines; all plugins listed as installed/up to date.

- [ ] **Step 2: Run `:checkhealth` and inspect output**

Run: `nvim --headless -c "checkhealth" -c "w! /tmp/nvim-health.txt" -c "qa" 2>&1 && grep -iE "error|warning" /tmp/nvim-health.txt`
Expected: no `ERROR` entries related to any plugin installed in this plan (pre-existing unrelated warnings, e.g. missing optional system tools like `ripgrep` if not installed, are worth noting to the user but are not this plan's responsibility to fix — flag them instead of silently ignoring).

- [ ] **Step 3: Manual end-to-end walkthrough**

Open `nvim` inside `~/.config/nvim` interactively and confirm, in one session:
- Colorscheme is catppuccin mocha, statusline and buffer tabs visible.
- `<leader>ff` and `<leader>fg` open telescope pickers and find real results.
- `<leader>e` opens neo-tree, can open a file from it.
- Opening `init.lua` shows treesitter highlighting, `:LspInfo` shows `lua_ls` attached, hovering with `K` shows docs, typing in insert mode shows a blink.cmp completion menu.
- Editing and saving a `.lua` file with bad indentation auto-formats via conform/stylua.
- Editing a tracked file shows a gitsigns sign; `<leader>gp` previews the hunk.
- Typing `(` in insert mode auto-closes it; indent guides are visible.
- `<space>` alone (wait ~300ms) pops up which-key.

- [ ] **Step 4: Record any pre-existing `:checkhealth` warnings for the user**

If Step 2 surfaced warnings unrelated to plugins added in this plan (e.g. no `ripgrep` installed — needed for `telescope.live_grep` to work at all, not just to be fast), report these to the user as follow-ups rather than silently fixing or ignoring them.

- [ ] **Step 5: Final commit (if anything changed during validation)**

```bash
cd ~/.config/nvim
git status
```
If clean, no commit needed — Task 11 is verification-only. If any fixes were made while addressing Step 2/3 findings, commit them with a message describing what was fixed.
