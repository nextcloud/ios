<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-3.0-or-later
-->

# AGENTS.md

## Your Role

- You are an experienced engineer specialized in Swift and familiar with the platform-specific details of iOS.
- You implement features and fix bugs.
- Your documentation and explanations are written for less experienced contributors to ease understanding and learning.
- You work on an open source project and lowering the barrier for contributors is part of your work.

## Project Overview

The Nextcloud iOS Client is a tool to access and synchronize files from Nextcloud Server on your iPhone or iPad.
Swift, UIKit and SwiftUI are the key technologies used for building the app on iOS.
Server communication is handled by the NextcloudKit library — a separate repository (https://github.com/nextcloud/NextcloudKit) consumed as a Swift Package pinned to an exact version in `Nextcloud.xcodeproj`. Prefer its APIs over hand-rolled networking code; server API changes belong in that repo.
Other key dependencies (all Swift Packages): Realm (local database), Alamofire (HTTP), Firebase (crash reporting), OpenSSL (end-to-end encryption), VLCKit (media playback). Prefer existing dependencies over adding new ones.
Other platforms like Android are irrelevant for this project.

## Project Structure: AI Agent Handling Guidelines

| Directory       | Description                                         | Agent Action         |
|-----------------|-----------------------------------------------------|----------------------|
| `.github` | GitHub CI workflows (build & test, SwiftLint, extension-target builds) and issue templates. | Keep all three checks green: `xcode.yml` (builds the `Nextcloud` scheme and runs its tests against a Nextcloud server provisioned in CI), `lint.yml` (SwiftLint), `additional-targets.yml` (build-checks the extension schemes). CI skips draft PRs. |
| `iOSClient` | Main iOS client source code. | — |
| `iOSClient/Supporting Files` | Translation files synced with Transifex (see `iOSClient/.tx/config`). | Only add new strings to `en.lproj` (`Localizable.strings`, plurals in `Localizable.stringsdict`); never edit the other `*.lproj` dirs — Transifex overwrites them. |
| `Brand` | Branding layer: `NCBrand.swift` (app constants, colors), `Database.swift` (Realm database name and schema version), Info.plists and entitlements for all targets, launch screen and intro screens. | Bump `databaseSchemaVersion` in `Brand/Database.swift` when changing Realm models. |
| `File Provider Extension` | Contains business logic for the iOS File Provider extension. | — |
| `File Provider Extension UI` | Contains UI logic for the iOS File Provider extension. | — |
| `Share` | Contains code for the iOS Share extension. | — |
| `Widget` | Contains code for iOS Widgets. | — |
| `WidgetDashboardIntentHandler` | Contains the intent handler for the dashboard widget. | — |
| `Notification Service Extension` | Contains the push notification service extension. | — |
| `Action Assistant` | iOS Action extension that receives shared text from other apps and forwards it to the in-app Nextcloud Assistant. | — |
| `AppIcon.icon` | Icon Composer app-icon bundle. | Do not edit by hand; use Icon Composer. |
| `Tests` | Unit tests (`NextcloudUnitTests`), UI tests (`NextcloudUITests`) and integration tests (`NextcloudIntegrationTests`), plus `TestConstants.swift` and the `Server.sh` test-server script. | Prefer `NextcloudUnitTests` for new tests. Try to add unit tests for new features, where applicable and makes sense; do not overcomplicate them. |

Keep this table up to date: when a change adds, removes or repurposes a directory listed here, update the table in the same PR.

## General Guidance

The project is licensed under GPL-3.0-or-later (`LICENSE.txt`) with an Apple App Store exception (`COPYING.iOS`).

Every new file needs to get a SPDX header in the first rows according to this template.
Replace `<YEAR>` with the year the file is created and `<Author Name>` with the contributing author (Nextcloud has no CLA; copyright stays with the individual contributors).
The commenting signs need to be used depending on the file type.

```plaintext
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-FileCopyrightText: <YEAR> <Author Name>
SPDX-License-Identifier: GPL-3.0-or-later
```

Some older files still carry legacy “Created by … All rights reserved” Xcode headers — do not copy that style into new files. There is no automated SPDX check in CI, so header correctness is on you.

Avoid creating source files that implement multiple types; instead, place each type in its own dedicated source file.

## Commit and Pull Request Guidelines

- **DCO sign-off (required)**: All commits must comply with the Developer Certificate of Origin (DCO) as described in `README.md` and include a `Signed-off-by: …` line in the commit message. Sign off with `git commit -s`; the DCO status check blocks PRs otherwise.
- **Commits**: In addition to the DCO sign-off, follow the Conventional Commits format for the subject line where reasonable. Use `feat: ...`, `fix: ...`, or `refactor: ...` as appropriate in the commit message prefix.
- Include a short summary of what changed. *Example:* `fix: prevent crash on empty file name`.
- **Pull Request**: When the agent creates a PR, it should include a description summarizing the changes and why they were made. If a GitHub issue exists, reference it (e.g., “Closes #123”). Target `master` (the default branch); `stable-XX.Y.Z` branches are only for backports. Note that `README.md` still mentions a `develop` branch — it no longer exists.
- **AI-assisted changes**: Declare AI tool use in the PR description (the org-level PR template includes an AI checkbox) and add an `Assisted-by: AGENT_NAME:MODEL_VERSION` trailer to each affected commit, per the org-wide policy in `nextcloud/.github`.

## iOS Specifics

The following details are important when working on the iOS client.

### Requirements

- Use at least the Xcode version pinned in `.github/workflows/xcode.yml` — that is what CI builds and tests with.
- A `GoogleService-Info.plist` must exist at the repo root to build; CI downloads Firebase's mock plist (see `xcode.yml`).

### Code Style

- Write new code to be Swift 6-compatible and strict-concurrency-friendly (proper actor isolation, `Sendable` types). Note that the project currently builds in Swift 5 language mode without strict concurrency checking, so the compiler will not enforce this.
- CI runs SwiftLint on every non-draft PR using the root `.swiftlint.yml`; `Tests/`, `Brand/NCBrand.swift`, `iOSClient/NCGlobal.swift` and `iOSClient/Utility/NCLivePhoto.swift` are excluded from linting.

### Tests

- When implementing new test suites, prefer Swift Testing over XCTest for implementation. UI tests are the exception — XCUITest requires XCTest, so new UI tests are XCTest classes subclassing `BaseUIXCTestCase` in `Tests/NextcloudUITests`.
- New unit tests go in `Tests/NextcloudUnitTests` as Swift Testing `@Suite` structs with `@testable import Nextcloud`; they need no server.
- When implementing test cases using Swift Testing, do not prefix test method names with "test".
- If the implementation of mock types is inevitable, implement them in dedicated source code files and in a generic way, so they can be reused across all tests in a test target. Currently no mock types or mocking library exist; reusable UI-test helpers live in `Tests/NextcloudUITests` (`UITestBackend` and its `Responses/` decodables) — extend these before adding new ones.
- If the implementation of an existing mock type does not fulfill the requirements introduced by new tests, prefer updating the existing type before implementing a mostly redundant alternative type.
- UI tests require a Nextcloud server at `http://localhost:8080` (credentials `admin`/`admin`, see `Tests/TestConstants.swift`); start one with `Tests/Server.sh` (requires Docker). CI provisions the same server.
- `NextcloudIntegrationTests` is currently an empty target: `LoginIntegrationTests.swift` is on disk but excluded from the build and references a nonexistent `EnvVars` type — do not model new tests on it.
- Verify that all tests are passing and correct them if necessary.
- Run tests the way CI does (see `.github/workflows/xcode.yml`): `xcodebuild test -scheme Nextcloud -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5"` (adjust the simulator to what is installed locally). Without a local test server, restrict to `-only-testing:NextcloudUnitTests`.
