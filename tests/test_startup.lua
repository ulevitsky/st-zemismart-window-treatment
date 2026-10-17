package.path = './src/?.lua;' .. package.path
local test = require 'integration_test'
local caps = require 'st.capabilities'
local lifecycle = require 'st.device_lifecycle_dispatcher'
local legacy = require 'legacy'
local target = require 'zm15b'

-- Verify SDK lifecycle selection prevents the legacy reverse handler from
-- programming DP5 when the target's software-reversal preference changes.
local root = lifecycle('legacy', function() return true end, legacy.lifecycle_handlers)
root:register_child_dispatcher(lifecycle('ZM15B', target.can_handle, target.lifecycle_handlers))
local sent = {}
local dev = {preferences={controlProtocol='tuya',reverseApp=true,endpointAction='idle'}}
function dev:get_manufacturer() return '_TZE200_cirjrpxe' end
function dev:get_model() return 'TS0301' end
function dev:send(m) sent[#sent+1]=m end
root:dispatch({}, dev, 'infoChanged', {old_st_store={preferences={controlProtocol='tuya',reverseApp=false,endpointAction='idle'}}})
assert(#sent==0, 'target preference change leaked into legacy transport')

test.register_coroutine_test('Driver initializes using official SDK', function()
  test.wait_for_events()
end)
test.run_registered_tests()
