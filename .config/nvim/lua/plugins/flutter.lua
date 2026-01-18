return {
	"akinsho/flutter-tools.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"stevearc/dressing.nvim",
	},
	config = function()
		require("flutter-tools").setup({
			debugger = {
				enabled = true,
				run_via_dap = true,
			},
			widget_guides = {
				enabled = true,
			},
		})
	end,
}
