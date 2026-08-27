# CLAUDE.md

## Project overview
Visual Minipro Lab is a macOS SwiftUI app for XGecu programmers, forked from Pawel Kadluczka's Visual Minipro. The Xcode project is `Visual Minipro.xcodeproj` and the main target is **Visual Minipro**.

The shipped app is named **Visual Minipro Lab** (`APP_PRODUCT_NAME` in `Config/Base.xcconfig`), while the target, the scheme and the Swift module stay `Visual Minipro` - `PRODUCT_MODULE_NAME` is pinned so tests keep importing `Visual_Minipro`.

## Key paths
- App sources: `MiniproUI/`
- App entry point: `MiniproUI/MiniproUIApp.swift`
- Minipro integration: `MiniproUI/Minipro/`
- Unit tests: `MiniproUITests/`
- UI tests: `MiniproUIUITests/`

## Dependencies
`minipro` and `libusb` are git submodules under `external/`. `Scripts/prepare-deps.sh` builds them and
places `minipro`, `libusb-1.0.0.dylib`, `infoic.xml`, `infoic_0.7.4.xml`, and `logicic.xml` at the
repository root, where the Xcode project picks them up (all five are git-ignored). The
`Prepare minipro dependencies` build phase runs it first on every build and exits early when the
submodules have not moved. Run it by hand with `--force` after changing the script, `--arch <arch>` to
build a single slice. It needs `autoconf`, `automake`, `libtool`, and `pkg-config` from Homebrew.

## Signing and identity
Identity and signing live in `Config/Base.xcconfig` (project level). `PRODUCT_BUNDLE_IDENTIFIER` is
`$(ORG_IDENTIFIER).VisualMinipro`; builds are ad-hoc signed (`CODE_SIGN_IDENTITY = -`, manual style, no
team) so they run locally without a developer account. `Config/Local.xcconfig` is an optional,
git-ignored override included by `Base.xcconfig`. Do not put signing settings back on the targets - a
target level setting beats the project level xcconfig.

The `os.Logger` subsystem follows the bundle identifier via `Logger(category:)` in
`MiniproUI/Utilities/Logging.swift`; never hardcode a subsystem.

The embedded `minipro` helper is re-signed by the `Sign minipro` build phase (`Scripts/sign-minipro.sh`)
with `minipro.entitlements`, so it inherits the app's sandbox and its USB access. That phase must stay
last, after `Embed minipro` and before Xcode signs the app bundle.

## App icon
`Design/AppIcon-base-1024.png` is the socket artwork without the Lab badge. `Scripts/make-app-icon.swift`
draws the badge onto it and rewrites every size in `MiniproUIIcon.appiconset` and
`VisualMiniproIconImage.imageset`; run it after changing either. Never edit the generated PNGs by hand,
and keep the base file free of the badge.

## Generated build info
`MiniproUI/BuildInfo.swift` holds the commit details the info screen shows. It is git-ignored and written
by `Scripts/make-build-info.sh`, which the `Generate build info` build phase runs. `MiniproUI` is a
synchronized folder group, so Xcode decides what to compile when it loads the project: on a clone that
has never been built the file does not exist yet, the target is missing it, and the build fails on
`getGitBranch` and friends however the build phase later writes it. Run the script once before the first
build - CI does exactly that.

## Build
```
xcodebuild -project "Visual Minipro.xcodeproj" -scheme "Visual Minipro" -configuration Debug build
```

## Tests
```
xcodebuild -project "Visual Minipro.xcodeproj" -scheme "Visual Minipro" test
```
UI tests require a simulator. Unit tests do not.

## CI and releases
`.github/workflows/ci.yml` builds and analyzes the app on every push and pull request. Pushing a version
tag (`2.0.0` or `v2.0.0`, matching `MARKETING_VERSION` - the workflow fails if it does not) also builds a
universal Release app, packs it with `Scripts/make-dmg.sh`, and publishes a GitHub release with the disk
image attached. Releases carry the ad-hoc signature, so users approve the app once on first launch.

`.github/actions/minipro-deps` builds the submodule dependencies universal and caches them on the two
submodule commits plus the hash of `prepare-deps.sh`; the in-Xcode build phase then exits early.

## Architecture
The app is layered:

```
SwiftUI Views → MiniproAPI → MiniproInvoker → minipro CLI binary
```

- **`minipro`** is a bundled CLI binary (not a system tool). `MiniproInvoker` locates it via `Bundle.main.path(forAuxiliaryExecutable:)` and runs it via `ProcessInvoker`.
- **`MiniproInvoker.invoke(...)`** returns an `InvocationResult` (`exitCode`, `stdOut: Data`, `stdErr: String`).
- **`MiniproAPI`** is the public interface for all programmer operations. Each method invokes `MiniproInvoker` and delegates parsing to a `ResponseProcessor`.
- **ResponseProcessors** (`MiniproUI/Minipro/ResponseProcessors/`) parse `InvocationResult` and throw typed `MiniproAPIError` values. `ensureNoError(_:)` in `ReponseProcessorUtils.swift` handles common error patterns (programmer not found, device not found, IO error, invalid chip ID, etc.) and should be called first in every processor.

## Adding a new programmer operation
1. Add a `static func` to `MiniproAPI.swift`.
2. Create `XxxProcessor.swift` in `MiniproUI/Minipro/ResponseProcessors/`. Call `ensureNoError` first, then parse the result.
3. Add corresponding `MiniproAPIError` cases if needed.
4. Add a SwiftUI view in `MiniproUI/` if the operation needs UI.
5. Add unit tests in `MiniproUITests/` mirroring the source path.

## Tests
Tests use **Swift Testing** (not XCTest): `@Test` functions and `#expect` / `#require` macros.
The test module import is `@testable import Visual_Minipro` (underscore, not space).
Test files mirror the source tree structure under `MiniproUITests/`.

## Code style
- Format with Xcode's built-in formatter (Ctrl+Shift+I). Do not use external formatters.
- Prefer minimal SwiftUI changes; avoid unrelated formatting churn.
- Keep entitlements files in sync with any new hardware or file access needs.
