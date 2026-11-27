# ColorOS 17 / OnePlus 13 Coexistence Observer v0.1.0-pre1

**TEST-ONLY, MONITOR-ONLY**. This is NOT a Lucky_Control replacement and does NOT start the original yumi scheduler. Do not flash upstream yumi on the OnePlus 13 with active OPlus/WALT game scheduling; this separate ZIP installs a passive observer.

## How it operates
- Watches every 20 seconds from a KernelSU/Magisk-compatible service, storing state only within its own `/data/adb/modules/coloros17_arbiter_observe/state/status.txt`.
- Reports SCRC, OPGCE, Lucky module-enable status, thermal-engine-v2 process presence, camera process presence, WALT and game-service indicators.
- **All states** keep `actuator_enabled=0`. No sysfs/procfs settings, CPU/GPU frequencies, display refresh rates, COSA database, camera config, property or mount is modified.
- Priority is `THERMAL_UNVERIFIED > CAMERA_POSSIBLE > COSA_DUAL_OWNER > OPLUS_GAME_OWNER > STOCK_OBSERVE`.
- Camera process is only a conservative signal, NOT an active camera session. A missing thermal process is **UNVERIFIED**, not proof of disabled thermal protection.

## Installation
Import the ZIP as a root module and restart once. This ZIP does NOT include the yumi daemon.
Check status in your root shell:

```sh
cat /data/adb/modules/coloros17_arbiter_observe/state/status.txt
sh /data/adb/modules/coloros17_arbiter_observe/bin/arbiter.sh --once
```

If the module isn't installed, running the `arbiter.sh --once` file directly in Root Shell produces the same read-only snapshot. Uninstall/disable through your root manager: no vendor or COSA data cleanup. Disable/uninstall does not touch SCRC, OPGCE or Lucky.

## Compatibility gates before a real scheduler
1. Test SCRC and OPGCE with one COSA strategy writer at a time, never invoke OPGCE `uninstall.sh` as a diagnostic rollback (it clears COSA data).
2. Identify actual active CameraService clients without treating listener PIDs as open camera sessions.
3. Verify all proposed writers have exclusive control of their sysfs nodes; never override the stock thermal service.
4. Verify camera 0.6x/1x/3x paths, high-res mode, metadata and video before enabling any actuator.

## Known limitations
- The `pidof com.oplus.camera` check may flag cached/background camera processes; it is intentionally conservative.
- Root manager module markers report enabled state only, not whether an injector has completed a write.
- The observer does not evaluate whether OPlus BSP limits or CPU frequencies are appropriate. No active control path exists.
