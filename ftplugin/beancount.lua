vim.opt_local.cursorline = true
vim.opt_local.cursorlineopt = "line"

vim.api.nvim_create_user_command("Bimport", function(args)
   local account = vim.fn.input("Account: ", "", "tag")
   require("beancount").insert_rows(args.args, account)
end, {
   nargs = 1,
   complete = "file",
   desc = "Import .qfx data into the current file"
})
