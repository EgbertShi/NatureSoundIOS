# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

NatureSound (display name **清籁**, bundle id `com.egbert.NatureSound`) is a SwiftUI ambient-sound / white-noise app for iOS, iPadOS, macCatalyst, and visionOS. Users mix up to 7 looping nature sounds (real `.m4a` files, not synthesized), pick from preset "scenes", start a sleep timer, and enter a full-screen "standby" clock mode. There are no third-party dependencies — only Apple frameworks (AVFoundation, CoreLocation, ActivityKit, MediaPlayer, UIKit).

The UI is in Chinese; user-facing strings (sound names, categories, scene names, settings labels) are written directly in code, not localized via `.strings` files. Match this convention when adding content.

## Build & run

The project is an `.xcodeproj` with **no Swift Package dependencies** and the target uses a `PBXFileSystemSynchronizedRootGroup`. Consequences:

- **Adding/removing/renaming a `.swift` file anywhere under `NatureSound/` is picked up by the target automatically — do NOT hand-edit `project.pbxproj`** (it has no per-file references). Build settings live there only at the target/project level.
- There is no shared `.xcscheme` file; the scheme `NatureSound` is auto-generated from the target name.

```bash
# Build (simulator). Deployment target is iOS 26.2 → requires Xcode 26.x.
xcodebuild -scheme NatureSound -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for connected device
xcodebuild -scheme NatureSound -destination 'generic/platform=iOS' build

# Open in Xcode for running/debugging
open NatureSound.xcodeproj
```

There are **no tests and no lint configuration** (no XCTest targets, no `.swiftlint.yml`). Verify changes by building and running in the simulator/device.

Key build settings: `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, `SWIFT_VERSION = 5.0`, `DEVELOPMENT_TEAM = SHW5PYNF5Z`, background mode `audio` (set via `INFOPLIST_KEY_UIBackgroundModes`), display name 清籁. `GENERATE_INFOPLIST_FILE = YES` — Info.plist is generated from build settings, there is no Info.plist file on disk.

## Architecture

### State ownership: shared `@Observable` managers, passed by reference

All state lives in `@Observable final class` managers, created **once** as `@State` in `ContentView` and passed down into pages by reference. They are singletons-in-practice — never `@State`-create the same manager in a child view, and never copy them; always accept the existing instance as an `let` parameter. The set, defined in `Managers/` and `Audio/`:

- **`AudioManager`** (`Audio/AudioManager.swift`) — owns `activePlayers: [SoundPlayer]` (max 7), `masterVolume`, and the Now Playing / `MPRemoteCommandCenter` surface. Handles `AVAudioSession` interruption, route-change, and media-services-reset by re-resuming players. Call `resumeAll()` when returning to foreground.
- **`SoundPlayer`** (`Audio/SoundPlayer.swift`) — one `AVAudioPlayer` per active sound, `numberOfLoops = -1`, fades in/out via `setVolume(_:fadeDuration:)`. Audio files are loaded from `Bundle.main` at `Sounds/<category.rawValue>/<fileName>.m4a` (subdirectory fallback to bundle root). Sounds are real audio files; do not introduce procedural synthesis.
- **`SceneManager`** — persists user scenes to `UserDefaults` key `NatureSound_UserScenes` as JSON. Presets live in `ScenePreset.allPresets` (static); `UserScene` is the Codable user-created counterpart.
- **`TimerManager`** — sleep timer; in the final `fadeOutSeconds` (30s) it sets `isFadingOut` and exposes `fadeOutProgress`, which `ContentView` pipes into `AudioManager.applyFadeOut(progress:)`. Preset minutes in `TimerManager.presetMinutes`.
- **`LiveActivityManager`** — surfaces the running timer as a Dynamic Island / Lock Screen Live Activity (`NatureSoundTimerAttributes`). Gated on `ActivityAuthorizationInfo().areActivitiesEnabled`.
- **`WeatherService`** — `CLLocationManager` + open-meteo.com API (WMO weather codes). 30-min freshness window; cache in `UserDefaults`. Drives greeting text, recommended sound IDs, and ambiance image name (all in `DayPeriod`).
- **`VideoManager`** — parses `Resources/videos.json` (OSS base URL + per-scene video/thumbnail paths). Currently only thumbnails are used (featured scene card backgrounds via `AsyncImage`); `LoopingVideoPlayer` (`AVQueuePlayer` + `AVPlayerLooper`) is scaffolded for future looped-video backgrounds.
- **`OrientationManager`** — programmatic rotation for standby landscape mode. Cooperates with `AppDelegate.orientationLock` (the `UIApplicationDelegateAdaptor`), which is the source of truth for `supportedInterfaceOrientations`. Use `restorePortrait()` on standby exit.

`ContentView` wires these together: a 3-tab `TabView` (声音/场景/我的) + an overlay `MiniPlayerBar` shown when `audioManager.activeCount > 0`, presenting `PlayerPage`, `StandbyView` as `fullScreenCover`s and `SettingsPage` as a `sheet`. `scenePhase` → `audioManager.resumeAll()`; `timerManager.fadeOutProgress` → `applyFadeOut`.

### Standby mode (`Views/Standby/`)

`StandbyView` is a full-screen clock experience, forced to `.dark` color scheme, with the idle timer disabled and `UIScreen.main.brightness` captured/restored. It picks one of four clock styles (`ClockStyle`: digital/dial/minimal/split), runs a breathing-glow `StandbyBackground`, auto-hides controls (`AutoHideDuration`), and can rotate to landscape via `OrientationManager`. All standby preferences are `@AppStorage` keys prefixed `standby_` (defined in `StandbyView`). Sub-views are split across `StandbyClocks.swift`, `StandbyBackground.swift`, and focused control files: `StandbyMixerPanel.swift`, `StandbyMasterControlPanel.swift`, `StandbyTimerPanel.swift`, `StandbyClockStylePanel.swift`, `StandbyScenePanel.swift`, `StandbyToolBar.swift`, and `StandbyTopBar.swift`; `StandbyPanelBackground.swift` provides their shared panel background. `mode: StandbyMode` (`.immersive` / `.timer`) controls whether the timer ring shows.

### Theming

`Utils/Theme.swift` is the single source of color truth — an `enum Theme` of `static` members. Many helpers take a `ColorScheme`, but note the app pins `.preferredColorScheme(.light)` in `ContentView` and `.dark` in `StandbyView`, so dark-mode variants are largely unused in practice. `Color(hex:)` (`Utils/ColorExtensions.swift`) accepts 3/6/8-char hex and is used everywhere — prefer `Theme` constants or `Color(hex:)` over raw `Color` literals. Sound/category colors are defined inline on `SoundItem` / `SoundCategory` in `Models/SoundItem.swift`.

### Platform guards

Audio-session, `MPRemoteCommandCenter`, `UIScreen`, `UIDevice`, and orientation code is wrapped in `#if os(iOS)` because the target also builds for macCatalyst and visionOS. When adding UIKit/AVFoundation code, check whether it needs the same guard.

## Conventions

- **Comments are in Chinese** and use `// MARK: -` section headers extensively. Match the language and the `MARK:` style when editing existing files.
- Every model/manager file opens with the standard Xcode header comment + a `// MARK: -` describing the type. Preserve this when adding new files.
- File dates in headers (`Created by egbert on 2026/7/…`) are authored manually, not generated — don't worry about keeping them current.
- Persistence is `UserDefaults` for everything (user scenes, weather cache, video-path index, standby prefs, `hasSeenWelcome`). There is no Core Data / SwiftData / file-based store.
- `static let allSounds` / `allPresets` on the model types are the canonical collections used by every page; adding a sound or scene means editing these arrays (and, for sounds, adding the matching `.m4a` under `Sounds/<category>/`).
