# Zemismart Blinds Lab (ulevitsky)

Independent SmartThings Edge driver fork for **ZM15B / TS0301 / `_TZE200_cirjrpxe`**, retaining librehat's six TS0601 fingerprints. Includes open, close, pause/stop, percentage/preset positioning, supervised upper/lower limit actions, and Zigbee diagnostics.

**Status: software-tested preview; physical acceptance on the user's ZM15B is pending.** There is no published SmartThings channel ID yet: account login is required to create it. The GitHub prerelease provides a CLI-built package.

The key research finding is that the [exact-fingerprint Zemismart converter](https://github.com/zemismart-dev/zigbee2mqtt/blob/4626587396e51f4bc617a504d698bd07bdbd5d25/zm25z.js) uses **DP118 (`0x76`)** for limits and **DP119 (`0x77`)** for results. It names that fingerprint ZM25Z, while this project targets the user's ZM15B. Confirm actual firmware behavior incrementally. **DP16 (`0x10`) is not sent for this fingerprint.** Existing TS0601 devices retain librehat's DP16 commands.

## Install and switch

1. Download `ulevitsky-zemismart-blinds.zip` from the [preview release](https://github.com/ulevitsky/st-zemismart-window-treatment/releases/tag/v0.1.0-test1).
2. Install the CLI: `npm install -g @smartthings/cli@2.1.2`.
3. Run `smartthings edge:channels:create` and complete account login. Name your developer channel, then record its ID.
4. Run `smartthings edge:drivers:package --upload ulevitsky-zemismart-blinds.zip --channel YOUR_CHANNEL_ID --install`. Select your hub.
5. With the motor stopped, select **Driver → Change driver → Zemismart Blinds Lab (ulevitsky)** in the SmartThings app; or run `smartthings edge:drivers:switch`. Keep the working iquix driver installed for rollback.
6. The switch handler updates the profile. Reopen the device screen to load its settings. No re-pairing or factory reset is required.

See [installation and developer-channel commands](docs/INSTALL.md) and [safe incremental calibration](docs/CALIBRATION.md) before operating a motor with uncertain limits.

## Design

- Exact-fingerprint ZM15B handler: iquix-compatible EF00 DP1/2/3 control, Basic bind/initialization, default-response suppression; no automatic movement on join, switch, or restart.
- Explicit standard Zigbee `0x0102` backend for comparison, using official SDK commands and percentage conversion. No automatic protocol switching or duplicate movement commands.
- DP118 limit actions default to disabled, execute only on deliberate preference changes, and are never retried automatically. DP107 status and DP119 result reports are decoded in logs.
- Per-device transaction numbers, bounded multi-DP parsing, datatype checks, raw unknown-message logs, and an optional 1–2 second jog with a queued Stop.
- Original TS0601 profile, quirks, and calibration remain isolated in `src/legacy.lua`; initialization defaults cannot accidentally clear a limit.

The [comparison and architecture decision](docs/RESEARCH.md) cover iquix, stock SmartThings, Mariano, ZHA, Zigbee2MQTT, and device-specific uncertainty.

## Develop

Use Lua 5.3 or 5.4 and the official [Edge SDK apiv21_62](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/releases/tag/apiv21_62). No SDK files are vendored.

```sh
EDGE_LUA_LIBS=/path/to/lua_libs-api_v21 LUA=lua5.4 ./scripts/test.sh
smartthings edge:drivers:package . --build-only dist/ulevitsky-zemismart-blinds.zip
```

Tests use official SDK message builders/serialization and hub mocks. They cover commands, reports, malformed frames, migration, jog behavior, calibration guards/timeouts, and legacy limit behavior. They do not simulate physical travel. CI runs the checks and builds a downloadable package.
