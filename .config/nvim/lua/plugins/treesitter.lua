return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',

  dependencies = {
    'neovim-treesitter/treesitter-parser-registry',
  },

  config = function()
    local parsers = {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'vim',
      'vimdoc',
      'python',
      'javascript',
      'typescript',
      'tsx',
      'json',
    }

    -- Configure Treesitter
    require('nvim-treesitter').setup {}

    -- Install parsers
    require('nvim-treesitter').install(parsers)

    -- Enable highlighting and indentation
    vim.api.nvim_create_autocmd('FileType', {
      pattern = parsers,
      callback = function(args)
        local ok = pcall(vim.treesitter.start, args.buf)

        if ok then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
