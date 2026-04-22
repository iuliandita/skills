# Capture and Sharing

Use this reference for OBS, browser WebRTC, Discord or Teams, screen sharing, hardware encoding,
and virtual cameras.

## Gather facts

```bash
systemctl --user status xdg-desktop-portal pipewire wireplumber 2>&1 || true
journalctl --user -b | grep -Ei 'portal|pipewire|webrtc|obs' 2>&1 || true
rpm -qa | grep -Ei 'obs|portal|pipewire|v4l2loopback|ffmpeg' | sort
lsmod | grep '^v4l2loopback' 2>&1 || true
```

## Patterns

- Wayland screen sharing is usually portal + PipeWire + client support.
- X11 capture issues are different from Wayland screencast issues.
- Virtual camera failures often come from kernel-module drift after updates.
- Hardware encoding failures may be driver, firmware, or SELinux path issues.
