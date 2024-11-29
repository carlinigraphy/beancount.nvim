-- vim: foldmethod=marker

---@param str string
---@return nil
local function warn(str)
   vim.api.nvim_echo({ {str, "WarningMsg"} }, true, {})
end


---@param before  string
---@param amount  number
---@param after?  string
local function justify_amount(before, amount, after)
   after = after or ""

   local float   = ("%.2f"):format(amount)
   local offset  = float:find("%.")
   local padding = 50 - #before - offset

   -- In case of a really long account name, don't want to end up concatenating
   -- with no spaces.
   if padding < 2 then padding = 2 end

   return ("%s%s%.2f%s"):format(
      before, (" "):rep(padding), amount, after)
end


--------------------------------------------------------------------------------
--| Dates
--------------------------------------------------------------------------------
--{{{

---@class Date
---@field year   integer
---@field month  integer
---@field day    integer
---@field hour   integer
---@field minute integer
---@field second integer
---@field ms     integer
---@field offset integer
---@field tz     string

local Date = {}
Date.__index = Date
Date.__tostring = function(self)
   return self:short()
end


---@param str    string
---@param pos    integer
---@param buffer string
---@return string timezone, integer string_position
local function parse_tz(str, pos, buffer)
   assert(pos <= #str)
   local char = str:sub(pos, pos)

   if char == "]" then
      return buffer, pos
   else
      return parse_tz(str, pos+1, buffer..char)
   end
end


---@param str    string
---@param pos    integer
---@param buffer string
---@return integer tz_offset, integer string_position
local function parse_offset(str, pos, buffer)
   assert(pos <= #str)
   local char = str:sub(pos, pos)

   if char == ":" then
      local number = tonumber(buffer) ; assert(number)
      return number, pos+1
   else
      return parse_offset(str, pos+1, buffer..char)
   end
end


---@param str  string   TZ string, example:  [-7:PST]
---@return integer string_position, string timezone
local function parse_date(str)
   local char = str:sub(1, 1)
   assert(char == "[")

   local offset, new_pos = parse_offset(str, 2, "")
   local tz    , end_pos = parse_tz(str, new_pos, "")

   assert(end_pos == #str)
   assert(str:sub(end_pos, end_pos) == "]")

   return offset, tz
end



---@param datestring string
---@return Date
function Date.new(datestring)
   -- TODO: if this breaks for whatever reason, write an actual date parsre,
   --    with user-provided template string. Only potentially necessary if
   --    different banks return the strings differently.

   -- Example:
   --20220619213828.108[-7:PDT]
   local formats = {
      { "year"  ,  1,  4 },
      { "month" ,  5,  6 },
      { "day"   ,  7,  8 },
      { "hour"  ,  9, 10 },
      { "minute", 11, 12 },
      { "second", 13, 14 },
      { "ms"    , 16, 18 },
   }

   local rv = {}
   for _,f in ipairs(formats) do
      rv[f[1]] = tonumber(datestring:sub(f[2], f[3]))
   end

   local offset, tz = parse_date(datestring:sub(19, #datestring))
   rv.offset = offset
   rv.tz = tz

   local reconstructed = string.format(
      "%d%02d%02d%02d%02d%02d.%03d[%d:%s]",
      rv.year   ,
      rv.month  ,
      rv.day    ,
      rv.hour   ,
      rv.minute ,
      rv.second ,
      rv.ms     ,
      rv.offset ,
      rv.tz     )

   assert(reconstructed == datestring, string.format(
      "\n%s\n%s\n", reconstructed, datestring))

   return setmetatable(rv, Date)
end


function Date:short()
   return string.format(
      "%d-%02d-%02d",
      self.year,
      self.month,
      self.day)
end
--}}}

--------------------------------------------------------------------------------
--| Directives
--------------------------------------------------------------------------------
--{{{

---@class Directive
---@field date      Date
---@field flag      string
---@field payee     string
---@field metadata  table<string, string>[]
---@field account   Account

---@class Account
---@field name string
---@field amount number
---@field commodity string

local function indent(times)
   return (" "):rep(times * 2)
end


local Directive = {}
Directive.__index = Directive

---@param self Directive
Directive.__tostring = function(self)
   return table.concat(self:to_lines(), "\n")
end


function Directive:to_lines()
   -- Example:
   -- 2014-06-28 * "Paid credit card bill"
   local directive_1 = string.format(
      "%s %s %q",
      self.date:short(),
      self.flag,
      self.payee)

   local directive_2 = string.format(
      "%smemo: %q", indent(2), self.metadata.memo)

   -- Example:
   -- Assets:CA:BofA:Checking  -700.00 USD
   local directive_3 = justify_amount(
      indent(1) .. self.account.name,
      self.account.amount,
      " " .. self.account.commodity)

   return {
      directive_1,
      directive_2,
      directive_3,
   }
end


---@param trn        List
---@param acc_name   string
---@param commodity  string
function Directive.new(trn, acc_name, commodity)
   return setmetatable({
      date     = Date.new(trn:get("DTPOSTED")),
      flag     = "!",
      payee    = trn:get("NAME"),
      metadata = {
         memo = trn:get("MEMO", {lax = true})
      },
      account = {
         name      = acc_name,
         amount    = trn:get("TRNAMT"),
         commodity = commodity,
      },
   }, Directive)
end
--}}}

--------------------------------------------------------------------------------
--| Statement
--------------------------------------------------------------------------------
--{{{

---@class Statement
---@field date          Date
---@field balance       number
---@field transactions  Directive[]
---@field commodity     string
---@field account       string

local Statement = {}
Statement.__index = Statement

---@param self Statement
---@return string
Statement.__tostring = function(self)
   local rv = {}
   for _,tns in ipairs(self.transactions) do
      table.insert(rv, tostring(tns))
   end

   table.insert(rv, justify_amount(
      tostring(self.date) .. " " .. self.account,
      self.balance))

   return table.concat(rv, "\n\n")
end


local function validate_headers(headers)
   -- TODO(config): set assertions in config.
   --    This is another thing that may need to be in a config for a specific
   --    importer. A lot of this plugin must be made more generic such that it
   --    can be re-used for other import sources.
   for _,assertion in ipairs({
      --{ "OFXHEADER"    , 100  },
      --{ "SGMLVERSION"  , 102  },
      --{ "ENCODING"     , "US" },
      --{ "ASCIICHARSET" , 1252 }
   }) do
      local key = assertion[1]
      local val = assertion[2]

      if not headers[key] then
         warn(string.format("Header missing %q", key))
      else
         assert(headers[key] == val, string.format(
            "Header '%s' mismatch '%s' != '%s'",
            key, headers[key], val
         ))
      end
   end
end


---@param headers  table<string, string|integer>
---@param data     XML
---@param account? string
---@return Statement
function Statement.new(headers, data, account)
   validate_headers(headers)

   local statement = data
      :get("OFX")
      :get("BANKMSGSRSV1")
      :get("STMTTRNRS")
      :get("STMTRS")


   -- TODO(config) use import-specific config to switch on account ID
   --[[
   local acc_type = statement
      :get("BANKACCTFROM")
      :get("ACCTTYPE")
   --]]
   if account == "" then
      account = "Assets:TODO"
   end

   local date = Date.new(statement
      :get("LEDGERBAL")
      :get("DTASOF"))

   local commodity = statement:get("CURDEF")
   local balance = statement
      :get("LEDGERBAL")
      :get("BALAMT")

   local transactions = {}
   for _,tns in ipairs(
      statement
      :get("BANKTRANLIST")
      :get("STMTTRN"))
   do
      table.insert(transactions, Directive.new(tns, account, commodity))
   end

   return setmetatable({
      account       = account,
      balance       = balance,
      commodity     = commodity,
      date          = date,
      transactions  = transactions,
   }, Statement)
end


---@return string[]
function Statement:to_lines()
   local rows = {}

   for _,tns in ipairs(self.transactions) do
      for _,drv in ipairs(tns:to_lines()) do
         table.insert(rows, drv)
      end
      table.insert(rows, "")
   end

   table.insert(rows, justify_amount(
      self.date:short() .. " balance " .. self.account,
      self.balance))

   -- Adds nice comment line after balance assertion.
   table.insert(rows, ";" .. string.rep("-", 79))

   return rows
end
--}}}

return {
   date      = Date.new,
   directive = Directive.new,
   statement = Statement.new,
}
