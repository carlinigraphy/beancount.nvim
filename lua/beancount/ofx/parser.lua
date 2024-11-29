local scan = require("beancount.ofx.scanner")
local header_parser = require("beancount.ofx.header_parser")

---@alias XML
---| string
---| integer
---| [string, XML]

---@class Object
local Object = {}
Object.__type = "Object" -- not "real" metamethod; is for me.
Object.__index = Object
Object.__tostring = function(tbl)
   local key = rawget(tbl, 1)
   local val = rawget(tbl, 2)

   if type(val) == "string" then
      val = '"'..val..'"'
   else
      val = tostring(val)
   end

   return key..": "..val
end

---@param key    string
---@param value  XML
---@return Object
function Object:new(key, value)
   return setmetatable({ key, value }, self)
end

---@param index  string
---@param opts? { lax: boolean }
---@return XML?
function Object:get(index, opts)
   opts = opts or {}

   if index == rawget(self, 1) then
      return rawget(self, 2)
   else
      if opts.lax then
         return
      else
         error("Index '"..index.."' not found in "..tostring(self), 2)
      end
   end
end


---@class List
local List = {}
List.__type = "List" -- not "real" metamethod; is for me.
List.__index = List
List.__tostring = function(tbl)
   local function pad_lines(str, pos, buf, acc)
      local char = str:sub(pos, pos)
      if char == "" then
         table.insert(acc, "  " .. buf)
         return table.concat(acc, "\n")
      elseif char == "\n" then
         table.insert(acc, "  " .. buf)
         return pad_lines(str, pos+1, "", acc)
      else
         return pad_lines(str, pos+1, buf .. char, acc)
      end
   end

   local str = { "[" }
   for _,v in ipairs(tbl) do
      if type(v) == "string" then
         table.insert(str, "  \""..v.."\"")
      elseif type(v) == "table" then
         table.insert(str, pad_lines(tostring(v), 1, "", {}))
      else
         assert(false, "unreachable")
      end
   end

   table.insert(str, "]")
   return table.concat(str, "\n")
end

---@param ... XML
---@return List
function List:new(...)
   local lst = {}
   for _,v in ipairs({...}) do
      table.insert(lst, v)
   end
   return setmetatable(lst, self)
end


---@param lst  XML[]
function List:from(lst)
   local xml = {}
   for _, v in ipairs(lst) do
      table.insert(xml, v)
   end
   return setmetatable(xml, self)
end

---@param index  string
---@param opts? { lax: boolean }
---@return XML?
function List:get(index, opts)
   opts = opts or {}

   local rv = {}
   for _,obj in ipairs(self) do
      if rawget(obj, 1) == index then
         table.insert(rv, rawget(obj, 2))
      end
   end

   if #rv == 0 then
      if opts.lax then
         return
      else
         error("Index '"..index.."' not found in "..tostring(self), 2)
      end
   elseif #rv == 1 then
      return rv[1]
   else
      return List:from(rv)
   end
end


---@param tag_name  string
---@param stack     XML[]
---@param acc       XML[]
---@return XML[] stack
local function pop_until(tag_name, stack, acc)
   assert(#stack > 0, "XML error, missing open tag for: " .. tag_name)

   local head = table.remove(stack)
   if head == tag_name then
      table.insert(stack, Object:new(tag_name, List:from(acc)))
      return stack
   else
      table.insert(acc, head)
      return pop_until(tag_name, stack, acc)
   end
end


---@param str    string
---@param pos    integer
---@param stack  XML[]
local function parse(str, pos, stack)
   local t, new_pos = scan(str, pos)

   if t.type == "EOF" then
      return stack

   elseif t.type == "TAG" then
      table.insert(stack, t.value)
      return parse(str, new_pos, stack)

   elseif t.type == "VALUE" then
      table.insert(stack, Object:new(table.remove(stack), t.value))
      return parse(str, new_pos, stack)

   elseif t.type == "CLOSE_TAG" then
      local val = t.value --[[@as string]]
      return parse(str, new_pos, pop_until(val, stack, List:new()))

   else
      print(vim.inspect(t))
      assert(false, "unreachable")
   end
end


---@param input string
---@return headers headers, XML data
return function(input)
   local offset, headers = header_parser(input)
   return headers, parse(input, offset, List:new())
end
