---
# SPDX-FileCopyrightText: Nextcloud GmbH
# SPDX-FileCopyrightText: 2026 Milen Pivchev
# SPDX-License-Identifier: GPL-3.0-or-later
name: github-actions-failure-debugging
description: Debug and fix failing GitHub Actions workflows (CI) in this repo — failing PR checks, xcodebuild/simulator/runner-image errors, SwiftLint failures. Use when asked to review, debug, or fix CI or a failing workflow run.
---

# Debugging failing GitHub Actions workflows

Workflows live in `.github/workflows/`:

- `xcode.yml` — builds the `Nextcloud` scheme for testing, then runs tests on a simulator against a locally installed Nextcloud server. Version pins are env vars at the top: `XCODE_VERSION`, `DESTINATION`, plus the `runs-on` labels and the `simctl boot` device name further down.
- `additional-targets.yml` — builds the extension schemes (Share, File Provider, Notification Service, Widget, WidgetDashboardIntentHandler). Keep its image/Xcode/destination consistent with `xcode.yml`.
- `lint.yml` — SwiftLint on ubuntu.

## 1. Get the failure

Use the `gh` CLI (if a GitHub MCP server is connected, its equivalents like `list_workflow_runs` / `get_job_logs` work too):

- `gh pr checks <pr>` or `gh run list --branch <branch> --limit 10` — find failing runs
- `gh run view <run-id>` — see which jobs and steps failed
- `gh run view <run-id> --log-failed | grep -iE "error:|failed" | head -60` — never dump full logs into context; grep/tail them, or have a subagent read them and report only the failing step and error lines.

## 2. Classify before fixing

- `cannot find type '…' in scope` for Apple APIs → SDK mismatch: the code uses APIs newer than the SDK of the Xcode selected on the runner. Confirm the API's introduction version by grepping the local SDK, e.g.
  `grep -rn -B4 "TypeName" /Applications/Xcode-*.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/<Framework>.framework/Modules/*.swiftmodule/*.swiftinterface`
  and look for `@available(iOS X.0, …)`.
- "Unable to find a destination" or simulator boot errors → the pinned `DESTINATION` OS/device or the `simctl boot` device name doesn't exist on the runner image.
- Job queued forever or tooling missing → invalid or stale `runs-on` label.
- Test-job failures around PHP/occ → the Nextcloud server setup steps; these shell steps can be reproduced locally.
- SwiftLint failures → run `swiftlint` locally.

## 3. Check runner-image compatibility

Before changing any pin, check https://github.com/actions/runner-images:

- The README's Available Images table has the valid `runs-on` labels, including preview images (e.g. `xcode-27`) and deprecation notices.
- Each macOS image readme (`images/macos/<image>-arm64-Readme.md`) lists installed Xcode versions, iOS simulator runtimes, and device types.

The chosen combination must exist together on one image: `runs-on` label ↔ `XCODE_VERSION` ↔ `DESTINATION` OS + device ↔ `simctl boot` device name. New Xcode majors appear first on a dedicated preview image before reaching the GA `macos-NN` image.

## 4. Reproduce and fix

- Do **not** run `xcodebuild` locally to reproduce — builds take too long (repo rule). Reproduce only cheap failures (SwiftLint, YAML, shell steps); for compile/SDK failures, reason from the logs plus the SDK check above.
- Apply the fix to every workflow sharing the stale value.
- Validate edited YAML: `ruby -ryaml -e 'YAML.load_file(".github/workflows/xcode.yml")'`
- If you reproduced a failure locally, verify the fix locally before committing. Otherwise say plainly that verification needs a CI run; after pushing, watch it with `gh pr checks --watch` or `gh run watch`.
