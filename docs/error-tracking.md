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
- **One-time local setup required**: install `posthog-cli` and run
  `posthog-cli login --host https://eu.i.posthog.com`. Without this the upload
  script silently fails on Release builds.

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

## First-time local setup

These steps are **one-time** per machine. Nothing here needs to be repeated per build.

1. **Install `posthog-cli`** (Homebrew):
   ```sh
   brew install posthog/tap/posthog
   ```

2. **Log in to the EU instance**:
   ```sh
   posthog-cli login --host https://eu.i.posthog.com
   ```
   This opens a browser to authenticate and writes a credential file that
   `upload-symbols.sh` picks up automatically on subsequent Release builds.

3. **Verify** by running a Release build — the build log should show the upload
   script running (not `Skipping dSYM upload for configuration 'Debug'`).

## CI configuration

For a CI environment (no interactive login), export these three env vars in the
build job before the Xcode build step:

| Variable | Value |
|---|---|
| `POSTHOG_CLI_HOST` | `https://eu.i.posthog.com` |
| `POSTHOG_CLI_PROJECT_ID` | PostHog project ID (Settings → Project → ID) |
| `POSTHOG_CLI_API_KEY` | Personal API key (Settings → Personal API keys) |

The `upload-symbols.sh` script reads these vars instead of the local credential
file when they are present.

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

Apple does **not** recompile when distributing to the App Store or TestFlight —
the binary users run is the exact one produced at archive time. This means the
dSYM generated locally during the archive has the same UUID as the binary on
users' devices, and the build-phase upload is sufficient.

> Note: The upload script runs on **every** local build, including archives, even
> when no code has changed. This is expected behavior.
> For builds made on CI (Xcode Cloud, other CI tools) or via bitcode recompilation,
> the build phase does **not** run. Grab the dSYMs from App Store Connect and
> upload them manually (see below).

## Manual dSYM upload

Use this when the build phase didn't run (Xcode Cloud, bitcode recompilation,
or a missed Release build).

```sh
# Single dSYM file or bundle
posthog-cli upload dsym /path/to/SleepingBird.app.dSYM

# From an xcarchive (App Store / TestFlight)
posthog-cli upload dsym /path/to/SleepingBird.xcarchive/dSYMs/SleepingBird.app.dSYM
```

The CLI uses the same local credential from `posthog-cli login`. On a machine
without a login session, pass the three env vars from the CI configuration
section before running the command.

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
