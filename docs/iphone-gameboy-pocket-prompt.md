# iPhone Game Boy Pocket emulator app prompt

Build a native Swift iPhone app that lets me play my own Pokémon Red ROM offline. The experience should evoke my silver Game Boy Pocket: a large, crisp game screen above a comfortable D-pad, A and B buttons, and Start and Select below.

## Phase 1 — app foundation

Create an Xcode project with SwiftUI. Integrate the open-source SameBoy **Core** through a small C-to-Swift bridge. Import a `.gb` ROM through the Files picker and store it in the app’s private documents area. Do not bundle a ROM or copyrighted Nintendo artwork. Launch the ROM, render its 160×144 output at the correct aspect ratio, play audio, and support battery saves. Make a working emulator before polishing the shell.

## Phase 2 — Pocket interface

Design a portrait layout inspired by the silver Game Boy Pocket: light silver body, dark screen bezel, subtle green monochrome display option, cross-shaped D-pad on the left, A/B on the right, and small angled Start/Select buttons. Keep the game screen prominent and all controls clear of the iPhone’s safe areas. Adapt sizes to small and large iPhones.

Touch controls must support holding a direction, sliding between directions, simultaneous direction-plus-button input, and immediate release when a finger lifts or the app loses focus. Add optional light haptics, adjustable button size and position, and external controller support.

Add an in-game menu for resume, save state, load state, display palette, sound, and control settings. Preserve game progress when the app backgrounds. Keep emulation and rendering smooth without requiring this project’s Node server or an internet connection.

Work in small, runnable stages. For each stage, show the files changed, how to build in Xcode, and what to test on a physical iPhone. Start by creating the Xcode project and getting a ROM to boot; then build the Pocket controls and visual design.

## Implementation notes

SameBoy's reusable core is separate from its existing iOS app folder, which has an additional distribution restriction. Review the [SameBoy source and license](https://github.com/LIJI32/SameBoy) before distributing the app.

SameBoy save states and this project's serverboy `saves/player.json` use different formats, so the first iPhone version should start a separate game.
