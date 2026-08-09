# 0012 — App Check: debug provider in Debug, App Attest in Release

- **Date:** 2026-08-09
- **Status:** Accepted
- **Area:** `ArperBirdApp.swift`, `ArperBird.entitlements`, `ArperBird-Release.entitlements`

## Context

Firebase App Check protects the Firebase AI Logic backend (used by
`AiSchemaCompletion`) from unauthorized clients. It needs an `AppCheckProviderFactory`
that vends a proof-of-authenticity token per app instance.

The only provider that works in production is **App Attest**, Apple's
hardware-backed attestation. But App Attest:

- **Never works on the Simulator** — there's no Secure Enclave to attest.
- **Fails on plain Xcode debug builds even on a real device**, because the
  attestation environment (`development` vs `production`) is baked into the
  build's entitlements and must match what the client asks for.

`ArperBirdApp` originally always used `AppAttestProvider`, so every debug run —
simulator or device — hit `firebaseappcheck.googleapis.com` and got back
`403 App attestation failed`. Firebase AI calls didn't hard-fail on this (App
Check is enforced per-API in the console), but it's noisy and would bite
immediately if enforcement were ever tightened.

## Decision

Split by build configuration, matching [Firebase's own guidance](https://firebase.google.com/docs/app-check/ios/debug-provider):

**1. Provider factory** (`ArperBirdApp.swift`) — branches on `#if DEBUG`:

```swift
class AppCheckReleaseProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if DEBUG
      return AppCheckDebugProvider(app: app)
    #else
      return AppAttestProvider(app: app)
    #endif
  }
}
```

**2. Entitlements — one file per build configuration**, wired in
*Build Settings → Code Signing Entitlements*:

| Build config | `CODE_SIGN_ENTITLEMENTS`            | `appattest-environment` |
|--------------|--------------------------------------|--------------------------|
| Debug        | `ArperBird/ArperBird.entitlements`         | `development`            |
| Release      | `ArperBird/ArperBird-Release.entitlements` | `production`             |

**3. Firebase console — register a debug token.** `AppCheckDebugProvider`
prints a token to the Xcode console on first run:

```
Firebase App Check Debug Token: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
```

Add it under *Firebase console → App Check → Apps → ArperBird (iOS) → Manage
debug tokens*. Without this the debug provider still gets rejected, just with
a clearer error. Each machine (your Mac, a teammate's, CI) needs its own
token registered — don't share one, and don't commit it.

## Why this split and not something simpler

**Why not always use App Attest and just accept the 403 in debug?** Fine
today because nothing enforces App Check yet, but it means the *only* build
config we can test the pipeline against is a signed Release archive on a
physical device — i.e. never, in normal iteration.

**Why not always use the debug provider, even in Release?** It's an
unauthenticated static token — anyone who extracts it from a build can call
the backend as if they were the app. It exists for CI/dev, not shipping.

## The gotcha: running *Release* from Xcode locally

Xcode's Run button can build the **Release** configuration (Product → Scheme →
Edit Scheme → Run → Build Configuration), e.g. to sanity-check
release-only behavior before archiving. If you do this on a plain
development-provisioned build:

- The binary is signed for App Attest's `production` environment
  (`ArperBird-Release.entitlements`), but a plain `xcodebuild`/Xcode-run install
  isn't the App Store/TestFlight-signed artifact Apple's production
  attestation service expects → App Attest **fails**, same 403 as before.

**To run Release locally and have App Check succeed, temporarily flip
`ArperBird-Release.entitlements`'s `appattest-environment` to `development`**
— then it behaves like the Debug entitlements and validates against Apple's
dev attestation service instead.

**Revert it to `production` before archiving for TestFlight/App Store.** An
archive shipped with `development` App Attest will fail attestation for real
users, since the App Store's servers only recognize `production` tokens.

The only build that exercises the real, unmodified production path end-to-end
is an actual TestFlight upload — that's the first place to confirm App Check
is genuinely working, not a local Release run.

## Consequences

- Debug/simulator runs get a valid App Check token via the debug provider, no
  more App Attest 403 noise.
- Release archives (App Store/TestFlight) still use real App Attest,
  unchanged.
- Anyone running Release locally from Xcode must remember to flip
  `ArperBird-Release.entitlements` to `development` first, and flip it back
  before archiving — easy to forget, which is why this file exists.
