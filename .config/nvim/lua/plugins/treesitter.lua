return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    -- Neovim doesn't know "sh" files should use the "bash" grammar unless told.
    vim.treesitter.language.register("bash", "sh")

    local ts = require("nvim-treesitter")
    local ts_config = require("nvim-treesitter.config")

    local ensure_installed = {
      "lua",
      "vim",
      "vimdoc",
      "query",
      "markdown",
      "markdown_inline",
      "bash",
      "python",
      "java",
    }

    local installed = ts_config.get_installed("parsers")
    local missing = vim.tbl_filter(function(lang)
      return not vim.list_contains(installed, lang)
    end, ensure_installed)
    if #missing > 0 then
      ts.install(missing)
    end

    vim.api.nvim_create_autocmd("FileType", {
      desc = "Auto-install missing parsers and start treesitter highlighting/indent",
      group = vim.api.nvim_create_augroup("user-treesitter-start", { clear = true }),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang then
          return
        end

        if
          not vim.list_contains(ts_config.get_installed("parsers"), lang)
          and vim.list_contains(ts_config.get_available(), lang)
        then
          local ok = pcall(function()
            ts.install(lang):wait(120000)
          end)
          if not ok then
            return
          end
        end

        if pcall(vim.treesitter.start, args.buf, lang) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
