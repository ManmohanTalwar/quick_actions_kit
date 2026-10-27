# Quick actions example

An independent DartNative app with three synthetic shortcuts: compose, search and
Unicode. It uses no Orb services or account data.

For local source development, create an ignored `pubspec_overrides.yaml` in
this example directory:

```yaml
dependency_overrides:
  quick_actions_kit:
    path: ../
  dartnative:
    path: <DARTNATIVE_SDK>/bin/cache/pkg/dartnative
```

Replace `<DARTNATIVE_SDK>` with your installed SDK directory. DN 1.4.0 injects
its framework override into pubspec.yaml; Pub gives this overrides file priority,
so local development must also retain the framework path here. Keep the file
untracked, and omit it when testing the published registry version.

```sh
dn pub get
dn run -d <device-id>
```

Use an installed, configured DartNative SDK. Register the generated plugins before
runApp, as main.dart does. Host native files come from `dn create --template plugin`;
no delegate/entry-activity customization is required by this plugin.

1. Install shortcuts and long-press the app in the launcher. Verify all three labels.
2. Choose an item; check the last action and activation counter. Repeat the same item.
3. Terminate only this demo process and choose an installed shortcut again. Expect
   exactly one activation after startup.
4. Hot restart through `dn run` (uppercase R), then repeat a shortcut.
5. Clear shortcuts and verify the launcher no longer offers the dynamic entries.

The demo keeps callback results separate from command status so initialization
cannot overwrite a cold-launch result. Native validation evidence and remaining
release/physical-device coverage are recorded in ../VALIDATION.md. The generated
RunnerTests Swift placeholder is not counted as test coverage.
