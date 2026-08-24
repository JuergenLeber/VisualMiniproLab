<img align="right" width="64" height="64" alt="icon_1024" src="https://github.com/user-attachments/assets/5a887d1f-420f-49a9-929d-f6f47c526bfc" />

# Visual Minipro

The missing Mac OS app for [XGecu](http://www.xgecu.com/en/) programmers. 

This is a fork of [Visual Minipro](https://github.com/moozzyk/MiniproUI) by Pawel Kadluczka. It supports the
TL866A, TL866CS, TL866II+, T48, T56 and T76 programmers.

## Features

- Read and write EEPROM contents
- Test 74xx/40xx logic ICs
- Update your programmer's firmware

## Added in this fork

### See where the chip goes in the socket

The chip details now show how to place the chip, the way the original Xgpro software does:

- **Adapter and ICSP pictures.** Chips that need an adapter or in-circuit wiring show the picture for
  the connected programmer, taken from the Xgpro software bundle you install for the algorithms. The
  pictures stay on your Mac and are never redistributed with the app.
- **A drawn *Location in Socket* diagram** for chips that have no picture: the chip sits at the bottom of
  the ZIF socket with the notch pointing up, and the diagram names the socket pin the chip's pin 1 goes
  in. PLCC chips and adapters are drawn through the footprint of the adapter they plug into, and the
  adapter Xgpro asks for (for example `T76_F48_05-001`) is named below the diagram.

A diagram is only drawn where the footprint is unambiguous. A PLCC44 chip, for instance, ships as both a
PLCC44-DIP40 and a PLCC44-DIP44 adapter, so those chips keep showing the picture alone rather than a
guess.

### Building from source

`minipro` and `libusb` are git submodules, built automatically by the Xcode project. See
[How to build it](#how-to-build-it).

## How to build it

You can build the app yourself from this repository. Visual Minipro bundles the
[`minipro`](https://gitlab.com/DavidGriffith/minipro) tool and its
[`libusb`](https://github.com/libusb/libusb) dependency, both of which are git submodules under `external/`
and are built by `Scripts/prepare-deps.sh`.

```
git clone --recurse-submodules https://github.com/JuergenLeber/VisualMinipro.git
brew install autoconf automake libtool pkg-config
```

The `Prepare minipro dependencies` build phase runs the script on every build, so opening the project in
Xcode and hitting Run is enough. The script can also be run on its own:

```
./Scripts/prepare-deps.sh              # universal arm64 + x86_64
./Scripts/prepare-deps.sh --arch arm64 # single architecture
./Scripts/prepare-deps.sh --force      # rebuild even if up to date
```

It places five git-ignored files at the repository root, all of them referenced by the Xcode project:

| File | Source | Bundled as |
| --- | --- | --- |
| `minipro` | `external/minipro` | `Contents/MacOS/minipro` |
| `libusb-1.0.0.dylib` | `external/libusb` | `Contents/Frameworks/libusb-1.0.0.dylib` |
| `infoic.xml` | `external/minipro` | resource, passed as `--infoic` |
| `infoic_0.7.4.xml` | `external/minipro` at tag `0.7.4` | resource, used by the *legacy infoIC* setting |
| `logicic.xml` | `external/minipro` | resource, found via the working directory |

To move to a newer `minipro`, update the submodule and commit the new pointer:

```
git -C external/minipro checkout master && git -C external/minipro pull
git add external/minipro
```

The next build rebuilds the dependencies automatically.

### Signing and identity

Local builds are ad-hoc signed and need no Apple Developer account. Identity and signing come from
[`Config/Base.xcconfig`](Config/Base.xcconfig), so the bundle identifier is
`$(ORG_IDENTIFIER).VisualMinipro`.

To sign with your own account, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` — that
file is git-ignored — and fill in what you need:

```
ORG_IDENTIFIER = com.example
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY[sdk=macosx*] = Apple Development
```

Anything left out keeps the value from `Base.xcconfig`, and `xcodebuild DEVELOPMENT_TEAM=...` overrides
both for one-off builds. Note that a bundle identifier belongs to a single Apple Developer team, so
distributing the app requires an identifier of your own.

## License 

Visual Minipro is available under the [GNU General Public License]([https://github.com/moozzyk/MiniproUI/blob/main/LICENSE) as it wraps the excellent [`minipro`](https://gitlab.com/DavidGriffith/minipro) tool released under GPL.
