# Remote Gaming, Input, and Tooling

Use this for Moonlight, Sunshine, Steam Remote Play, controllers, and input quirks.

## Checks
- `journalctl -b | grep -Ei 'sunshine|moonlight|gamepad|controller'`
- `lsusb`
- `udevadm info --query=all --name=/dev/input/event*`

## Notes
- Confirm the input device is recognized before debugging the app layer.
- Remote play issues often come from encoding, network, or session state.
