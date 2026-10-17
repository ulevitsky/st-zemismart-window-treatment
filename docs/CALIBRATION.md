# Supervised travel-limit testing

The controls operate through SmartThings; no remote or Tuya hub is required by the software. Physical success on this ZM15B remains to be demonstrated. The exact-fingerprint converter is labeled **ZM25Z**, so first confirm response behavior on this motor rather than assuming that retail model names imply identical firmware.

## Establish reliable Stop first

1. Record the current driver/settings and whether existing limits already stop travel. Pause routines that could move the blind. Clear the travel path, stay with the motor, and keep its power disconnect accessible.
2. Switch to the new driver while stopped. Keep **Control protocol = Tuya EF00 (iquix)**, **Enable limit calibration = off**, and **Endpoint action = Idle**. No limit is cleared by these defaults.
3. Set **Timed jog seconds = 1**. Briefly test Open, then Close, well away from an endpoint. Each queues a Stop after one second. Also test manual Stop. A Zigbee Stop or driver timer is not a mechanical safety interlock; loss of radio, power or driver execution can prevent it.
4. Confirm actual direction. If required, stop first and change **Reverse app direction**. This is software reversal; it does not write motor DP5. Use a separate save from any calibration action.
5. Start logcat. Check DP3 position reports. If percentage is reversed, stop and change **Invert percentage**, then check both commanded/reported percentages. **Position report datapoint = DP2** is only for logs proving DP2 carries actual position; it may otherwise be a destination echo.
6. Only if Tuya control fails, stop first and select **Zigbee 0102**, then repeat the jog/Stop checks. There is no automatic fallback that could double-send movement. Standard mode does not establish support for Tuya calibration.

**If Stop fails, stop testing and disconnect power. Do not delete limits to diagnose communications.**

## Set one endpoint at a time

The target uses `EF00 / command 00 / DP118 / enum`, based on the exact fingerprint. DP16 is deliberately unavailable for this motor.

The **Open endpoint** is where the app's Open command should stop; the **Closed endpoint** is where Close should stop. Both setting and deleting follow **Reverse app direction**:

| Endpoint action | Reversal off: DP118 | Reversal on: DP118 | Expected DP119 |
| --- | ---: | ---: | --- |
| Set open endpoint here | 3 | 4 | 2 = set success |
| Set closed endpoint here | 4 | 3 | 2 = set success |
| Delete open endpoint | 0 | 1 | 0 = delete success |
| Delete closed endpoint | 1 | 0 | 0 = delete success |

**Invert percentage** does not change this mapping. The motor still stores its two native limits; toggling app reversal changes how app actions refer to them and does not rewrite either limit. Set the desired app direction before calibration.

DP119 values 1/3 mean delete/set failure. DP107 values 0/1/2 mean no limits / upper+lower / upper+lower+favorite in the motor's native protocol. These are device reports, not independent physical measurements.

When upgrading from v0.1.0-test1, reopen Settings and save **Endpoint action = Idle** before choosing a new action. The old Physical limit action preference is no longer used; its stored selection cannot trigger a calibration write. Saved motor limits remain intact and need no recalibration solely because of this update.

1. Keep one-second jog enabled. Move a small distance at a time to the desired open endpoint, leaving a conservative margin from any mechanical hard stop. Send Stop and wait for physical motion to cease.
2. Enable **Enable limit calibration**, with action still Idle, and save. Save Idle before every subsequent action so repeat selections produce an intentional change.
3. Select **Set open endpoint here** and save once. The driver uses the mapping above for the selected app direction. Do not change protocol/direction in the same save. No writes occur from initial preference population or restart.
4. Observe the log for DP119. The driver blocks another limit write while awaiting a result and releases that block after 15 seconds with a warning; it never retries. A timeout, echo, or wrong-kind result is not success. If the result is missing or failure is reported, stop and retain the logs instead of trying other datapoints.
5. If the result reports success, return the action to Idle. Move a short distance away, then approach the new endpoint under supervision using short jogs. Verify that the motor respects it. Do not test by driving into a hard stop.
6. Repeat for the closed endpoint, with the same margins and stop-before-save procedure.
7. After both are physically verified, disable calibration and set action Idle. Set jog seconds to 0, then test small percentage changes (for example 45→50→55) and Stop. Verify 0/100 only after intermediate positioning works and both limits have been confirmed.
8. Repeat endpoint checks after a motor power cycle to establish persistence. Record behavior, reports and firmware before calling the installation accepted.

## If an existing endpoint prevents adjustment

First try setting the new endpoint without deletion. If the motor rejects it and deletion is necessary, delete only the endpoint being adjusted, then use supervised jogs to reposition and set it again. Deletion removes a travel safeguard. The driver offers no delete-both action and sends no automatic full-travel calibration cycle. Middle/favorite limits are outside this release's scope.

## Acceptance record

Save the package version, firmware, endpoint/cluster list, protocol, direction/percentage preferences, successful short jog+Stop, actual percentage reports, each DP118 request/DP119 result, physical endpoint behavior, and persistence after power cycle. Include failures and missing responses. Reliable calibration is not claimed until these hardware checks pass.
