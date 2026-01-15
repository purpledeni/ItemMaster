local module = {}
local buffer

---encode base64
---@param str string
---@return string
function module.encode(str)
if buffer then buffer:close(); buffer = nil end
   buffer = data:createBuffer()
   buffer:writeByteArray(str)
   buffer:setPosition(0)
   local output = buffer:readBase64()
   buffer:close()
   buffer = nil
   return output
end

---decode base64
---@param str string
---@return string
function module.decode(str)
   if buffer then buffer:close(); buffer = nil end
   buffer = data:createBuffer()
   buffer:writeBase64(str)
   buffer:setPosition(0)
   local output = buffer:readByteArray()
   buffer:close()
   buffer = nil
   return output
end

return module