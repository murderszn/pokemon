# PocketBoy iOS app

This directory contains the native SwiftUI iPhone app and its SameBoy Core bridge. No ROM or Nintendo artwork is bundled. Import a ROM you own from Files when the app provides its import flow.

## Open and build

The checked-in project uses synchronized source groups and requires Xcode 16 or newer. Initialize the pinned SameBoy submodule, then open the project:

```sh
git submodule update --init --recursive
cd ios
open PocketBoy.xcodeproj
```

`project.yml` is also checked in as the XcodeGen specification for regenerating the project when the target configuration changes. If you use it, install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run `xcodegen generate` from this directory.

Select an iPhone simulator or connected iPhone in Xcode and run the `PocketBoy` scheme. Set your Apple development team in the target's Signing & Capabilities settings for a physical device.

The project compiles only `Vendor/SameBoy/Core` and this app's bridge. SameBoy is pinned to upstream v1.0.3. Its upstream iOS frontend is deliberately not included; the upstream repository identifies an additional distribution condition for files under its `iOS` directory. The Core license is in `Vendor/SameBoy/LICENSE`.

The bridge includes the 256-byte Pocket boot program assembled from SameBoy's `BootROMs/mgb_boot.asm` under its Expat license. It is generated into `CoreBridge/PocketBootROM.h`; the app does not use a Nintendo boot ROM. The game ROM is selected by the user at runtime and must not be added to the project or app bundle.

## Current stage

The first runnable stage now includes a SwiftUI Game Boy Pocket shell, SameBoy's C Core, touch controls, external controller input, Files ROM import into the app's Documents/ROMs directory, audio output, battery saves, and per-ROM save states. The menu includes palette, sound, haptics, button size, and control spacing settings. The app keeps its saves separate from the Node/serverboy game and does not share its save format.

The C bridge and every upstream Core C file passed a local Clang syntax check with the SameBoy version defines. A Linux smoke test ran the bridge with the local Pokémon Red ROM for 1,000 frames and successfully saved and reloaded emulator state. This workspace runs Linux and does not include Xcode or the Apple SDK, so the iOS app has not yet been built in Xcode, run in a simulator, or tested on a physical iPhone. Do those checks on macOS before treating this stage as device-verified.
