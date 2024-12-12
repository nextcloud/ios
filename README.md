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

### Xcode 16 Project Setup

#### Dependencies

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
To run integration tests, you need a docker instance of a Nextcloud test server. [This](https://github.com/szaimen/nextcloud-easy-test) is a good start.

1. In `TestConstants.swift` you must specify your instance credentials. App Token is automatically generated.

```
public class TestConstants {
    static let timeoutLong: Double = 400
    static let server = "http://localhost:8080"
    static let username = "admin"
    static let password = "admin"
    static let account = "\(username) \(server)"
}
```

2. Run the integration tests. 

### UI tests

UI tests also use the docker server, but besides that there is nothing else you need to do.
