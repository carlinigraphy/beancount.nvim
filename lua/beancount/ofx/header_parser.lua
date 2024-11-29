---@alias headers table<string, integer|string>

--[[ Example headers:
ASCIICHARSET:1252
COMPRESSION:NONE
DATA:OFX
ENCODING:US
NEWFILEUID:NONE
OFXHEADER:100
OLDFILEUID:NONE
SECURITY:NONE
SGMLVERSION:102
--]]

local RULES = {
   A = "SCIICHARSET",
   C = "OMPRESSION",
   D = "ATA",
   E = "NCODING",
   N = "EWFILEUID",
   O = {
      F = "XHEADER",
      L = "DFILEUID",
   },
   S = {
      E = "CURITY",
      G = "MLVERSION",
   }
}


---@param str  string
---@param pos  integer
---@return integer position
local function header_offset(str, pos)
   local char = str:sub(pos, pos)

   if char == "" then
      assert(false, "unreachable")
   elseif char == "<" then
      return pos
   else
      return header_offset(str, pos+1)
      ---@diagnostic disable-next-line: missing-return
   end
end


---@param str      string
---@param str_pos  integer
---@param test     string
---@param test_pos integer
---@return boolean
local function string_match(str, str_pos, test, test_pos)
   local c1 = str:sub(str_pos, str_pos)
   local c2 = test:sub(test_pos, test_pos)

   -- Successfully reached end of test string.
   if test_pos > #test then
      return true

   -- No match before hitting end of input string.
   elseif str_pos > #str then
      return false

   -- Successful character match.
   elseif c1 == c2 then
      return string_match(str, str_pos+1, test, test_pos+1)

   -- Unsuccessful character match.
   else
      return false
   end
end


--- This needs backtracking!


---@param str    string
---@param rules  table
---@param pos    integer
---@param acc    integer
local function find_start(str, rules, pos, acc)
   local char = str:sub(pos, pos)
   local rule = rules[char]


   if char == "" then
      return nil

   elseif not rule then
      return find_start(str, RULES, acc+1, acc+1)

   elseif type(rule) == "table" then
      return find_start(str, rule, pos+1, acc)

   elseif type(rule) == "string" then
      if string_match(str, pos+1, rule, 1) then
         return acc
      else
         return find_start(str, rules, acc+1, acc+1)
      end

   else
      assert(false, "Unreachable: no other type of data possible.")
   end
end


---@param str     string
---@param pos     integer
---@param max     integer
---@param buffer  string
---@param acc     string[]
---@return string[]
local function split(str, pos, max, buffer, acc)
   local char = str:sub(pos, pos)

   if pos > max then
      table.insert(acc, buffer)
      return acc
   elseif char == ":" then
      table.insert(acc, buffer)
      return split(str, pos+1, max, "", acc)
   else
      return split(str, pos+1, max, buffer..char, acc)
   end
end


---@param lst table
---@param acc string[]
local function split_again(lst, acc)
   if #lst == 0 then
      return acc
   end

   local str = table.remove(lst)
   local header_pos = find_start(str, RULES, 1, 1)

   if header_pos then
      local s1 = str:sub(1, header_pos-1)
      local s2 = str:sub(header_pos, #str)

      if #s2 > 0 then table.insert(acc, s2) end
      if #s1 > 0 then table.insert(acc, s1) end
   else
      table.insert(acc, str)
   end

   return split_again(lst, acc)
end


---@param lst  string[]
---@param acc  string[]
---@return headers
local function join_pair(lst, acc)
   if #lst == 0 then
      return acc
   end

   local key = table.remove(lst)
   local val = table.remove(lst)

   acc[key] = tonumber(val) or val
   return join_pair(lst, acc)
end


---@param str  string
---@return integer header_offset, headers headers
return function(str)
   local offset = header_offset(str, 1)
   return offset, join_pair(
      split_again(
         split(str, 1, offset, "", {}),
         {}),
      {})
end
