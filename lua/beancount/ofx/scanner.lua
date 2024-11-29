---@alias token { type: token_t, value: string | integer }

---@alias token_t
---| "TAG"
---| "CLOSE_TAG"
---| "VALUE"
---| "EOF"

--- Wrapping in a function to make easier to change later. Don't need to hunt
--- down all the instances of something returning a token-like object.
---
---@param type   token_t
---@param value  string | integer
---@return token
local function new_token(type, value)
   return { type = type, value = value }
end


---@param str     string
---@param pos     integer
---@param buffer  string
---@param type    token_t
---@return token, integer
local function _scan_tag(str, pos, type, buffer)
   local char = str:sub(pos, pos)
   if char == ">" then
      return new_token(type, buffer), pos+1
   else
      return _scan_tag(str, pos+1, type, buffer .. char)
   end
end


---@param str  string
---@param pos  integer
---@return token, integer
local function scan_tag(str, pos)
   local char = str:sub(pos, pos)
   if char == '/' then
      return _scan_tag(str, pos+1, "CLOSE_TAG", "")
   else
      return _scan_tag(str, pos+1, "TAG", char)
   end
end


---@param str   string
---@param pos?  integer  Set by function, or explicitly pass: `1`.
---@param acc?  integer  Set by function, or explicitly pass: `1`.
---@return string
local function rstrip(str, pos, acc)
   pos = pos or 1
   acc = acc or 1

   local char = str:sub(pos, pos)

   if pos > #str then
      return str:sub(1, acc)
   elseif (char == " ") or (char == "\t") or (char == "\n") then
      return rstrip(str, pos+1, acc)
   else
      return rstrip(str, pos+1, pos)
   end
end


---@param str     string
---@param pos     integer
---@param buffer  string
---@return token, integer
local function scan_value(str, pos, buffer)
   local char = str:sub(pos, pos)

   if (char == "") or (char == '<') then
      local value = rstrip(buffer)
      local maybe_num = tonumber(value) or value
      return new_token("VALUE", maybe_num), pos
   else
      return scan_value(str, pos+1, buffer .. char)
   end
end


---@param str  string
---@param pos  integer
---@return token token, integer position
local function scan(str, pos)
   if pos > #str then
      return new_token("EOF", ""), pos
   end

   local char = str:sub(pos, pos)
   if char == "<" then
      return scan_tag(str, pos+1)
   elseif (char == " ") or (char == "\t") or (char == "\n") then
      return scan(str, pos+1)
   else
      return scan_value(str, pos+1, char)
   end
end


return scan
