<img align="right" width="64" height="64" alt="icon_1024" src="https://github.com/user-attachments/assets/5a887d1f-420f-49a9-929d-f6f47c526bfc" />

# Visual Minipro

The missing Mac OS app for [XGecu](http://www.xgecu.com/en/) programmers. 

This is a fork of [Visual Minipro](https://github.com/moozzyk/MiniproUI) by Pawel Kadluczka. It supports the
TL866A, TL866CS, TL866II+, T48, T56 and T76 programmers.

## Features

### Read and write EEPROM contents
https://github.com/user-attachments/assets/223b87c6-2a22-45dd-a9f9-31aff44f878b

### Test 74xx/40xx logic ICs
https://github.com/user-attachments/assets/52823ef8-a25e-41ad-b4cd-3f83759363ea

### Update your programmer's firmware
https://github.com/user-attachments/assets/8b3be8b0-840e-4e8d-b0e7-947bf6cc8379

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

## License 

Visual Minipro is available under the [GNU General Public License]([https://github.com/moozzyk/MiniproUI/blob/main/LICENSE) as it wraps the excellent [`minipro`](https://gitlab.com/DavidGriffith/minipro) tool released under GPL.
