local M = {}

local parse = require("beancount.ofx.parser")
local format = require("beancount.format")

M.insert_rows = function(input_path, account)
   local path = vim.fn.glob(input_path)
   if path:find("\n") then
      error(string.format("Multiple matches returned for '%s'", input_path))
   end

   local f = io.open(path, "r")
   if not f then
      error(string.format("Failed to open '%s'", input_path))
   end

   local fdata = f:read("*a")
   f:close()

   local header, data = parse(fdata)
   local statement = format.statement(header, data, account)

   vim.fn.append(".", statement:to_lines())
end

return M
