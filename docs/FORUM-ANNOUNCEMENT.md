# [Edge] Zemismart ZM15B / TS0301 blind driver with travel-limit calibration

I’m sharing a custom SmartThings Edge driver for the Zemismart ZM15B with fingerprint **TS0301 / `_TZE200_cirjrpxe`**. It provides blind control and travel-limit configuration through SmartThings, without requiring a remote or Tuya hub.

**[Install from UL’s edge drivers](https://bestow-regional.api.smartthings.com/invite/6Vjdn3bxx62N)**  
**[Source code and documentation](https://github.com/ulevitsky/st-zemismart-window-treatment)**

Features:

- Open, close, stop, percentage positioning and presets.
- Set or delete open/closed endpoints through device settings.
- Endpoint actions follow **Reverse app direction**, so they match the app controls.
- Optional short timed jogs for setup and detailed Zigbee diagnostics.
- Switch from an existing Edge driver without re-pairing.

This is a community preview. It is reported working on a ZM15B with the fingerprint above; please check the complete manufacturer/model rather than assuming all Zemismart or TS0301 motors use the same protocol. Six original librehat TS0601 fingerprints are also retained, but have not been hardware-tested as part of this fork.

To install, open the invitation, sign in, accept, enroll your hub, and install **Zemismart Blinds Lab (ulevitsky)** under Available Drivers. Then select it from the blind’s **Driver → Change driver** screen in the SmartThings app. No CLI or ZIP is needed.

Calibration is disabled by default. Follow the [incremental calibration guide](https://github.com/ulevitsky/st-zemismart-window-treatment/blob/main/docs/CALIBRATION.md): establish reliable Stop with short jogs, stop before saving a limit, and test one endpoint at a time. After upgrading from the first preview, reopen Settings and save **Endpoint action = Idle** before selecting a new action. Updating does not rewrite existing motor limits.

For this exact fingerprint, calibration uses Tuya DP118, with DP119 result reports. The related Zemismart converter labels the fingerprint ZM25Z, so firmware variations still need checking. The [research notes](https://github.com/ulevitsky/st-zemismart-window-treatment/blob/main/docs/RESEARCH.md) explain the mappings and alternatives.

Thanks to **[librehat](https://github.com/librehat/st-zemismart-window-treatment)** for the original driver and **[iquix](https://github.com/iquix/ST-Edge-Driver)** for the Tuya control implementation. The project also draws on protocol evidence from Zigbee2MQTT, ZHA and Zemismart’s external converter.

Please report issues through [GitHub Issues](https://github.com/ulevitsky/st-zemismart-window-treatment/issues), including the fingerprint, firmware, driver version, settings, action attempted, and relevant Zigbee logs. Remove personal device or network identifiers before posting logs publicly.
