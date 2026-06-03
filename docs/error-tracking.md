# Error Tracking (PostHog)

How crash / exception reporting is wired up in SleepingBird, and why it's set up
the way it is. Read this before touching anything PostHog-related — there are a
few non-obvious gotchas that are easy to "fix" into being broken.

## TL;DR

- Crashes are captured by **PostHog error tracking** (`autoCapture`), configured
  in `AppDelegate` (`SleepingBirdApp.swift`).
- Readable stack traces require **dSYM files** to be uploaded to PostHog. That
  upload is done automatically by a **Run Script build phase** — but **only on
  Release builds**. Debug builds intentionally do not upload.
- So: dev/Debug crashes show up unsymbolicated (raw addresses). Release /
  TestFlight / App Store crashes symbolicate correctly. This is expected.

## What's already set up (don't redo these)

1. **SDK init** — `AppDelegate.application(_:didFinishLaunchingWithOptions:)` in
   `SleepingBird/SleepingBirdApp.swift`:
   ```swift
   let config = PostHogConfig(projectToken: …, host: "https://eu.i.posthog.com")
   config.errorTrackingConfig.autoCapture = true
   PostHogSDK.shared.setup(config)
   ```
   We're on the **EU** PostHog instance.

2. **dSYM upload build phase** — a Run Script phase on the `SleepingBird` target
   (Build Phases tab). Its script is:
   ```sh
   POSTHOG_INCLUDE_SOURCE=1 ${BUILD_DIR%/Build/*}/SourcePackages/checkouts/posthog-ios/build-tools/upload-symbols.sh
   ```
   with an **Input File**:
   ```
   $(DWARF_DSYM_FOLDER_PATH)/$(DWARF_DSYM_FILE_NAME)/Contents/Resources/DWARF/$(EXECUTABLE_NAME)
   ```

3. **Build settings** (Release): `Debug Information Format = DWARF with dSYM File`
   and `ENABLE_USER_SCRIPT_SANDBOXING = NO` (the upload script needs to read the
   dSYM folder).

4. **CLI auth** — done once locally via `posthog-cli login` (EU). The
   `upload-symbols.sh` script bundled with the posthog-ios SPM package uses that
   auth. For CI you'd instead set `POSTHOG_CLI_HOST`, `POSTHOG_CLI_PROJECT_ID`,
   `POSTHOG_CLI_API_KEY`.

## Why it's only on Release (and that's correct)

The `upload-symbols.sh` script **gates itself to Release internally** — on a
Debug build it prints `Skipping dSYM upload for configuration 'Debug'` and exits.
We rely on that built-in check; there is **no** `if [ "$CONFIGURATION" = …]`
wrapper in our build phase because it would be redundant.

Reasons this is the right default:
- Debug builds change constantly; uploading a dSYM on every dev build is noise.
- Debug crashes are debugged live in Xcode (the debugger catches them anyway).
- The builds we actually need symbolicated are the ones users run — all Release.

## The gotchas (the stuff that wasted time, documented so it doesn't again)

- **Reports upload on the NEXT launch, not the crashing run.** The app has to
  relaunch to flush the stored crash.
- **The debugger intercepts the crash.** When run from Xcode, lldb pauses on the
  exception before PostHog's handler runs. Either continue (`c`) past it, or
  untick **Edit Scheme → Run → "Debug executable"** so it runs detached.
- **Unsymbolicated frames (`SleepingBird +0x…`) mean "no matching dSYM uploaded"**
  — not that tracking is broken. Almost always because you crashed a Debug build
  (which never uploads) or a Release build whose dSYM upload hasn't run.

## How symbolication matches across many app versions

Every build embeds a unique **debug UUID**; its dSYM carries the same UUID.
PostHog stores each uploaded dSYM as a *symbol set* keyed by that UUID and picks
the right one per incoming crash. So v1.0, v1.1, TestFlight, App Store builds all
coexist — just make sure each shipped (Release) build's dSYM got uploaded, which
the build phase handles automatically.

> Note: App Store / TestFlight archive builds put dSYMs inside the `.xcarchive`.
> The build-phase upload covers local + CI Release builds. If a build is made via
> Xcode Cloud or bitcode recompilation, grab the dSYMs from App Store Connect and
> upload them with `posthog-cli upload dsym …`.

## How to verify it's working

1. Build & run a **Release** build (Edit Scheme → Run → Build Configuration →
   Release, "Debug executable" off).
2. Build log shows the upload running (not "Skipping…").
3. PostHog → **Error tracking → Symbol sets** lists the new UUID.
4. Trigger a real `NSException`, relaunch, and confirm the event shows real
   file/line frames in PostHog → **Error tracking**.

## Useful links

- iOS error tracking install: https://posthog.com/docs/error-tracking/installation/ios
- Upload dSYMs: https://posthog.com/docs/error-tracking/upload-source-maps/ios
- Stack traces: https://posthog.com/docs/error-tracking/stack-traces
