return {
	{
		"NMAC427/guess-indent.nvim",
		config = function()
			require("guess-indent").setup({
				auto_cmd = true,
				override_editorconfig = false,
				filetype_exclude = { "netrw", "tutor" },
				buftype_exclude = { "help", "nofile", "terminal", "prompt" },
				on_tab_options = { ["expandtab"] = false },
				on_space_options = {
					["expandtab"] = true,
					["tabstop"] = "detected",
					["softtabstop"] = "detected",
					["shiftwidth"] = "detected",
				},
			})
		end,
	},
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	require("kickstart.plugins.debug"),
	require("kickstart.plugins.indent_line"),
	require("kickstart.plugins.lint"),
	require("kickstart.plugins.autopairs"),
	require("kickstart.plugins.gitsigns"),
	-- require 'kickstart.plugins.neo-tree',
}
