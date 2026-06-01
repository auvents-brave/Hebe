# Hebe

> A production-ready SwiftUI **starting point** for a new Apple app. Fork it and
> build your own product on top of solid foundations, instead of wiring the same
> plumbing from scratch every time.

Hebe is a small but complete inventory app whose real purpose is to be a
template: it demonstrates, in one place, how to ship a single codebase across
every Apple platform with a modern Xcode project, SwiftData + iCloud, App Intents,
Spotlight, widgets, Live Activities, sharing and more — all wired and working.

Every Apple platform lives in **one single target** (`HebeApp`) with a modern
multiplatform Xcode project. The **only** exception is the Watch: `HebeWatch` is a
separate target, because a watch app is embedded inside the iPhone app.

![Swift](https://img.shields.io/badge/Swift-6.0+-orange?logo=swift)

[![CodeQL](https://github.com/auvents-brave/Hebe/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/codeql.yml)
[![DocC](https://img.shields.io/badge/DocC-available-brightgreen)](https://auvents-brave.github.io/Hebe/)

Documentation is available directly in Xcode and [online](https://auvents-brave.github.io/Hebe/).

## Supported platforms

A single multiplatform target ships to nine destinations — six native platforms,
Mac Catalyst, and two "Designed for iPad" runtimes.

| # | Device | OS | Mode |
|---|---|---|---|
| 1 | iPhone | iOS 17.0+ | Native |
| 2 | iPad | iPadOS 17.0+ | Native |
| 3 | Mac | macOS 14.0+ | Native |
| 4 | Mac | — | Mac Catalyst |
| 5 | Mac | — | Designed for iPad |
| 6 | Apple TV | tvOS 17.0+ | Native |
| 7 | Apple Watch | watchOS 11.0+ | Native (separate `HebeWatch` target) |
| 8 | Apple Vision Pro | visionOS 26.0+ | Native |
| 9 | Apple Vision Pro | — | Designed for iPad |

**Minimum OS versions:** iOS / iPadOS 17.0 · macOS 14.0 · tvOS 17.0 · watchOS 11.0 · visionOS 26.0.

## Build status

| Platform | CI |
|---|---|
| ![iOS](https://img.shields.io/badge/iOS-111111?logo=apple&logoColor=white) | [![iOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-ios.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-ios.yml) |
| ![iPadOS](https://img.shields.io/badge/iPadOS-111111?logo=apple&logoColor=white) | [![iPadOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-ipados.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-ipados.yml) |
| ![macOS](https://img.shields.io/badge/macOS-111111?logo=apple&logoColor=white) | [![macOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-macos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-macos.yml) |
| ![Mac Catalyst](https://img.shields.io/badge/Mac_Catalyst-111111?logo=apple&logoColor=white) | [![Mac Catalyst](https://github.com/auvents-brave/Hebe/actions/workflows/apple-maccatalyst.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-maccatalyst.yml) |
| ![tvOS](https://img.shields.io/badge/tvOS-111111?logo=apple&logoColor=white) | [![tvOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-tvos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-tvos.yml) |
| ![watchOS](https://img.shields.io/badge/watchOS-111111?logo=apple&logoColor=white) | [![watchOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-watchos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-watchos.yml) |
| ![visionOS](https://img.shields.io/badge/visionOS-111111?logo=apple&logoColor=white) | [![visionOS](https://github.com/auvents-brave/Hebe/actions/workflows/apple-visionos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/apple-visionos.yml) |
| Code analysis | [![CodeQL](https://github.com/auvents-brave/Hebe/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/codeql.yml) |
| Documentation | [![Documentation](https://github.com/auvents-brave/Hebe/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Hebe/actions/workflows/docs.yml) |

## Architecture

Hebe follows the **MV (Model–View)** pattern: SwiftUI views observe SwiftData
models and `@MainActor` services directly — there is no view-model layer. The
source is organised into four folders:

| Folder | Responsibility |
|---|---|
| `App` | App entry points and scene / window configuration. |
| `Models` | SwiftData models (`Furniture`, `Thing`, and their `FurnitureThing` join). |
| `Services` | Persistence, snapshot publishing, indexing, notifications — the behaviour the views drive. |
| `Views` | SwiftUI views. |

## Auto-incrementing build number

The build number increments on every build. A pre-action on the `HebeApp` scheme
runs `Scripts/bump_build_number.sh`, which bumps `CURRENT_PROJECT_VERSION` in
`Config/Version.xcconfig` — no manual versioning, and no churn in `project.pbxproj`.

## Features

| Feature | Where | Notes |
|---|---|---|
| App Intents · Shortcuts · Siri | All | Inventory queries exposed as App Intents with spoken phrases. |
| Spotlight indexing | iOS · iPadOS · macOS · visionOS | Advanced `IndexedEntity` semantic indexing on iOS 18 / macOS 15+, with a classic `CSSearchableItem` fallback on iOS 17.0 / macOS 14.0. Deep-links back into the app via an `OpenIntent`. |
| Widgets | iOS · iPadOS · macOS · visionOS · watchOS | Every available widget family, including on the Mac. |
| Live Activity | iPhone | Lock Screen activity plus the Dynamic Island "bubble". |
| Watch complications | watchOS | Accessory widget families. |
| Share to / from the app | iOS · iPadOS · macOS | A Share extension to receive inventories, and sharing out — on the Mac too. |
| File import / export | macOS | Classic open / save panels with an XML / ZIP format choice. |
| Context menus | macOS · iPad | Right-click / long-press row actions. |
| Drag & drop | iOS · iPadOS · macOS · visionOS | Drag rows out as files; drop files in to import. |
| Notifications | All | Local notifications with configurable thresholds. |
| Localization | All | English and French, ready for more. |
| SwiftData + iCloud | All | Persistence synced across devices over CloudKit. |
| Preferences synced over iCloud | All | Settings follow the user across devices. |
| Menu bar item | macOS | A status item showing live inventory stats. |

## Getting started

```bash
open Hebe.xcodeproj
```

The project depends on its Swift packages **remotely** (Euryale, Stheno,
ZIPFoundation, swift-log), so `Hebe.xcodeproj` resolves and builds on its own —
on a fresh clone, on CI, for anyone. They resolve automatically.

**Optional — local package editing.** If you also check out
[Euryale](https://github.com/auvents-brave/Euryale) and
[Stheno](https://github.com/auvents-brave/Stheno) as **siblings** (`../Euryale`,
`../Stheno`), create a local workspace (it is intentionally **not committed** —
`Hebe.xcworkspace/` is git-ignored) adding `Hebe.xcodeproj` plus the two sibling
package folders. The local copies then *override* the remote dependencies by
package identity, so you can edit the packages and the app together. CI always
builds the project (`-project Hebe.xcodeproj`), so it stays on the published packages.

Then set your own signing team and bundle identifiers to run on a device.

## Forking as a template

1. Create a new repository from this one.
2. Update the badge URLs and the GitHub Pages base path if you rename the repo
   (they currently point at `auvents-brave/Hebe`).
3. Configure signing, bundle identifiers and provisioning profiles.
4. Rename the models, views and services to fit your own domain.

## Continuous integration

GitHub Actions builds the two targets (`HebeApp`, `HebeWatch`) across every Apple
platform, analyses the code with CodeQL, and publishes the DocC documentation to
GitHub Pages. The workflows live in `.github/workflows/`.
