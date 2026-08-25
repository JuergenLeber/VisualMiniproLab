---
argument-hint: "[version]"
---

Bump the Visual Minipro Lab version, commit, and tag. Without an argument the patch number is
incremented; `$ARGUMENTS` sets the version explicitly, e.g. `/bump-version 2.0.0`.

## Step 1: Read the current version

```bash
grep "MARKETING_VERSION" "Visual Minipro.xcodeproj/project.pbxproj" | head -1
```

Extract the current `MARKETING_VERSION` (e.g. `1.5.5`) and `CURRENT_PROJECT_VERSION` from:

```bash
grep "CURRENT_PROJECT_VERSION\|MARKETING_VERSION" "Visual Minipro.xcodeproj/project.pbxproj" | head -4
```

Only look at the first two occurrences of each — they are the Debug and Release configs for the main app target. The other occurrences belong to test targets and should not be changed.

Compute:
- `new_version`: `$ARGUMENTS` when one was given, otherwise the current version with its patch
  component incremented by 1 (e.g. `1.5.5` → `1.5.6`). A given version must be three numbers separated
  by dots and must be higher than the current one - stop and say so if it is not.
- `new_build`: increment `CURRENT_PROJECT_VERSION` by 1 (e.g. `13` → `14`), whichever way the version
  was determined. App Store Connect rejects a build number that does not climb.

## Step 2: Update the project file

In `Visual Minipro.xcodeproj/project.pbxproj`, update the first two occurrences of each:
- `MARKETING_VERSION = <old>;` → `MARKETING_VERSION = <new_version>;`
- `CURRENT_PROJECT_VERSION = <old>;` → `CURRENT_PROJECT_VERSION = <new_build>;`

Verify the changes:

```bash
grep -n "CURRENT_PROJECT_VERSION\|MARKETING_VERSION" "Visual Minipro.xcodeproj/project.pbxproj"
```

Confirm the first two occurrences of each are updated and the test target configs are unchanged.

## Step 3: Commit

```bash
git add -A && git commit -m "chore: bump version to <new_version>"
```

## Step 4: Tag

```bash
git tag -a <new_version> -m "<new_version>"
```
