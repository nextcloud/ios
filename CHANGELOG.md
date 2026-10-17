<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-3.0-or-later
-->

# TestFlight changelog

This file maps each published TestFlight build to the source revision that was archived.
An entry is a historical build record. It is not the marketing version checked in on `master`, and later project-version bumps must not be written back into an older entry.

The app version on `master` is `MARKETING_VERSION`, and the build number is `CURRENT_PROJECT_VERSION`, in the project-level Debug and Release configurations of `Nextcloud.xcodeproj/project.pbxproj`. When this changelog was added those values were **35.2.0** and **0**. That pair is the current project metadata, not a TestFlight record.

## Entry format

Add a new section at the top of [Builds](#builds) for every build published to TestFlight:

- **Marketing version:** `MARKETING_VERSION` archived for that build
- **TestFlight build:** `CURRENT_PROJECT_VERSION` archived for that build
- **Release date:** the day that build was published to TestFlight (`YYYY-MM-DD`)
- **Source revision:** immutable GitHub URL of the archived commit, `https://github.com/nextcloud/ios/commit/` followed by the full 40-character commit id
- **Highlights:** user-visible changes included in that archive

Link a tag or GitHub release only when it points at that same commit. A later tag that reuses the marketing version is not the source of an earlier build number. Do not publish a tag or release link when the archived commit cannot be confirmed.

## Builds

### 35.1.0 (Build 9)

- **Marketing version:** 35.1.0
- **TestFlight build:** 9
- **Release date:** 2026-10-03
- **Source revision:** [`a157232cf34be2da96a407662029365c3fe843a1`](https://github.com/nextcloud/ios/commit/a157232cf34be2da96a407662029365c3fe843a1)
- **Highlights:**
  - PhotoKit auto-upload jobs are cleaned up when auto upload stops. Successful upload records are kept before acknowledgement, and discovery and scheduling stop when auto upload is disabled.
  - Auto-upload sessions are isolated across restarts. Stale discovery and retry passes are invalidated, outstanding PhotoKit jobs are reconciled, and the selected date cutoff is saved before Start.
  - Log snapshots can be previewed without blocking the interface. Flushing and file work leave the main actor, and Quick Look opens an immutable temporary copy.
  - A cancelled PhotoKit upload stays cancelled when jobs are updated.
  - Media preview and avatar sizes follow the view instead of the device screen.
  - The auto-upload date cutoff is independent of discovery progress. The choice is the whole library or an explicit date, and new accounts start from the current date.

The release date is the day [#4369](https://github.com/nextcloud/ios/issues/4369) reported that 35.1.0 Build 9 was available on TestFlight. The repository does not contain an App Store Connect upload timestamp. The build number itself was committed on 2026-10-02.

Commit [`a157232cf34be2da96a407662029365c3fe843a1`](https://github.com/nextcloud/ios/commit/a157232cf34be2da96a407662029365c3fe843a1) (#4356) is the revision that set `MARKETING_VERSION` to 35.1.0 and `CURRENT_PROJECT_VERSION` to 9. There is no git tag and no GitHub release for Build 9. The same version and build number stayed in the tree through [`b49c8c86ec01d1853e7797fdb970c19907f368c6`](https://github.com/nextcloud/ios/commit/b49c8c86ec01d1853e7797fdb970c19907f368c6) (2026-10-05), the last commit before build 10. The uploaded archive was not recorded separately from that range, so this entry does not claim a later tip as the archived commit.

These later commits still compile as 35.1.0 (9). They are part of the unrecorded range, not additional TestFlight build numbers:

- [`bd58e2f17ee4e179b06e09d115690f49122c1978`](https://github.com/nextcloud/ios/commit/bd58e2f17ee4e179b06e09d115690f49122c1978) — clarify auto upload progress and PhotoKit settings (#4361)
- [`1d8269785e0cc35f44b097d2740f4b51204a265c`](https://github.com/nextcloud/ios/commit/1d8269785e0cc35f44b097d2740f4b51204a265c) — preserve legacy auto upload progress for Live Photos (#4362)
- [`31732165437a3c198409cd79865943a0d4ccfca0`](https://github.com/nextcloud/ios/commit/31732165437a3c198409cd79865943a0d4ccfca0) — GUI fix (#4363)
- Transifex translation updates through `b49c8c86ec01d1853e7797fdb970c19907f368c6`

The GitHub tag `35.1.0` is a different revision. It points at [`dc214c4c92125da009bf9581b83462d4ba36d5fb`](https://github.com/nextcloud/ios/commit/dc214c4c92125da009bf9581b83462d4ba36d5fb) (2026-10-07), which is marketing version 35.1.0 and build 14. That tag is not the source of TestFlight Build 9.
