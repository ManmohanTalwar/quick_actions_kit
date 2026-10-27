# quick_actions_kit validation

Date: 2026-10-27. Release candidate: **0.1.0**. This record separates the original
0.1.0-dev.1 implementation checks from the 0.1.0 distribution checks below.
Website registration and publisher authentication are complete; the CLI upload
and fresh registry-consumer check are pending. No Orb application migration is
claimed. Finish this package before deciding the remaining plugin order.

## Scope and provenance

Retains the familiar QuickActions/ShortcutItem API for dynamic set, clear and
activation. Replaces Flutter messaging with iOS FFI and Android FFI/JNI. Adds
explicit errors, callback lifetime protection, serial operations and disposal.
App navigation, auth, account and permission decisions remain outside the plugin.

Flutter API references: quick_actions 1.1.0, Android 1.0.18, iOS 1.2.5; Orb Flutter
source pin 61449f0e76c22b7f7fa96afc6f7a5fbff78a9c6f. Inspected file hashes and
licences: provenance.json. No source checkout was modified.

SDK: DartNative 1.4.0, Dart 3.12.0-192.0.dev; framework 75bc07e9b49, engine
ed0d71411e76bf9558f1c4dc8078f3222e364497. Public guide pin:
1be7f977753bf7976c0861b64756cc34aa1b489f. Native floors: iOS 15, Android API 26.

## Original implementation qualification (0.1.0-dev.1)

| Evidence | Result | Boundary |
|---|---|---|
| Dart analyzer: lib, test, example/lib | No issues | SDK-specific source analysis |
| Dart behavior suite | 11 passing | Cold delivery ordering, handler/host replacement, repeated taps, dispose/reinitialize, validation, Unicode, snapshot isolation, serialization and failures |
| Swift typecheck and consumer build | Passed | iOS simulator debug app; actual linking/registrant |
| Android consumer build | Passed | Debug APK, merged receiver manifest and JVM-loaded JNI bridge |
| Official standalone plugin build | Passed | AAR arm64-v8a/x86_64; XCFramework iOS arm64 + simulator arm64/x86_64 |
| Android ELF alignment | All LOAD segments 0x4000 | Plugin .so only; not a whole-app 16-KB runtime qualification |
| iOS runtime | Passed bounded smoke | iPhone 17 Pro, iOS 26.5 simulator: launcher set, warm/repeated/Unicode delivery, cold launcher start, clear, hot restart followed by delivery |
| Android runtime | Passed bounded smoke | Android 14/API 34 arm64 emulator: ShortcutManager entries, warm receiver launch, retained-isolate activity recreation, repeated/Unicode events, cold receiver launch, clear, hot restart followed by delivery |

Android activation checks use explicit intents to the manifest receiver matching
the registered shortcut target. They do not establish behavior for every launcher.
The iOS checks use the actual SpringBoard long-press menu. Screenshot witnesses
are under validation/; the sequence above distinguishes cold/restart from a mere
visible result. No broad UI/accessibility, performance or app parity claim is made.

Runtime checks found and corrected Android RTLD_LOCAL symbol visibility (the
public DN_IsolateGen is resolved from the already loaded core), retry after a
failed initial binding, and host recreation/delivery timing. The current design
rebinds only from a live Dart isolate; native code never revives a stale pointer.
New-isolate registration resets delivery, generation/session checks invalidate
old queued work, and pending activations wait for the host to resume.

## Reproduce

From the package with the pinned DN SDK:

```sh
dn pub get
dart analyze lib test example/lib
dart test
python3 tool/check_distribution.py
dn plugin build --owner local_validation --out /tmp/quick-actions-artifacts
cd example
dn pub get
dn build ios --simulator --debug
dn build apk --debug
dn run -d <simulator-or-emulator-id>
```

`local_validation` is a local build label, not an assigned publisher. See the
example README for the runtime steps. The binaries built here are not published.

## Qualification limits

- Physical iOS/Android devices, minimum supported OS versions, Android launcher
  variants, release/AOT and Android shrinking, icon resource fallback and rate
  limits, static/pinned shortcut coexistence, multi-window/multi-engine hosts.
- Controlled old-install upgrade: Android receiver identity differs from Flutter,
  so existing dynamic shortcuts must be refreshed; pinned/static legacy shortcuts
  require an explicit app-owned migration policy. No upgrade continuity is claimed.
- Stress events during teardown/restart, long background suspension, system kill
  and launcher task-stack restoration beyond the bounded smoke sequences.
- The official builder's Dart-binding archive is not a complete native source
  distribution. Full native source, tests, GIFs and evidence are in the public
  repository. Both archives carry LICENSE and collector-readable NOTICES; README
  also reproduces the synchronized notices.

## Version 0.1.0 release checks

- Public repository: [ManmohanTalwar/quick_actions_kit](https://github.com/ManmohanTalwar/quick_actions_kit).
  Package version is `0.1.0`, consumer constraint is `^0.1.0`, and both publishing
  metadata and the example point explicitly to `https://dartpub.dev`.
- SDK-specific analysis of lib/test/example passed. All 11 behavior tests passed
  using the cached test runner with the existing DN resolution. The ordinary Dart
  test launcher tried resolving dartnative from pub.dev; it is not evidence of a
  successful fresh resolution. Use `dn pub get` with the installed DN SDK.
- Android debug example rebuilt with the final Quick Actions Kit display name.
- Both README GIFs show actual launcher menus and a single compose callback.
  The iOS 26.5 simulator and Android 14/API 34 emulator were newly created for
  recording; Quick Actions Kit was the only non-system app installed. No Orb
  apps or account data appear. Static waiting time was trimmed; action order and
  native UI were preserved. iOS used RocketSim; Android used emulator recording.
  Marionette's Flutter binding cannot drive DN or the OS launcher directly.
- The iOS recording used the previously qualified example binary with unchanged
  runtime source; the Android recording used the newly built debug APK. These
  demos do not establish physical-device, AOT, minimum-OS or upgrade support.
- Official 0.1.0 standalone build passed: iOS arm64 device + arm64/x86_64 simulator
  XCFramework and Android arm64-v8a/x86_64 AAR. Plugin ELF LOAD alignment is 0x4000
  for both Android ABIs. This is not a whole-app 16-KB device qualification.
- Both archives passed the distribution notice check. Textual payloads contain
  no local home paths or source-development overrides. Native artifacts include
  public bindings and wrappers; GitHub remains the complete source distribution.

The original `validation/source-sha256.json` and `artifact-sha256.json` are
historical snapshots for 0.1.0-dev.1. Final 0.1.0 archive checksums are recorded
separately. Example lockfiles may describe the earlier source qualification;
registry-consumer validation uses a fresh directory without locks or overrides.

## Publication verification

Pending: push the final candidate, upload via `dn plugin publish`, then resolve
and build a fresh consumer from the registry without local source overrides.
Website registration alone does not upload a version or its native binaries.
