# quick_actions_kit validation

Date: 2026-10-27. Version: **0.1.0-dev.1**. Original implementation complete for
the bounded first package. **Development qualification, not a published release
or Orb application migration.** Stop here; decide remaining plugin order with the user.

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

## Completed checks

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

## Remaining release gates

- Physical iOS/Android devices, minimum supported OS versions, Android launcher
  variants, release/AOT and Android shrinking, icon resource fallback and rate
  limits, static/pinned shortcut coexistence, multi-window/multi-engine hosts.
- Controlled old-install upgrade: Android receiver identity differs from Flutter,
  so existing dynamic shortcuts must be refreshed; pinned/static legacy shortcuts
  require an explicit app-owned migration policy. No upgrade continuity is claimed.
- Stress events during teardown/restart, long background suspension, system kill
  and launcher task-stack restoration beyond the bounded smoke sequences.
- Before a catalogue release, confirm publisher/copyright holder, final version,
  name reservation and licence review, then clean installation from the registry.
- The official builder's native and Dart-binding archives omit extra docs/notices.
  README includes synchronized notices; full native source/tests/evidence must
  accompany the public repository. Do not call the Dart-only source tarball a
  complete native source distribution.

## Source repository

Public source: [https://github.com/ManmohanTalwar/quick_actions_kit](https://github.com/ManmohanTalwar/quick_actions_kit). The initial GitHub upload is
separate from catalogue registration and release; `publish_to: none` remains set.

The source and artifact hashes in validation/ record the original local native
qualification. Repository metadata was subsequently added to pubspec.yaml and
the podspec homepage; runtime source is unchanged. The native binaries were not
rebuilt for this metadata-only update. The example Podfile.lock likewise records
the earlier native build and will be refreshed by the next native dependency
resolution.

For the initial source upload, analysis of lib/test/example passed, all 11
existing tests passed via the cached test runner with the existing DN package
resolution, and distribution notices plus podspec syntax checks passed. The
ordinary Dart test launcher attempted to resolve dartnative from pub.dev after
the metadata edit; it was not used as a successful fresh dependency-resolution
check. No new native build, device run or clean-clone qualification is claimed.
