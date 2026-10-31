# ColorOS 17 / OnePlus 13 coexistence contract (draft)

Target: PJZ110 / OP5D0DL1 / Android 17 / Kernel 6.6.150 (device-specific; re-probe on every update).

## Evidence and limits
Reviewed user-supplied `SCRC-v5.7.zip` and `OPGCE_v3.1.6(1).zip`. Encrypted game strategy payloads and native injectors were **not** decoded or executed. Neither package alone proves it is currently installed or functioning.
- SCRC: `bin/inject` targets `com.oplus.cosa`'s `db_game_database`; `script/restart_service.sh` starts oiface/horae/gameopt/URCC and enables COSA components. Optional `ctn_patch.ko` path is gated on a kernel 6.1.141 pattern, so must **not** be assumed active on kernel 6.6.150.
- OPGCE: `inject_cosa.sh`/`inject_core` target the same COSA database. `service.sh` force-stops COSA during injection. `system.prop` globally sets `vendor.display.disable_system_load_check=1` and `vendor.display.enable_perf_hint_large_comp_cycle=0`. Its `uninstall.sh` clears/removes COSA user data: do **not** use that script as a generic compatibility rollback.
- OPGCE includes `/dev/opgce/mode` with 0666 permissions and an optional MT-platform SLC bind mount; no basis for assuming that branch applies to SM8750. The uploaded ZIP references `sgame_mtr.sh` but does not contain it.
- Unmodified yumi has active CLG/FAS CPU-frequency writers, screen-off caps, and sysfs/mount management, and must **not** run as an independent actuator alongside HMBIRD/WALT/COSA before device validation.
- Other known modules include KernelSU/SUSFS, BRENE, NoMount, ViPER4Android and separate GPU/display modules. Existing camera modifications may include OPCameraPro/LSPosed; preserve their boundaries.

## Non-negotiable ownership rules
1. **Factory thermal protection always wins.** Never stop thermal services, bypass thermal trips, or blindly override `freq_qos`.
2. **Camera takes precedence over gaming.** Enter OBSERVE_ONLY while `com.oplus.camera`, `com.tlsu.opluscamerapro`, or an active camera client is detected. This includes video/third-party camera access; package foreground checks alone are insufficient.
3. **Game mode leaves HMBIRD / game_opt / COSA as CPU/game scheduling owners.** yumi's eBPF/FPS path may measure, but FAS/CLG frequency writers are disabled by default. No second PID frequency controller.
4. **COSA policy must have one injection owner.** SCRC and OPGCE both target `db_game_database`; do not trigger them together or treat their payloads as safely composable. Decide a single owner only after database backup, serialised inspection and one-module A/B testing.
5. **No opportunistic mount changes.** No system-file overlays, dynamic unmount/remount, or manipulating SUSFS namespaces in the adapter. Preserve GPU/audio/thermal module mounts.
6. **Write only nodes we own, with CAS-style restoration.** Capture baseline just before any permitted write and restore only if the current value still equals our last applied value. Restore no third-party values.
7. **Fail open to stock.** If camera state, thermal telemetry, kernel capabilities, or competing writer ownership is unknown, run OBSERVE_ONLY; never infer that a compatible `sysfs` node proves a safe write.
8. **No uninstall-based rollback.** Do not run OPGCE `uninstall.sh` or SCRC cleanup to test coexistence; those contain COSA data-clearing operations.

## Arbiter state machine (planned, not implemented)
`INIT -> OBSERVE_ONLY` (default).
Priority: `THERMAL_EMERGENCY > CAMERA_ACTIVE > GAME_HMBIRD > DAILY > IDLE`.
- THERMAL_EMERGENCY / CAMERA_ACTIVE: stop our writes, restore exclusively owned nodes safely; retain stock thermal/camera services; keep monitoring.
- GAME_HMBIRD: measure only, publish hints / policy to the existing owner after an explicit negotiated integration.
- DAILY: may later enable conservative controller **only if** no competing owner exists and the device passes an A/B test.
- IDLE/screen off: do not replace stock URCC/thermal policy.

## Camera regression contract
Camera issues predate this work: check original camera UI, 0.6×/1×/3× lens paths, normal-photo output size (~25 MP goal), high-definition control, HEIC/10-bit output **metadata** (not just a UI toggle), portrait/night/video and supported 4K60 modes. Do not force 4K120 (previous experiments could hang) and do not modify camera APK, config, LUT, Camera2 vendor tags or LSPosed scope.
Use three fresh-reboot scenarios: stock scheduling; SCRC-only *or* OPGCE-only; new module OBSERVE_ONLY + chosen owner. Test game -> camera, camera -> game, recording while screen changes, camera background client, and thermal recovery. Capture only non-sensitive logs.

## Acceptance gates before any CPU writer goes live
- Kernel eBPF tracepoint/uprobe capabilities verified, and frame measurements cross-checked against actual app FPS.
- Current app and active camera-client detection verified; no false transition during camera recording.
- `/sys` and `/proc` write sets enumerated for every module; one writer per resource.
- COSA database is backed up and single-writer injection validated; both module install statuses recorded.
- Camera tests pass; no crashes, blocked preview, missing camera controls, wrong lens selection, or forced display changes.
- Thermal and power recovery verified in 10–15 minute real loads with conservative stop conditions.
- All features are opt-in; default mode is read-only. No automatic flashing or `main` merge.

## First work item
Run `tools/coloros17-compat-probe.sh` under native Android root shell. It gathers read-only module, display/property, governor, camera-process and COSA metadata signals. Do not upload raw reports without checking for potentially sensitive process/package information.
