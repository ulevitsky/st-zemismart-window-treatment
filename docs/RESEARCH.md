# Evidence and architecture decision — 2026-10-17

## Decision

Fork librehat for continuity, but use an **exact-fingerprint subdriver** for `TS0301 / _TZE200_cirjrpxe`. Reuse iquix's proven Tuya command framing and Basic initialization, use the exact-fingerprint Zemismart DP118 limit map, and retain an explicitly selected standard-Zigbee backend using the official SDK. Keep librehat's six original TS0601 devices and DP16 calibration separate. Do not use model-only TS0301 matching or automatic fallback between movement protocols.

The user's successful iquix operation is direct hardware evidence for that motor's basic EF00 control. The stock driver's previous success suggests standard control may also be available, but does not establish current firmware behavior. The published exact-fingerprint converter provides stronger calibration evidence than similar devices' DP16 mappings. **No source research or software test proves physical acceptance on this individual motor.**

## Compared implementations

| Implementation | Compatibility / reliability evidence | Calibration | Maintainability / decision |
| --- | --- | --- | --- |
| [librehat](https://github.com/librehat/st-zemismart-window-treatment/blob/93599e17837fb59f41d3afc1d99f958c1c9b92ef/src/init.lua) | Six named TS0601 manufacturers, EF00 control; no cirjrpxe fingerprint. Narrow parser assumes a single numeric DP, so malformed/raw/multiple records need hardening. | DP16 enum 0/1 set upper/lower; 2/3 delete. Boolean settings swap endpoints with reverse. | Archived July 2025. Useful small base and original-device compatibility; adding the target fingerprint alone would incorrectly assume its calibration map. Retain original profile and quirks in `legacy.lua`, share bounded framing. |
| [iquix Edge 0.7.1](https://github.com/iquix/ST-Edge-Driver/blob/736691b62a99b6cba540791aa8eea5fbda3be373/tuya-window-shade/src/init.lua) | User reports this works. EF00 DP1 enum open/stop/close=0/1/2, DP2 32-bit percentage, DP3 reports. Suppresses default responses; Basic bind plus ordered attribute read; mains-only ApplicationVersion reporting. Device families also have DP2-position, DP6-completion, DP7-work-state and inversion quirks. | No upper/lower limit UI or DP118 handler in inspected Edge source. The old Groovy DTH's automatic calibration is device-specific and is not equivalent. | Reuse target-relevant transport/initialization/percentage behavior. Avoid importing unrelated device families. Its added handler can move an uninitialized device to 50%; omit that behavior for supervised setup. |
| [stock SmartThings](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/blob/247dbadb4f1a66c74c0713c5c6f4fde69e4f859c/drivers/SmartThings/zigbee-window-treatment/src/init.lua) | User reports prior operation. Registers SDK defaults plus many manufacturer subdrivers. SDK WindowCovering uses 0x0102 Open/Close/Stop and GoToLiftPercentage; Zigbee default 0=open vs SmartThings 100=open. | Standard positioning/physical-limit attributes do not establish a manufacturer procedure to learn/save this motor's stops. No exact cirjrpxe DP118 mapping in inspected driver. | Best source for standard commands and SDK integration. Use SDK builders directly for the explicit standard backend; do not copy the entire general-purpose driver. |
| [Mariano](https://github.com/Mariano-Github/Edge-Drivers-Beta/blob/bdf24246fd24563e6e35ea2cb8b2f14f9c8584ed/zigbee-window-treatment/src/init.lua) | Model-only TS0301 fingerprint can select its battery/invert profile, but no cirjrpxe-specific EF00 handler exists in inspected source. Generic defaults issue 0x0102 commands. Yoolax subdriver is limited to named manufacturers. | The `tuya-calib` path applies to TS130F and uses 0x0102 attributes F001/F002/F003, not this fingerprint's Tuya limit DP. | Signal metrics and broad profiles are useful generally, but importing that framework increases unrelated surface. Its source warns that channel packages can differ from repository code. Cannot establish the exact installed failure without version/logs. |

Mariano's likely mismatch is an inference from handler routing, not a demonstrated radio/firmware fault. Other possibilities include endpoint selection, position inversion, an installed channel version differing from source, or a motor that accepts 0x0102 only partially. Test one explicit backend at a time and capture responses; do not claim a confirmed root cause without logs.

## Exact-fingerprint finding: DP118, not DP16

[zemismart-dev's `zm25z.js`](https://github.com/zemismart-dev/zigbee2mqtt/blob/4626587396e51f4bc617a504d698bd07bdbd5d25/zm25z.js) explicitly matches `TS0301 / _TZE200_cirjrpxe`. Its [README](https://github.com/zemismart-dev/zigbee2mqtt/blob/4626587396e51f4bc617a504d698bd07bdbd5d25/README.md) labels that fingerprint **ZM25Z mains-powered curtain motor**, while the user identifies **ZM15B**. Use the complete fingerprint as protocol evidence, but keep the retail-name discrepancy visible for hardware acceptance. This converter is external to upstream Zigbee2MQTT and its publication is not a test report for the user's motor.

Protocol facts independently implemented here:

| DP (decimal / hex) | Type / meaning | Use in target |
| --- | --- | --- |
| 1 / 01 | enum open=0, stop=1, close=2 | Commands and motion reports; iquix-compatible |
| 2 / 02 | 32-bit percentage | Command; by default treated as destination echo on RX, following iquix. Explicit DP2 report variant available if observed |
| 3 / 03 | 32-bit percentage | Default actual-position report |
| 5 / 05 | enum forward=0, back=1 | Logged; target uses software reversal and does not reprogram direction |
| 107 / 6B | enum no limits=0, upper+lower=1, plus favorite=2 | Diagnostic status |
| 118 / 76 | enum delete upper/lower/middle=0/1/2; set upper/lower/middle=3/4/5 | Only upper/lower actions exposed, opt-in and one write per deliberate change |
| 119 / 77 | enum delete success/failure=0/1; set success/failure=2/3 | Diagnostic result; no fabricated physical-state confirmation |
| 124 / 7C | enum charging status | Logged as unmapped; no inferred battery percentage |

The exact converter maps both DP2 and DP3 to position; it does not establish which reports are destination echoes on every firmware. Keeping iquix's DP3 default prioritizes the user's working behavior. A DP13 battery report is accepted only if received; the exact converter itself does not map battery percentage. The battery capability also serves the optional standard PowerConfiguration report; an empty battery field is not a command failure.

DP119 has no proven request/action correlation semantics here. A timely result is useful evidence, but may be unsolicited or stale. The driver logs the pending action, result, raw frame and transaction; a result or ZCL SUCCESS never substitutes for endpoint/persistence testing.

## Other ecosystems and why DP16 must be scoped

- [Zigbee2MQTT converter definitions](https://github.com/Koenkk/zigbee-herdsman-converters/blob/d9247ac943045e85d20e1a3189cb49eb0b43d204/src/devices/tuya.ts): generic TS0301 uses standard WindowCovering. `_TZE210_m6lwazh9` instead uses EF00 DP1/2/3/5/13. `_TZE210_xgzzuerd` uses different position DPs **9/8**, direction **11**, and limit **16**. Therefore even TS0301 plus EF00 does not identify one DP map.
- [Zigbee2MQTT `coverLimit` converter](https://github.com/Koenkk/zigbee-herdsman-converters/blob/d9247ac943045e85d20e1a3189cb49eb0b43d204/src/lib/tuya.ts): DP16-style enum 0/1 set, 2/3 delete, 4 delete-both. This validates librehat's protocol family, not cirjrpxe.
- [ZHA `ts0601_cover.py`](https://github.com/zigpy/zha-device-handlers/blob/1d6598c32a8b4f054438f63f08fc36ff3d6b4930/zhaquirks/tuya/ts0601_cover.py): multiple inverted command/position families. The `_TZE284_3mzb0sdz` builder uses position DP9/8, direction DP11, battery DP13 and border DP16. Its set/delete buttons confirm those meanings on that fingerprint only. No cirjrpxe-specific quirk was found in the checked tree.
- [Mariano TS130F calibration](https://github.com/Mariano-Github/Edge-Drivers-Beta/blob/bdf24246fd24563e6e35ea2cb8b2f14f9c8584ed/zigbee-window-treatment/src/tuya-calib/init.lua): calibration on manufacturer attributes within 0x0102 is a third mechanism. It is not a physical upper/lower limit procedure for cirjrpxe.

No speculative writes to DP16, TS130F calibration attributes, generic physical-limit attributes, unknown direction settings, or full-travel auto-calibration are exposed on the target. DP16 RX remains visible in diagnostics. The retained legacy devices continue their existing DP16 path.

## Implementation and validation boundaries

`src/legacy.lua` preserves original commands, battery handling and `_TZE200_9p5xmj5r` reverse-position quirk. Changes are bounded multi-record parsing, per-device sequence/transport extraction, the Lua truthiness fix for numeric direction 0, and avoiding limit writes when initial preference defaults arrive. The original profile/fingerprints remain. Physical regression testing of those six devices is still outstanding.

`src/zm15b.lua` is selected by both manufacturer and model. It overrides commands/reports/lifecycle, migrates its profile on driver switch, and does not send motion or calibration on setup/restart. Standard and Tuya reports cannot overwrite each other's selected position state. Calibration requires explicit enablement and a new action after Idle; guards reject mixed direction/protocol changes and active jogs. DP119 result or a 15-second warning ends the pending interval. No automatic retries occur.

The preview's SDK-backed checks use official **apiv21_62** message builders, serialization and hub mocks with Lua 5.4; CI uses Lua 5.3. CLI **2.1.2** builds the Edge ZIP. This verifies wire construction, routing assumptions and safeguards, not RF delivery, actual motor Stop, physical travel, power-cycle persistence, firmware-specific DP results or long-term reliability. Account-authenticated SmartThings upload/channel creation and the [hardware acceptance record](CALIBRATION.md) are still required.
