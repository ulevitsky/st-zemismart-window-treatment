-- Copyright 2026 Uri Levitsky. Apache-2.0.
-- Tuya frames: 16-bit transaction followed by one or more typed DP records.
local M = {}
function M.hex(s)
  return (s:gsub(".", function(c) return string.format("%02X", c:byte()) end))
end
function M.encode(sequence, dp, kind, data)
  assert(type(data) == "string" and #data <= 65535)
  return string.pack(">I2BBI2", sequence, dp, kind, #data) .. data
end
function M.decode(s)
  if type(s) ~= "string" or #s < 2 then return nil, "missing transaction" end
  local records, pos = {}, 3
  while pos <= #s do
    if #s - pos + 1 < 4 then return nil, "truncated DP header" end
    local dp, kind, length, next_pos = string.unpack(">BBI2", s, pos)
    if #s - next_pos + 1 < length then return nil, "truncated DP value" end
    local data = s:sub(next_pos, next_pos + length - 1)
    local value
    if ((kind == 1 or kind == 4) and length == 1) or
       ((kind == 2 or kind == 5) and length >= 1 and length <= 4) then
      value = 0
      for i = 1, length do value = value * 256 + data:byte(i) end
    end
    records[#records + 1] = {dp = dp, kind = kind, data = data, value = value}
    pos = next_pos + length
  end
  return records
end
return M
