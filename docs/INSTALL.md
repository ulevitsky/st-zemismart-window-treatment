# Installation and developer channel

## Public installation (no CLI)

Open **[UL’s edge drivers](https://bestow-regional.api.smartthings.com/invite/6Vjdn3bxx62N)**, sign in to your Samsung account, accept the invitation, enroll your hub, and install **Zigbee Blind Control** under Available Drivers. Then switch the existing blind to this driver in the app. No re-pairing is required. See [calibration instructions](CALIBRATION.md) before changing limits.

Channel: `4c5629b7-c3df-4e79-b0b1-b088b2ccc91c`

Driver: `fec52ec7-75d7-4d0d-8eb0-1ca2f491b7d3`

## CLI and maintaining your own deployment

Requires a SmartThings account, a supported Edge hub, and the blind already paired to that hub. GitHub and SmartThings authentication are separate. Commands below were checked against CLI **2.1.2** help. CLI build-only works without SmartThings login; cloud upload/channel creation does require it. The public channel above is already deployed; the following instructions are for maintainers or anyone creating a separate channel.

## First deployment

Install the CLI and create a developer channel (prompts for name/description):

```sh
npm install -g @smartthings/cli@2.1.2
smartthings edge:channels:create
smartthings edge:channels --json
```

Record the returned channel UUID and enroll the hub (select it when prompted):

```sh
smartthings edge:channels:enroll --channel YOUR_CHANNEL_ID
```

Upload the release ZIP, assign it, and select that hub when prompted:

```sh
smartthings edge:drivers:package --upload zigbee-blind-control.zip --channel YOUR_CHANNEL_ID --install
```

For an explicitly selected hub:

```sh
smartthings edge:channels:enroll YOUR_HUB_ID --channel YOUR_CHANNEL_ID
smartthings edge:drivers:package --upload zigbee-blind-control.zip --channel YOUR_CHANNEL_ID --hub YOUR_HUB_ID
```

Record the uploaded driver UUID/version. The unique package key is `ulevitsky-zemismart-blinds`; the visible name is **Zigbee Blind Control**. This creates a separate driver from librehat, iquix, Mariano and stock SmartThings. Later uploads using this package key update this driver's package.

To share the channel later, run `smartthings edge:channels:invites:create` and follow its prompts; use the invitation URL returned by SmartThings. No invitation URL is fabricated by this repository.

## Switch without re-pairing

Stop the motor. Keep your current working driver installed and note its name/UUID and preference values. Choose the new driver from the device's Driver screen in the app, or use the CLI:

```sh
smartthings edge:drivers:switch --hub YOUR_HUB_ID --driver NEW_DRIVER_ID YOUR_DEVICE_ID
```

The exact manufacturer/model fingerprint makes the new driver eligible. Its switch handler sets profile `zm15b-blind`, publishes supported commands, binds Basic and reads Basic attributes. It sends no motion, direction-programming, or calibration command. If standard mode is explicitly selected, it also binds/reads/configures position reporting.

Reopen the app's device page after the profile update. The original device identity and pairing remain. Verify routines after switching, especially those referring to capabilities/settings from another profile. Iquix's hardware direction setting remains in the motor; the new `Reverse app direction` preference is separate and defaults to false.

Rollback uses the same app/CLI change-driver operation with the previous driver ID. No reset or re-pairing is needed. Check the previous driver's own behavior on switching: this project cannot prevent another driver from sending configuration or movement commands.

## Build from source

```sh
git clone https://github.com/ulevitsky/st-zemismart-window-treatment.git
cd st-zemismart-window-treatment
mkdir -p dist
smartthings edge:drivers:package . --build-only dist/zigbee-blind-control.zip
```

The ZIP contains only config, fingerprints, profiles and Lua source, not tests or credentials. The CLI normalizes `.yaml` files to `.yml` inside the package. Upload/assign as above.

## Logs

Run on the same network as the hub:

```sh
smartthings edge:drivers:logcat NEW_DRIVER_ID --hub-address YOUR_HUB_LAN_IP --log-level trace
```

Capture the exact time/action, motor label, manufacturer/model, firmware, endpoint/cluster description, and settings. Logs include outgoing DP/type/raw bytes, per-device transaction ID, incoming frames/DPs, malformed records, unknown commands and global/default responses. For investigating rejected Tuya commands, enable **Request Zigbee responses**, repeat one supervised action, then turn it off to return to iquix's frame flags.

ZCL SUCCESS means command acceptance at that layer. It does not prove a limit was saved. DP119 success is a device result report; verify physical behavior too. EF00 command echoes without DP119 do not establish calibration success. A missing response is ambiguous, not proof that the command is unsupported.

## Updating an existing installation

Download the new ZIP from the [release](https://github.com/ulevitsky/st-zemismart-window-treatment/releases/tag/v0.1.2-test1), then upload it to the same channel with `smartthings edge:drivers:package --upload zigbee-blind-control.zip --channel YOUR_CHANNEL_ID --install`. Keep the same channel/package key; this updates the driver already in use. No re-pairing or change-driver operation is needed. Reopen Settings and save **Endpoint action = Idle** before any new calibration action. Open/closed endpoint actions now follow **Reverse app direction**. Existing saved limits remain intact.

## Driver name update (v0.1.2-test1)

The public driver name is now **Zigbee Blind Control**. The package key remains `ulevitsky-zemismart-blinds` solely to update the existing SmartThings driver ID and installations. It is an internal continuity identifier, not the public driver name. ZIP downloads from v0.1.2-test1 onward are named `zigbee-blind-control.zip`; earlier releases retain their original asset names.
