# [Nextcloud](https://nextcloud.com) iOS app 
[![Releases](https://img.shields.io/github/release/nextcloud/ios.svg)](https://github.com/nextcloud/ios/releases/latest) [![Build](https://github.com/nextcloud/ios/actions/workflows/xcode.yml/badge.svg)](https://github.com/nextcloud/ios/actions/workflows/xcode.yml) [![SwiftLint](https://github.com/nextcloud/ios/actions/workflows/lint.yml/badge.svg)](https://github.com/nextcloud/ios/actions/workflows/lint.yml)
[![irc](https://img.shields.io/badge/IRC-%23nextcloud--mobile%20on%20freenode-blue.svg)](https://webchat.freenode.net/?channels=nextcloud-mobile)

<img src="Animation.gif" alt="Demo of the Nextcloud iOS files app" width="277" height="600"><img src="widget.png" alt="Widget of the Nextcloud iOS files app" width="277" height="600">

[<img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg"
alt="Demo of the Nextcloud iOS files app"
height="40">](https://itunes.apple.com/us/app/nextcloud/id1125420102)

Check out https://nextcloud.com and follow us on [twitter.com/nextclouders](https://twitter.com/nextclouders)

## How to contribute
If you want to [contribute](https://nextcloud.com/contribute/) to Nextcloud, you are very welcome:

- our forum at https://help.nextcloud.com/c/clients/ios
- for translations of the app on [Transifex](https://www.transifex.com/nextcloud/nextcloud/dashboard/)
- opening issues and PRs (including a corresponding issue)

## Contribution Guidelines & License

[GPLv3](LICENSE.txt) with [Apple app store exception](COPYING.iOS).

Nextcloud doesn't require a CLA (Contributor License Agreement). The copyright belongs to all the individual contributors. Therefore we recommend that every contributor adds following line to the header of a file, if they changed it substantially:

```
@copyright Copyright (c) <year>, <your name> (<your email address>)
```

Please read the [Code of Conduct](https://nextcloud.com/code-of-conduct/). This document offers some guidance to ensure Nextcloud participants can cooperate effectively in a positive and inspiring atmosphere, and to explain how together we can strengthen and support each other.

More information how to contribute: [https://nextcloud.com/contribute/](https://nextcloud.com/contribute/)

## Start contributing

You can start by forking this repository and creating pull requests on the develop
branch. Maybe start working on [starter issues](https://github.com/nextcloud/ios/labels/good%20first%20issue). 

Easy starting points are also reviewing [pull requests](https://github.com/nextcloud/ios/pulls)

### Xcode 15 Project Setup

#### Dependencies

After forking a repository you have to build the dependencies. Dependencies are managed with Carthage version 0.38.0 or later. 
Run

```
carthage update --use-xcframeworks --platform iOS
```
to fetch and compile the dependencies.

In order to build the project in Xcode you will also need a file `GoogleService-Info.plist` at the root of the repository which contains the Firebase configuration. For development work you can use a mock version found [here](https://github.com/firebase/quickstart-ios/blob/master/mock-GoogleService-Info.plist).

### Creating Pull requests

#### DCO Signoff

Nextcloud enforces the [Developer Certificate of Origin (DCO)](https://developercertificate.org/) on Pull Requests. It requires your commit messages to contain a Signed-off-by line with an email address that matches your GitHub account.

##### How to Sign off

The DCO is a way for contributors to certify that they wrote or otherwise have the right to submit the code they are contributing by adding a Signed-off-by line to commit messages.

```
My Commit message

Signed-off-by: Random Contributor <random@contributor.dev>
```

Git even has a `-s | --signoff` command line option to append this to your commit messages automatically.

## Support

If you need assistance or want to ask a question about the iOS app, you are welcome to [ask for support](https://help.nextcloud.com/c/clients/ios) in our Forums. If you have found a bug, feel free to [open a new Issue on GitHub](https://github.com/nextcloud/ios/issues). Keep in mind, that this repository only manages the iOS app. If you find bugs or have problems with the server/backend, you should ask the [Nextcloud server team](https://github.com/nextcloud/server) for help!

## TestFlight 

Do you want to try the latest version in development of Nextcloud iOS ? Simple, follow this simple step

[Apple TestFlight](https://testflight.apple.com/join/RXEJbWj9)

## Testing

#### Note: If a Unit or Integration test exclusively uses and tests NextcloudKit functions and components, then write that test in the NextcloudKit repo. NextcloudKit is used in many other repos as an API, and it's better if such tests are located there.

### Unit tests:

There are currently no preresquites for unit testing that need to be done. Mock everything that's not needed. 

### Integration tests:
To run integration tests, we need a docker instance of a Nextcloud test server.
The CI does all this automatically, but to do it manually:
1. Run `docker run --rm -d -p 8080:80 ghcr.io/juliushaertl/nextcloud-dev-php80:latest` to spin up a docker container of the Nextcloud test server.
2. Log in on the test server and generate an app password for device. There are a couple test accounts, but `admin` as username and password works best.
3. Build the iOS project once. This will generate an `.env-vars` file in the root directory. It contains env vars that the project will use for testing.
4. Provide proper values for the env vars inside the file. Here is an example:
```
export TEST_SERVER_URL=http://localhost:8080
export TEST_USER=nextcloud
export TEST_PASSWORD=FAeSR-6Jk7s-DzLny-CCQHL-f49BP
```
5. Build the iOS project again. If all the values are set correctly you will see a generated file called `EnvVars.generated.swift`. It contains the env vars as Swift fields that can be easily used in code:
```
/**
This is generated from the .env-vars file in the root directory. If there is an environment variable here that is needed and not filled, please look into this file.
 */
 public struct EnvVars {
  static let testUser = "nextcloud"
  static let testPassword = "FAeSR-6Jk7s-DzLny-CCQHL-f49BP"
  static let testServerUrl = "http://localhost:8080"
}
```
6. You can now run the integration tests. They will use the env vars to connect to the test server to do the testing. 


### UI tests

UI tests also use the docker server, but besides that there is nothing else you need to do.

### Snapshot tests

Snapshot tests are made via this library: https://github.com/pointfreeco/swift-snapshot-testing and these 2 extensions:
1. https://github.com/doordash-oss/swiftui-preview-snapshots - for creating SwiftUI snapshot tests via previews.
2. https://github.com/alexey1312/SnapshotTestingHEIC - makes snapshot images HEIC instead of PNGs for much reduced size.

Snapshot tests are a great way to test if UI elements are consistent with designs and don't break with new commits, but they can be very finicky and the smallest change can cause them to fail. Keep in mind:

- For SwiftUI snapshot tests, It's always a good idea to utilize previews, as they do not depend on device/app state and it has less chances to fail due to wrong state.

- For UIKit snapshot tests, try to include mock dependencies to always make sure the UI is rendered the same way. Even a text change can cause the tests to fail.
