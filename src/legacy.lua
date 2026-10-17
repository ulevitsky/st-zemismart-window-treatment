-- Zemismart Window Treatment
-- Copyright 2024 Simeon Huang (librehat)
--
-- This edge driver is based on a more generic one from iquix's ST-Edge-Driver and code
-- from https://github.com/Koenkk/zigbee-herdsman-converters
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local window_preset_defaults = require "st.zigbee.defaults.windowShadePreset_defaults"
local log = require "log"

---------- Constant Definitions ----------

local CLUSTER_TUYA = 0xEF00
local DP_TYPE_VALUE = "\x02"
local DP_TYPE_ENUM = "\x04"


----------Device-specific Quirks-----------
local DEVICES_LEVEL_INVERTED_IN_REVERSE = {
  ["_TZE200_9p5xmj5r"] = true,
}

----------Tuya Utility Functions-----------

local send_tuya_command = require("tuya").send

------------Capabilities Handlers-----------

local function get_current_level(device)
  return device:get_latest_state("main", capabilities.windowShadeLevel.ID, capabilities.windowShadeLevel.shadeLevel.NAME)
end

local function get_current_battery(device)
  return device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.battery.NAME)
end

local function level_event_moving(device, level)
  local current_level = get_current_level(device)
  if current_level == nil or current_level == level then
    log.info("Ignore invalid reports")
    return false
  end

  if current_level < level then
    device:emit_event(capabilities.windowShade.windowShade.opening())
  elseif current_level > level then
    device:emit_event(capabilities.windowShade.windowShade.closing())
  end
  return true
end

local function level_event_arrived(device, level)
  if type(level) ~= "number" or (level < 0 or level > 100) then
    log.error("Invalid level", level)
    device:emit_event(capabilities.windowShade.windowShade.unknown())
    return
  end

  local window_shade_val
  if level == 0 then
    window_shade_val = "closed"
  elseif level == 100 then 
    window_shade_val = "open"
  else
    window_shade_val = "partially open"
  end
  device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
  device:emit_event(capabilities.windowShade.windowShade(window_shade_val))
end

local function window_shade_open_handler(driver, device)
  send_tuya_command(device, "\x01", DP_TYPE_ENUM, "\x00")
end

local function window_shade_pause_handler(driver, device)
  send_tuya_command(device, "\x01", DP_TYPE_ENUM, "\x01")
end

local function window_shade_close_handler(driver, device)
  send_tuya_command(device, "\x01", DP_TYPE_ENUM, "\x02")
end

local function window_shade_level_set_shade_level_handler(driver, device, command)
  send_tuya_command(device, "\x02", DP_TYPE_VALUE, string.pack(">I4", command.args.shadeLevel))
end

local function window_shade_preset_preset_position_handler(driver, device)
  local preset_level = device.preferences.presetPosition or device:get_field(window_preset_defaults.PRESET_LEVEL_KEY) or window_preset_defaults.PRESET_LEVEL
  window_shade_level_set_shade_level_handler(driver, device, {args = { shadeLevel = preset_level }})
end

------------Preferences Handlers------------

local function set_limit(device, is_set, direction)
  if (direction == "up" and device.preferences.reverse ~= true) or (direction == "down" and device.preferences.reverse == true) then
    -- set upper border/limit (upper becomes lower if 'reverse' is switched on)
    send_tuya_command(device, "\x10", DP_TYPE_ENUM, is_set and "\x00" or "\x02")
  else
    send_tuya_command(device, "\x10", DP_TYPE_ENUM, is_set and "\x01" or "\x03")
  end
end

------------Lifecycle Handlers--------------

local function device_added(driver, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({"open", "close", "pause"}))
end

local function device_init(driver, device)
  log.info("current level", get_current_level(device))
  log.info("current battery", get_current_battery(device))
end

local function device_info_changed(driver, device, event, args)
  local old = (args and args.old_st_store and args.old_st_store.preferences) or {}
  if old.reverse ~= nil and old.reverse ~= device.preferences.reverse then
    send_tuya_command(device, "\x05", DP_TYPE_ENUM, device.preferences.reverse and "\x01" or "\x00")
    local current_level = get_current_level(device)
    if current_level ~= nil then
      level_event_arrived(device, 100 - current_level)
    end
  end
  if old.limitUp ~= nil and old.limitUp ~= device.preferences.limitUp then
    set_limit(device, device.preferences.limitUp, "up")
  end
  if old.limitDown ~= nil and old.limitDown ~= device.preferences.limitDown then
    set_limit(device, device.preferences.limitDown, "down")
  end
end

-----------Tuya Cluster Functions-----------

local function tuya_cluster_handler(driver, device, zb_rx)
  local records, err = require("protocol").decode(zb_rx.body.zcl_body.body_bytes)
  if not records then log.warn("Malformed Tuya report: " .. err); return end
  for _, record in ipairs(records) do
  local dp, fncmd = record.dp, record.value
  log.debug(string.format("Tuya RX dp=0x%02X type=0x%02X raw=%s", dp, record.kind, require("protocol").hex(record.data)))
  if fncmd ~= nil then
  if dp == 1 then -- 0x01: Control -- open / pause / close
    -- fncmd: 0: open, 1: pause, 2: close
    if fncmd == 1 then
      device:emit_event(capabilities.windowShade.windowShade.paused())
    elseif fncmd == 0 then -- 100% in ST means fully open
      level_event_moving(device, 100)
    elseif fncmd == 2 then -- 0% in ST means fully closed
      level_event_moving(device, 0)
    end
  elseif dp == 2 then -- 0x02: Percent control -- Started moving to position (triggered from Zigbee)
    level_event_moving(device, fncmd)
  elseif dp == 3 then -- 0x03: Percent state -- Arrived at position
    if device.preferences.reverse and DEVICES_LEVEL_INVERTED_IN_REVERSE[device:get_manufacturer()] then
      fncmd = 100 - fncmd
    end
    level_event_arrived(device, fncmd)
  elseif dp == 5 then -- 0x05: Direction state
    log.info("direction state of the motor is "..(fncmd == 1 and "reverse" or "forward"))
  elseif dp == 12 then -- 0x0c: Motor fault
    log.error("motor fault, not implemented yet") -- TODO
  elseif dp == 13 then -- 0x0d: Battery level
    device:emit_event(capabilities.battery.battery(fncmd))
  elseif dp == 16 then -- 0x10: Border
    log.debug(string.format("border command=%d", fncmd))
  elseif dp == 20 then -- click control (single motor steps)
    log.debug("click control received, not implemented yet") -- TODO
  else
    log.warn(string.format("unhandled dp=%d, fncmd=%d", dp, fncmd))
  end
  end
  end
end

--------------Driver Main-------------------

local zemismart_window_treatment_driver = {
  supported_capabilities = {
    capabilities.windowShade,
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset,
    capabilities.battery,
  },
  zigbee_handlers = {
    cluster = {
      [CLUSTER_TUYA] = {
        [0x01] = tuya_cluster_handler,
        [0x02] = tuya_cluster_handler,
      }
    }
  },
  capability_handlers = {
    [capabilities.windowShade.ID] = {
      [capabilities.windowShade.commands.open.NAME] = window_shade_open_handler,
      [capabilities.windowShade.commands.pause.NAME] = window_shade_pause_handler,
      [capabilities.windowShade.commands.close.NAME] = window_shade_close_handler
    },
    [capabilities.windowShadeLevel.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_set_shade_level_handler
    },
    [capabilities.windowShadePreset.ID] = {
      [capabilities.windowShadePreset.commands.presetPosition.NAME] = window_shade_preset_preset_position_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    infoChanged = device_info_changed
  }
}

return zemismart_window_treatment_driver
