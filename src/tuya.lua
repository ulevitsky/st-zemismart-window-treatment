-- Tuya transport adapted from librehat (2024) and iquix (2021-2026).
-- Licensed under Apache-2.0; original notices retained in legacy.lua / NOTICE.
local zcl = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local types = require "st.zigbee.data_types"
local constants = require "st.zigbee.constants"
local generic = require "st.zigbee.generic_body"
local protocol = require "protocol"
local log = require "log"
local M = {}
function M.send(device, dp, kind, data)
  if type(dp) == "string" then dp = dp:byte() end
  if type(kind) == "string" then kind = kind:byte() end
  local seq = ((device:get_field("tuya_sequence") or 0) + 1) % 65536
  device:set_field("tuya_sequence", seq)
  local header = zcl.ZclHeader({cmd = types.ZCLCommandId(0x00)})
  header.frame_ctrl:set_cluster_specific()
  -- iquix suppresses default responses. Preserve that target behavior by default.
  if device:get_manufacturer() == "_TZE200_cirjrpxe" and device:get_model() == "TS0301"
      and device.preferences.requestResponses ~= true then
    header.frame_ctrl:set_disable_default_response()
  end
  local endpoint = device:get_endpoint(0xEF00)
  log.info(string.format("TX EF00 ep=%s seq=%d dp=0x%02X type=0x%02X raw=%s", tostring(endpoint), seq, dp, kind, protocol.hex(data)))
  device:send(messages.ZigbeeMessageTx({
    address_header = messages.AddressHeader(constants.HUB.ADDR, constants.HUB.ENDPOINT,
      device:get_short_address(), endpoint, constants.HA_PROFILE_ID, 0xEF00),
    body = zcl.ZclMessageBody({zcl_header = header,
      zcl_body = generic.GenericBody(protocol.encode(seq, dp, kind, data))})
  }))
end
return M
