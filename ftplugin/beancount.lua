vim.opt_local.cursorline = true
vim.opt_local.cursorlineopt = "line"

vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

vim.opt_local.makeprg = 'bean-check %'
vim.opt_local.errorformat = { '%-G', '%f:%l: %m', '%-G %.%#' }

-- Allows for easier use of tags w/ <C-]>. Can also search for a tag with:
--    $ vim -t '/checking'
-- If a tag file exists, it will start vim on the tag.
--
vim.opt_local.iskeyword:append(':')    -- Colon sep. in accounts
vim.opt_local.iskeyword:append('-')    -- Dash sep. in accounts, dates
vim.opt_local.iskeyword:append('.')    -- Treat currency as a "word"

vim.opt_local.comments = { 'b:;' }
vim.opt_local.commentstring = ';%s'

vim.opt_local.shiftwidth  = 2
vim.opt_local.tabstop     = 2
vim.opt_local.softtabstop = 2

vim.opt_local.foldenable = true
vim.opt_local.foldlevel  = 1
-- Can use org-mode `*` to start section headings, which can be folded via
-- defined treesitter folds.

local function format()
   vim.cmd.write()
   vim.cmd [[:norm m`]]
   vim.cmd [[:silent! %! bean-format --currency-column 54 %]]
   vim.cmd [[:norm ``]]
end

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
   pattern = "*.beancount",
   callback = function()
      vim.cmd [[:silent! !ctags *.beancount]]
   end,
})

vim.api.nvim_buf_create_user_command(0, 'Bformat', format, {})
vim.api.nvim_buf_create_user_command(0, 'Bcheck',
   [[:silent! lmake | lwindow 5]], {})

vim.api.nvim_create_user_command("Bimport", function(args)
   local account = vim.fn.input("Account: ", "", "tag")
   require("beancount").insert_rows(args.args, account)
end, {
   nargs = 1,
   complete = "file",
   desc = "Import .qfx data into the current file"
})
