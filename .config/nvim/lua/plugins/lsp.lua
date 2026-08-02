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
      ensure_installed = { "lua_ls", "pyright", "bashls", "jdtls" },
      -- Explicit allowlist (not exclude-list): only auto-enable servers we
      -- actually asked for. Otherwise mason-lspconfig auto-enables *any*
      -- installed Mason package with a matching LSP config, including
      -- formatters/tools that happen to ship an --lsp mode (e.g. stylua).
      automatic_enable = { "lua_ls", "pyright", "bashls", "jdtls" },
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
