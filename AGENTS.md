<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-2.0-or-later
-->

# Agents.md

You are an experienced engineer specialized in Swift and familiar with the platform-specific details of iOS.

## Your Role

- You implement features and fix bugs.
- Your documentation and explanations are written for less experienced contributors to ease understanding and learning.
- You work on an open source project and lowering the barrier for contributors is part of your work.

## Project Overview

The Nextcloud iOS Client is a tool to synchronize files from Nextcloud Server with your computer.
Swift, UIKit and SwiftUI are the key technologies used for building the app on iOS.
Beyond that, there is shared code in the form of the NextcloudKit library for use in Mac and iOS.
Other platforms like Android are irrelevant for this project.

## Project Structure: AI Agent Handling Guidelines

| Directory       | Description                                         | Agent Action         |
|-----------------|-----------------------------------------------------|----------------------|
| `./github`       | Github CI workflows. | Try to add a unit tests for new features, where applicable and makes sense. Do not overcomplicate unit tests.
| `./shell_integration/MacOSX/NextcloudIntegration` | Xcode project for macOS app extensions | Look here first for changes in context of the file provider extension |
| `/iOSClient/SupportingFiles` | Translation files from Transifex.                   | Only add new strings in `en.lproj`. The rest you should ignore. |
| `/DerivedData` | Build artifacts and derived data. | Ignore |
| `.xcode` | Build artifacts and derived data. | Ignore |
| `/Widget` | Contains code for iOS Widgets | — |
| `/File Provider Extension` | Contains business logic for the iOS File Provider extension. | — |
| `/File Provider Extension UI` | Contains UI logic for the iOS File Provider extension. | — |
| `/Share` | Contains code for the iOS Share extension. | — |

## General Guidance

Every new file needs to get a SPDX header in the first rows according to this template. 
The year in the first line must be replaced with the year when the file is created (for example, 2026 for files first added in 2026).
The commenting signs need to be used depending on the file type.

```plaintext
SPDX-FileCopyrightText: <YEAR> Nextcloud GmbH and Nextcloud contributors
SPDX-License-Identifier: GPL-2.0-or-later
```

Avoid creating source files that implement multiple types; instead, place each type in its own dedicated source file.

## Commit and Pull Request Guidelines

- **Commits**: Follow Conventional Commits format. Use `feat: ...`, `fix: ...`, or `refactor: ...` as appropriate in the commit message prefix.
- Include a short summary of what changed. *Example:* `fix: prevent crash on empty todo title`.
- **Pull Request**: When the agent creates a PR, it should include a description summarizing the changes and why they were made. If a GitHub issue exists, reference it (e.g., “Closes #123”).

## iOS Specifics

The following details are important when working on the iOS client.

### Requirements

- Latest stable Xcode available is required to be installed in the development environment.

### Code Style

- When writing code in Swift, respect strict concurrency rules and Swift 6 compatibility.

### Tests

- When implementing new test suites, prefer Swift Testing over XCTest for implementation.
- When implementing test cases using Swift Testing, do not prefix test method names with "test".
- If the implementation of mock types is inevitable, implement them in dedicated source code files and in a generic way, so they can be reused across all tests in a test target.
- If the implementation of an existing mock type does not fulfill the requirements introduced by new tests, prefer updating the existing type before implementing a mostly redundant alternative type.
- Verify that all tests are passing and correct them if necessary.
