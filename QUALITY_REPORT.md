# 0.5.13 quality report

Implementation base: `3bd7830cecf15550cd841368e497372f6fa43444` (GitHub 0.5.10).
Target: Barotrauma 1.13.4.0; LuaCs `85ded59c4efed4d139159c4cb056cc9705a5096e`.
Status: **release candidate**. Automated checks pass; the in-game matrix remains unverified.

## Changes

- Same-team server authority and client selection, execution-time team/control checks, and stale-button target protection.
- Independent diving/base render lifetimes, retryable load errors, bounded activation retries, cleanup of replaced/removed characters, and configured NPC diving restoration.
- Cached diving storage keys and custom-look signatures; loaded disabled profiles leave the poll set. No stable-state capture, disk write or wardrobe packet.
- Focus-aware shortcut and wrapped/localized persistence status text.
- Native executable rendering/alarm checks plus expanded persistence, UI, authority and package failure cases.
- Consistent version metadata; candidate gate reads the previous verified version from metadata. Source package includes settings and a SHA-256 manifest.

## Baseline

Upstream build, MoonSharp tests, persistence probe and static renderer contracts passed. Upstream package verification failed because filelist.xml declared 0.5.18 while version.json and code declared 0.5.10. Configuration coverage also omitted Config/SettingsClient.xml.

All probed API signatures passed. The original compatibility gate failed its LuaCs commit pin. Source comparison found only a macOS preprocessor change across the two intervening commits; the new pin records the actually installed Windows assembly without claiming cross-platform execution.

## Validation limits

Automated validation on 2026-09-06 (Windows, game 1.13.4.0, SDK 10.0.400 targeting net8.0):

| Check | Result |
| --- | --- |
| Release build | PASS, zero warnings/errors |
| Exact game/LuaCs capability probe, including optional hooks | PASS |
| MoonSharp syntax and core/client/server behavior suites | PASS |
| Persistence and native renderer/alarm probe | PASS |
| Static renderer contracts | PASS |
| Package behavior tests | PASS, 8 cases, including a Unicode output directory |
| Source package gate and git diff whitespace check | PASS |
| `--release` on this candidate | Expected rejection; not promoted to verified |

Probe artifacts/logs stay under ignored `artifacts/quality`.

## Isolated performance comparison

The same facade fixture runs 600 steady custom-diving think ticks through the actual installed MoonSharp. Setup/compilation is excluded. Each measurement starts after GC.Collect, reads Stopwatch elapsed time and GC.GetAllocatedBytesForCurrentThread, and asserts no new capture, save or wardrobe packet. Three fresh runner processes are used per source revision.

| Source | Elapsed ms (three runs) | Median ms | Allocated bytes per run |
| --- | --- | --- | --- |
| GitHub 3bd7830 | 108.181 / 106.944 / 106.203 | 106.944 | 105,487,448 |
| 0.5.13 | 47.237 / 38.141 / 50.401 | 47.237 | 33,589,896 |

This workload shows about **55.8% lower elapsed time** and **68.2% fewer allocated bytes**. These are test-double/MoonSharp workload results, not game FPS or whole-mod CPU/GC measurements. The earlier preliminary numbers used an earlier fixture; the table uses the final shared fixture for both revisions. Renderer draw CPU/allocation, live network traffic and real file-write frequency still need in-game profiling.

## Local installation and rollback

Create the explicit source package with `scripts/package_mod.py`; its manifest covers every package payload. Deployment checks Barotrauma is closed, backs up the previous LocalMods directory and existing player settings/data, copies only listed package files, and checks installed hashes. The rollback branch for the pre-update repository is `codex/wardrobe-before-quality` at `7c96b11`.

The installation backup location, source-package hashes and deployed paths are recorded in ignored `artifacts/quality/deployment.json`. To roll back with the game closed, restore the recorded installation backup and remove only newly deployed files recorded there. Player runtime data is left untouched by deployment.

No game UI/GPU session, live two-client multiplayer, Linux dedicated server or Performance Fix/ItemOptimizer conflict matrix has been executed for this candidate. These are **unverified**, not passing. Native renderer probes create no graphics device and do not validate pixels, sound playback or frame rate. No Workshop publication or GitHub push is part of this change.
