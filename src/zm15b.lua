-- Copyright 2026 Uri Levitsky. Licensed under Apache-2.0.
-- Target-specific policy; Tuya wire commands follow iquix/librehat.
local caps = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local management = require "st.zigbee.device_management"
local read_attribute = require "st.zigbee.zcl.global_commands.read_attribute"
local zcl = require "st.zigbee.zcl"
local messages = require "st.zigbee.messages"
local types = require "st.zigbee.data_types"
local constants = require "st.zigbee.constants"
local protocol = require "protocol"
local tuya = require "tuya"
local log = require "log"
local WC, Basic = clusters.WindowCovering, clusters.Basic
local M = {NAME = "Zemismart ZM15B TS0301"}
function M.can_handle(opts, driver, device)
  return device:get_manufacturer() == "_TZE200_cirjrpxe" and device:get_model() == "TS0301"
end
local function standard(device) return device.preferences.controlProtocol == "standard" end
local function level(device)
  return device:get_latest_state("main", caps.windowShadeLevel.ID, caps.windowShadeLevel.shadeLevel.NAME)
end
local function invert(device)
  local flip = standard(device) -- Zigbee 0=open; SmartThings 100=open.
  if device.preferences.fixPercent == true then flip = not flip end
  if device.preferences.reverseApp == true then flip = not flip end
  return flip
end
local function convert(device, n) return invert(device) and 100 - n or n end
local function arrived(device, n)
  if type(n) ~= "number" or n < 0 or n > 100 then
    log.warn("Ignoring invalid/unavailable position " .. tostring(n)); return
  end
  device:emit_event(caps.windowShadeLevel.shadeLevel(n))
  device:emit_event(caps.windowShade.windowShade(n == 0 and "closed" or n == 100 and "open" or "partially open"))
end
local function moving(device, target)
  local current = level(device)
  if current ~= nil and current ~= target then
    device:emit_event(caps.windowShade.windowShade(current < target and "opening" or "closing"))
  end
end
local function refresh(driver, device)
  if standard(device) then
    device:send(WC.attributes.CurrentPositionLiftPercentage:read(device))
  else
    -- No speculative EF00 query: iquix uses reports rather than assuming query support.
    log.info("Tuya mode: awaiting position reports; no movement or calibration sent by refresh")
  end
end
local function cancel_jog(device)
  local timer = device:get_field("jog_timer")
  if timer then device.thread:cancel_timer(timer); device:set_field("jog_timer", nil) end
end
local function pause(driver, device)
  cancel_jog(device)
  if standard(device) then device:send(WC.server.commands.Stop(device))
  else tuya.send(device, 1, 4, "\x01") end
  -- Wait for position reports; a sent Stop is not proof the motor stopped.
end
local function action(driver, device, open)
  cancel_jog(device)
  local physical_open = open ~= (device.preferences.reverseApp == true)
  if standard(device) then
    device:send(physical_open and WC.server.commands.UpOrOpen(device) or WC.server.commands.DownOrClose(device))
  else tuya.send(device, 1, 4, physical_open and "\x00" or "\x02") end
  moving(device, open and 100 or 0)
  local seconds = device.preferences.jogSeconds or 0
  if seconds > 0 then
    device:set_field("jog_timer", device.thread:call_with_delay(seconds, function()
      device:set_field("jog_timer", nil)
      pause(driver, device)
    end))
  end
end
local function set_level(driver, device, command)
  local n = command.args.shadeLevel
  if type(n) ~= "number" or n < 0 or n > 100 or n % 1 ~= 0 then
    log.warn("Invalid requested percentage"); return
  end
  if (device.preferences.jogSeconds or 0) > 0 then
    log.warn("Percentage commands disabled while timed jog is enabled; use Open/Close and Stop")
    return
  end
  cancel_jog(device)
  local raw = convert(device, n)
  if standard(device) then device:send(WC.server.commands.GoToLiftPercentage(device, raw))
  else tuya.send(device, 2, 2, string.pack(">I4", raw)) end
  moving(device, n)
end
local function preset(driver, device)
  set_level(driver, device, {args = {shadeLevel = device.preferences.presetPosition or 50}})
end
local function report(driver, device, rx)
  local raw = rx.body.zcl_body.body_bytes
  log.info("EF00 RX " .. tostring(rx))
  local records, err = protocol.decode(raw)
  if not records then log.warn("Malformed Tuya report: " .. err); return end
  for _, r in ipairs(records) do
    log.info(string.format("RX dp=0x%02X type=0x%02X raw=%s value=%s", r.dp, r.kind, protocol.hex(r.data), tostring(r.value)))
    local v = r.value
    -- Log other protocol reports, but never let them overwrite the selected backend.
    if not standard(device) and v ~= nil then
      if r.dp == 1 and r.kind == 4 and v <= 2 then
        if v == 1 then device:emit_event(caps.windowShade.windowShade.paused())
        else
          local open = (v == 0) ~= (device.preferences.reverseApp == true)
          moving(device, open and 100 or 0)
        end
      elseif r.dp == 2 and r.kind == 2 and #r.data == 4 and v <= 100 then
        if device.preferences.positionReports == "dp2" then arrived(device, convert(device, v))
        else moving(device, convert(device, v)) end -- iquix: destination echo, not an arrival.
      elseif r.dp == 3 and r.kind == 2 and #r.data == 4 and v <= 100 then
        arrived(device, convert(device, v))
      elseif r.dp == 13 and v <= 100 then
        device:emit_event(caps.battery.battery(v))
      elseif r.dp == 107 and r.kind == 4 and v <= 2 then
        device:set_field("limit_status", v)
        log.info("DP107 limit status: " .. ({[0]="no limits", [1]="upper and lower", [2]="upper, lower and favorite"})[v])
      elseif r.dp == 119 and r.kind == 4 and v <= 3 then
        local result = ({[0]="delete success", [1]="delete failed", [2]="set success", [3]="set failed"})[v]
        log.warn("DP119 device reports " .. result .. "; pending=" .. tostring(device:get_field("limit_pending")) .. "; physical verification still required")
        device:set_field("limit_result", v)
        local timer = device:get_field("limit_timeout")
        if timer then device.thread:cancel_timer(timer) end
        device:set_field("limit_pending", nil)
        device:set_field("limit_timeout", nil)
      elseif r.dp == 16 then
        log.warn("DP16 observed but not mapped for cirjrpxe; no DP16 calibration writes are exposed")
      else log.info("Unmapped datapoint: retained in diagnostics only") end
    end
  end
end
local function position(driver, device, value, rx)
  log.info("0102 position RX " .. tostring(rx))
  if standard(device) and value.value <= 100 then arrived(device, convert(device, value.value)) end
end
local function battery(driver, device, value)
  if value.value <= 200 then device:emit_event(caps.battery.battery(math.floor(value.value / 2))) end
end
local function configure(driver, device)
  -- Proven iquix Basic bind and attribute sequence, with no auto-motion.
  device:send(management.build_bind_request(device, Basic.ID, driver.environment_info.hub_zigbee_eui))
  local header = zcl.ZclHeader({cmd = types.ZCLCommandId(read_attribute.ReadAttribute.ID)})
  device:send(messages.ZigbeeMessageTx({
    address_header = messages.AddressHeader(constants.HUB.ADDR, constants.HUB.ENDPOINT,
      device:get_short_address(), device:get_endpoint(Basic.ID), constants.HA_PROFILE_ID, Basic.ID),
    body = zcl.ZclMessageBody({zcl_header = header,
      zcl_body = read_attribute.ReadAttribute({0x0004, 0x0000, 0x0001, 0x0005, 0x0007, 0xFFFE})})
  }))
  if standard(device) then
    device:send(management.build_bind_request(device, WC.ID, driver.environment_info.hub_zigbee_eui))
    device:send(WC.attributes.CurrentPositionLiftPercentage:configure_reporting(device, 1, 600, 1))
    refresh(driver, device)
  end
end
local function init(driver, device)
  device:emit_event(caps.windowShade.supportedWindowShadeCommands({"open", "close", "pause"}))
  log.info("ZM15B backend=" .. (device.preferences.controlProtocol or "tuya") .. " device=" .. tostring(device))
end
-- Exact-fingerprint protocol facts from zemismart-dev/zigbee2mqtt zm25z.js.
-- DP118 enum: delete upper/lower=0/1, set upper/lower=3/4.
local limits = {setUpper = 3, setLower = 4, deleteUpper = 0, deleteLower = 1}
local function info_changed(driver, device, event, args)
  local old = (args and args.old_st_store and args.old_st_store.preferences) or {}
  if old.controlProtocol and old.controlProtocol ~= device.preferences.controlProtocol then
    -- Stop using the previous backend before cancelling its queued jog Stop.
    if old.controlProtocol == "standard" then device:send(WC.server.commands.Stop(device))
    else tuya.send(device, 1, 4, "\x01") end
    cancel_jog(device)
    device:emit_event(caps.windowShade.windowShade.unknown())
    configure(driver, device)
  end
  local selected = device.preferences.limitAction
  -- Defaults arriving on driver switch/init are not an instruction to calibrate.
  if not selected or selected == "idle" or selected == old.limitAction then return end
  if old.limitAction == nil then log.warn("Select Idle then the limit action to execute"); return end
  if device.preferences.enableCalibration ~= true then log.warn("Calibration blocked: enable limit calibration explicitly"); return end
  if old.controlProtocol ~= device.preferences.controlProtocol or old.reverseApp ~= device.preferences.reverseApp then
    log.warn("Change protocol/direction separately from calibration"); return
  end
  local value = limits[selected]
  if value == nil then return end
  if device:get_field("jog_timer") then log.warn("Stop the motor before setting a limit"); return end
  if device:get_field("limit_pending") then log.warn("Wait for the previous calibration result/timeout"); return end
  -- Never retry a limit write, never clear both limits, never claim it succeeded.
  log.warn("DP118 limit write: " .. selected .. "; verify DP119 result and physical behavior")
  device:set_field("limit_pending", selected)
  device:set_field("limit_timeout", device.thread:call_with_delay(15, function()
    log.warn("No DP119 result observed for " .. tostring(device:get_field("limit_pending")) .. "; do not assume success")
    device:set_field("limit_pending", nil)
    device:set_field("limit_timeout", nil)
  end))
  tuya.send(device, 118, 4, string.char(value))
end
M.capability_handlers = {
  [caps.windowShade.ID] = {
    [caps.windowShade.commands.open.NAME] = function(d, dev) action(d, dev, true) end,
    [caps.windowShade.commands.close.NAME] = function(d, dev) action(d, dev, false) end,
    [caps.windowShade.commands.pause.NAME] = pause
  },
  [caps.windowShadeLevel.ID] = {[caps.windowShadeLevel.commands.setShadeLevel.NAME] = set_level},
  [caps.windowShadePreset.ID] = {[caps.windowShadePreset.commands.presetPosition.NAME] = preset},
  [caps.refresh.ID] = {[caps.refresh.commands.refresh.NAME] = refresh}
}
M.zigbee_handlers = {
  cluster = {[0xEF00] = {[0x01] = report, [0x02] = report}},
  attr = {
    [WC.ID] = {[WC.attributes.CurrentPositionLiftPercentage.ID] = position},
    [clusters.PowerConfiguration.ID] = {[clusters.PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery}
  }
}
local function power_source(driver, device, value)
  if value.value == Basic.attributes.PowerSource.SINGLE_PHASE_MAINS then
    device:send(Basic.attributes.ApplicationVersion:configure_reporting(device, 30, 300, 1))
  end
end
M.zigbee_handlers.attr[Basic.ID] = {[Basic.attributes.PowerSource.ID] = power_source}
local function switched(driver, device)
  device:try_update_metadata({profile = "zm15b-blind", provisioning_state = "PROVISIONED"})
  init(driver, device)
  configure(driver, device)
end
M.lifecycle_handlers = {init = init, added = init, doConfigure = configure, infoChanged = info_changed, driverSwitched = switched}
return M
