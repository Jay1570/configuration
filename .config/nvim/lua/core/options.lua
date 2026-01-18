vim.o.number = true
vim.o.relativenumber = true
vim.o.wrap = false
vim.o.mouse = "a"
vim.o.showmode = false

vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = "yes"
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.o.inccommand = "split"
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.opt.sidescroll = 1
vim.opt.sidescrolloff = 8
vim.opt.colorcolumn = { "80", "100" }
vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg = 0, bg = "#2c2c2c" })

vim.o.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.o.expandtab = true
vim.o.confirm = true
