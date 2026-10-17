-- Run from repository root with the official Edge SDK on LUA_PATH.
package.path = './src/?.lua;' .. package.path
require "integration_test" -- SDK mocks install the hub environment.
local caps = require "st.capabilities"
local P = require "protocol"
local Z = require "zm15b"
local legacy = require "legacy"
local sent, events, timers, fields, latest
local driver={environment_info={hub_zigbee_eui="76543210"}}
local count = 0
local function check(value, message)
  count = count + 1
  assert(value, message or ('check ' .. count .. ' failed'))
end
local function device(prefs)
  sent, events, timers, fields, latest = {}, {}, {}, {}, nil
  local d = {zigbee_eui='01234567', fingerprinted_endpoint_id=1, preferences = prefs or {controlProtocol='tuya', limitAction='idle', reverseApp=false},
    thread = {call_with_delay=function(_, seconds, fn) timers[#timers+1]=fn; return #timers end,
      cancel_timer=function(_, id) timers[id]=false end}}
  function d:try_update_metadata(m) self.metadata=m end
  function d:get_manufacturer() return '_TZE200_cirjrpxe' end
  function d:get_model() return 'TS0301' end
  function d:get_short_address() return 0x1234 end
  function d:get_endpoint(cluster) return 1 end
  function d:get_field(key) return fields[key] end
  function d:set_field(key, value) fields[key]=value end
  function d:get_latest_state() return latest end
  function d:emit_event(e) events[#events+1]=e end
  function d:send(m) sent[#sent+1]=m; m:_serialize() end -- Real SDK serialization.
  return d
end
local function command(d, capability, name, args)
  Z.capability_handlers[capability][name]({}, d, {args=args or {}, component='main'})
end
local function payload(m) return m.body.zcl_body.body_bytes end
local function dp(m)
  local records = assert(P.decode(payload(m)))
  return records[1]
end
local function update(d, old)
  Z.lifecycle_handlers.infoChanged({environment_info={hub_zigbee_eui="76543210"}}, d, nil, {old_st_store={preferences=old}})
end
local function rx(d, raw)
  Z.zigbee_handlers.cluster[0xEF00][2]({}, d, {body={zcl_body={body_bytes=raw}}})
end
check(P.hex(P.encode(1,16,4,'\0')) == '00011004000100', 'DP16 wire fixture')
local raw = P.encode(0x1234,3,2,string.pack('>I4',73)) .. '\x0D\x02\x00\x04\0\0\0\x5A'
local records = assert(P.decode(raw))
check(#records==2 and records[1].value==73 and records[2].value==90, 'multi-DP report')
for _, malformed in ipairs({'', '\0', '\0\1\2', '\0\1\2\2\0\4\0'}) do
 check(P.decode(malformed)==nil, 'reject truncated frame')
end
check(assert(P.decode('\0\1\x22\3\0\0'))[1].value==nil, 'empty string DP')
check(assert(P.decode('\0\1\x22\0\0\x0A0123456789'))[1].value==nil, 'long raw DP')
local d = device()
check(Z.can_handle(nil,nil,d))
check(not Z.can_handle(nil,nil,{get_manufacturer=function() return '_TZE200_9p5xmj5r' end,get_model=function() return 'TS0601' end}), 'legacy isolation')
Z.lifecycle_handlers.init({},d)
check(#sent==0, 'init must not send motion/calibration')
Z.lifecycle_handlers.added({},d)
check(#sent==0, 'added must not move')
Z.lifecycle_handlers.doConfigure(driver,d)
check(#sent==2 and sent[1].address_header.cluster.value==0x21 and sent[2].address_header.cluster.value==0, 'Basic bind and read-only handshake')
check(P.hex(sent[2].body.zcl_body:_serialize())=='04000000010005000700FEFF', 'iquix magic attribute order')
sent={}
for _, spec in ipairs({{'open',0},{'pause',1},{'close',2}}) do
 command(d,'windowShade',spec[1])
 local r=dp(sent[#sent]); check(r.dp==1 and r.kind==4 and r.value==spec[2], 'iquix command fixture '..spec[1])
end
command(d,'windowShadeLevel','setShadeLevel',{shadeLevel=37})
check(dp(sent[#sent]).dp==2 and dp(sent[#sent]).value==37, 'percentage fixture')
local before=#sent
command(d,'windowShadeLevel','setShadeLevel',{shadeLevel=101})
check(#sent==before, 'invalid command blocked')
events={}
rx(d, raw)
check(#events==3 and events[1].value.value==73 and events[3].value.value==90, 'multi DP state emission')
events={}; rx(d, '\0\1\3\2\0\4\0')
check(#events==0, 'malformed RX does not crash or emit')
rx(d,P.encode(1,2,2,string.pack('>I4',44)))
check(#events==0, 'destination echo must not invent arrival')
local old={controlProtocol='tuya',limitAction='idle',reverseApp=false}
for _,m in ipairs(sent) do check(m.address_header.cluster.value~=0xEF00 or dp(m).dp~=16, 'target never sends DP16') end
d.preferences.limitAction='setUpper'; update(d,old)
check(#sent==before, 'calibration disabled by default')
d.preferences.enableCalibration=true
update(d,{})
check(#sent==before, 'no initial preference calibration')
update(d,old)
check(dp(sent[#sent]).dp==118 and dp(sent[#sent]).kind==4 and dp(sent[#sent]).value==3, 'upper limit explicit write')
before=#sent; update(d,{limitAction='setUpper'})
check(#sent==before, 'no replay of selected action')
for action,value in pairs({setLower=4,deleteUpper=0,deleteLower=1}) do
 rx(d,P.encode(1,119,4,'\x02'))
 d.preferences.limitAction=action; update(d,old)
 check(dp(sent[#sent]).value==value, action)
end
before=#sent; d.preferences.limitAction='setUpper'; d.preferences.controlProtocol='standard'
-- Mixed protocol/calibration change must not write limits.
update(d,old)
for i=before+1,#sent do check(sent[i].address_header.cluster.value~=0xEF00 or dp(sent[i]).dp~=118, 'no calibration with protocol change') end
local d2=device({controlProtocol='standard',limitAction='idle',reverseApp=false})
command(d2,'windowShade','open'); check(sent[1].body.zcl_header.cmd.value==0 and sent[1].address_header.cluster.value==0x102)
command(d2,'windowShade','close'); check(sent[2].body.zcl_header.cmd.value==1)
command(d2,'windowShade','pause'); check(sent[3].body.zcl_header.cmd.value==2)
command(d2,'windowShadeLevel','setShadeLevel',{shadeLevel=37})
check(sent[4].body.zcl_header.cmd.value==5 and P.hex(sent[4].body.zcl_body:_serialize())=='3F', 'standard 100-percent conversion')
Z.zigbee_handlers.attr[0x102][8]({},d2,{value=0},{})
check(events[#events].value.value=='open')
Z.zigbee_handlers.attr[0x102][8]({},d2,{value=255},{})
check(events[#events].value.value=='open', 'unknown Zigbee percentage ignored')
local jog=device({controlProtocol='tuya',jogSeconds=1})
command(jog,'windowShade','open'); check(#sent==1 and #timers==1)
command(jog,'windowShadeLevel','setShadeLevel',{shadeLevel=50})
check(type(timers[1])=='function', 'refused percentage preserves queued Stop')
timers[1](); check(dp(sent[2]).value==1, 'timed jog stop')
command(jog,'windowShadeLevel','setShadeLevel',{shadeLevel=50})
check(#sent==2, 'percentage cannot bypass jog')
local rev=device({controlProtocol='tuya',reverseApp=true,fixPercent=false})
command(rev,'windowShade','open'); check(dp(sent[1]).value==2)
command(rev,'windowShadeLevel','setShadeLevel',{shadeLevel=25}); check(dp(sent[2]).value==75)
local l=device({reverse=false,limitUp=false,limitDown=false})
legacy.lifecycle_handlers.infoChanged({},l,nil,{})
check(#sent==0,'legacy defaults must not clear limits')
l.preferences.limitUp=true
legacy.lifecycle_handlers.infoChanged({},l,nil,{old_st_store={preferences={reverse=false,limitUp=false,limitDown=false}}})
check(dp(sent[1]).dp==16 and dp(sent[1]).value==0,'legacy calibration preserved')
local migrated=device()
Z.lifecycle_handlers.driverSwitched(driver,migrated)
check(migrated.metadata.profile=='zm15b-blind' and #sent==2 and sent[1].address_header.cluster.value==0x21 and sent[2].address_header.cluster.value==0, 'migration changes profile, binds and reads Basic')
local timeout_device=device({controlProtocol='tuya',limitAction='setUpper',enableCalibration=true,reverseApp=false})
update(timeout_device,{controlProtocol='tuya',limitAction='idle',reverseApp=false})
check(fields.limit_pending=='setUpper')
local before_timeout=#sent
timeout_device.preferences.limitAction='setLower'
update(timeout_device,{controlProtocol='tuya',limitAction='idle',reverseApp=false})
check(#sent==before_timeout,'pending limit blocks another write')
timers[#timers]()
check(fields.limit_pending==nil and #sent==before_timeout,'timeout clears pending without retry')
local typed=device()
rx(typed,P.encode(1,3,4,'\x32'))
check(#events==0,'wrong position datatype ignored')
rx(typed,P.encode(1,107,4,'\x01') .. '\x77\x04\x00\x01\x03')
check(fields.limit_status==1 and fields.limit_result==3,'limit status and failure parsed')
local variant=device({controlProtocol='tuya',positionReports='dp2'})
rx(variant,P.encode(1,2,2,string.pack('>I4',42)))
check(events[1].value.value==42,'explicit DP2 report variant')
local flags=device()
command(flags,'windowShade','open')
check(sent[1].body.zcl_header.frame_ctrl:is_disable_default_response_set(),'iquix frame flags')
flags.preferences.requestResponses=true
command(flags,'windowShade','pause')
check(not sent[2].body.zcl_header.frame_ctrl:is_disable_default_response_set(),'diagnostic default response option')
print('Passed '..count..' SDK-backed checks')
