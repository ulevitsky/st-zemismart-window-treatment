-- Copyright 2026 Uri Levitsky. Apache-2.0.
local Driver = require "st.zigbee"
local template = require "legacy"
template.health_check = false
table.insert(template.supported_capabilities, require("st.capabilities").refresh)
template.sub_drivers = {require "zm15b"}
local function diagnostic(driver, device, rx)
  require("log").info("Unhandled Zigbee RX " .. tostring(rx))
end
template.zigbee_handlers.global = {
  [0xEF00] = {[0x0B] = diagnostic, [0x01] = diagnostic, [0x04] = diagnostic, [0x07] = diagnostic},
  [0x0102] = {[0x0B] = diagnostic, [0x01] = diagnostic, [0x04] = diagnostic, [0x07] = diagnostic}
}
template.zigbee_handlers.fallback = diagnostic
Driver("ulevitsky-zemismart-blinds", template):run()
