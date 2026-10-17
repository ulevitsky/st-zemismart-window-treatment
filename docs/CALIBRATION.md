# Supervised travel-limit testing

The controls operate through SmartThings; no remote or Tuya hub is required by the software. Physical success on this ZM15B remains to be demonstrated. The exact-fingerprint converter is labeled **ZM25Z**, so first confirm response behavior on this motor rather than assuming that retail model names imply identical firmware.

## Establish reliable Stop first

1. Record the current driver/settings and whether existing limits already stop travel. Pause routines that could move the blind. Clear the travel path, stay with the motor, and keep its power disconnect accessible.
2. Switch to the new driver while stopped. Keep **Control protocol = Tuya EF00 (iquix)**, **Enable limit calibration = off**, and **Physical limit action = Idle**. No limit is cleared by these defaults.
3. Set **Timed jog seconds = 1**. Briefly test Open, then Close, well away from an endpoint. Each queues a Stop after one second. Also test manual Stop. A Zigbee Stop or driver timer is not a mechanical safety interlock; loss of radio, power or driver execution can prevent it.
4. Confirm actual direction. If required, stop first and change **Reverse app direction**. This is software reversal; it does not write motor DP5. Use a separate save from any calibration action.
5. Start logcat. Check DP3 position reports. If percentage is reversed, stop and change **Invert percentage**, then check both commanded/reported percentages. **Position report datapoint = DP2** is only for logs proving DP2 carries actual position; it may otherwise be a destination echo.
6. Only if Tuya control fails, stop first and select **Zigbee 0102**, then repeat the jog/Stop checks. There is no automatic fallback that could double-send movement. Standard mode does not establish support for Tuya calibration.

**If Stop fails, stop testing and disconnect power. Do not delete limits to diagnose communications.**

## Set one endpoint at a time

The target uses `EF00 / command 00 / DP118 / enum`, based on the exact fingerprint. DP16 is deliberately unavailable for this motor.

| Action | DP118 value | Expected DP119 result |
| --- | ---: | --- |
| Set upper limit at current position | 3 | 2 = set success |
| Set lower limit at current position | 4 | 2 = set success |
| Delete upper limit | 0 | 0 = delete success |
| Delete lower limit | 1 | 0 = delete success |

DP119 values 1/3 mean delete/set failure. DP107 values 0/1/2 mean no limits / upper+lower / upper+lower+favorite. These are device reports, not independent physical measurements. Upper/lower calibration names follow the motor's protocol and do not swap when software app reversal is enabled.

1. Keep one-second jog enabled. Move a small distance at a time to the desired upper endpoint, leaving a conservative margin from any mechanical hard stop. Send Stop and wait for physical motion to cease.
2. Enable **Enable limit calibration**, with action still Idle, and save. Save Idle before every subsequent action so repeat selections produce an intentional change.
3. Select **Set upper limit here** and save once. The driver sends `DP118 enum 3`. Do not change protocol/direction in the same save. No writes occur from initial preference population or restart.
4. Observe the log for DP119. The driver blocks another limit write while awaiting a result and releases that block after 15 seconds with a warning; it never retries. A timeout, echo, or wrong-kind result is not success. If the result is missing or failure is reported, stop and retain the logs instead of trying other datapoints.
5. If the result reports success, return the action to Idle. Move a short distance away, then approach the new endpoint under supervision using short jogs. Verify that the motor respects it. Do not test by driving into a hard stop.
6. Repeat for the lower endpoint, with the same margins and stop-before-save procedure.
7. After both are physically verified, disable calibration and set action Idle. Set jog seconds to 0, then test small percentage changes (for example 45→50→55) and Stop. Verify 0/100 only after intermediate positioning works and both limits have been confirmed.
8. Repeat endpoint checks after a motor power cycle to establish persistence. Record behavior, reports and firmware before calling the installation accepted.

## If an existing endpoint prevents adjustment

First try setting the new endpoint without deletion. If the motor rejects it and deletion is necessary, delete only the endpoint being adjusted, then use supervised jogs to reposition and set it again. Deletion removes a travel safeguard. The driver offers no delete-both action and sends no automatic full-travel calibration cycle. Middle/favorite limits are outside this release's scope.

## Acceptance record

Save the package version, firmware, endpoint/cluster list, protocol, direction/percentage preferences, successful short jog+Stop, actual percentage reports, each DP118 request/DP119 result, physical endpoint behavior, and persistence after power cycle. Include failures and missing responses. Reliable calibration is not claimed until these hardware checks pass.
