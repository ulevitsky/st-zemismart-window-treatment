# Zigbee Blind Control

Independent community SmartThings Edge driver, with no manufacturer affiliation. Includes support for **ZM15B / TS0301 / `_TZE200_cirjrpxe`**, retaining librehat's six TS0601 fingerprints. Includes open, close, pause/stop, percentage/preset positioning, supervised open/closed endpoint actions, and Zigbee diagnostics.

**Status: community preview, reported working on a ZM15B.** Published through **UL’s edge drivers**; firmware variants and retained legacy devices need further hardware testing.

The key research finding is that the [exact-fingerprint Zemismart converter](https://github.com/zemismart-dev/zigbee2mqtt/blob/4626587396e51f4bc617a504d698bd07bdbd5d25/zm25z.js) uses **DP118 (`0x76`)** for limits and **DP119 (`0x77`)** for results. It names that fingerprint ZM25Z, while this project targets the user's ZM15B. Confirm actual firmware behavior incrementally. **DP16 (`0x10`) is not sent for this fingerprint.** Existing TS0601 devices retain librehat's DP16 commands.

## Install and switch

**[Install from UL’s edge drivers](https://bestow-regional.api.smartthings.com/invite/6Vjdn3bxx62N)** — no CLI or ZIP required.

1. Open the invitation link and sign in with your Samsung account.
2. Accept the invitation, choose your SmartThings hub and select **Enroll**.
3. Open **Available Drivers** and install **Zigbee Blind Control**.
4. With the motor stopped, open its device page in the SmartThings app and choose **Driver → Change driver → Zigbee Blind Control**. Keep the working driver installed for rollback. No re-pairing or factory reset is required.
5. Reopen Settings and save **Endpoint action = Idle** before any calibration action. Read the [safe incremental calibration guide](docs/CALIBRATION.md).

The channel is **UL’s edge drivers** (`4c5629b7-c3df-4e79-b0b1-b088b2ccc91c`). The driver ID is `fec52ec7-75d7-4d0d-8eb0-1ca2f491b7d3`.

For CLI installation, source builds, updates or creating your own channel, see [installation and developer-channel commands](docs/INSTALL.md). Packaged ZIPs remain available from the [preview release](https://github.com/ulevitsky/st-zemismart-window-treatment/releases/tag/v0.1.2-test1).

## Design

- Exact-fingerprint ZM15B handler: iquix-compatible EF00 DP1/2/3 control, Basic bind/initialization, default-response suppression; no automatic movement on join, switch, or restart.
- Explicit standard Zigbee `0x0102` backend for comparison, using official SDK commands and percentage conversion. No automatic protocol switching or duplicate movement commands.
- Open/closed endpoint labels follow **Reverse app direction**, so calibration matches the app controls. Changing reversal does not rewrite saved limits.
- DP118 limit actions default to disabled, execute only on deliberate preference changes, and are never retried automatically. DP107 status and DP119 result reports are decoded in logs.
- Per-device transaction numbers, bounded multi-DP parsing, datatype checks, raw unknown-message logs, and an optional 1–2 second jog with a queued Stop.
- Original TS0601 profile, quirks, and calibration remain isolated in `src/legacy.lua`; initialization defaults cannot accidentally clear a limit.

The [comparison and architecture decision](docs/RESEARCH.md) cover iquix, stock SmartThings, Mariano, ZHA, Zigbee2MQTT, and device-specific uncertainty.

## Develop

Use Lua 5.3 or 5.4 and the official [Edge SDK apiv21_62](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/releases/tag/apiv21_62). No SDK files are vendored.

```sh
EDGE_LUA_LIBS=/path/to/lua_libs-api_v21 LUA=lua5.4 ./scripts/test.sh
smartthings edge:drivers:package . --build-only dist/zigbee-blind-control.zip
```

Tests use official SDK message builders/serialization and hub mocks. They cover commands, reports, malformed frames, migration, jog behavior, calibration guards/timeouts, and legacy limit behavior. They do not simulate physical travel. CI runs the checks and builds a downloadable package.
