import UIKit
import NextcloudKit

var hasBecomeActiveOnce: Bool = false
/// Used for read/write in Realm
var isAppSuspending: Bool = false
/// Used for know if the app in in Background mode
var isAppInBackground: Bool = true

final class NCAppStateManager {
    static let shared = NCAppStateManager()

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            hasBecomeActiveOnce = true
            isAppSuspending = false
            isAppInBackground = false

            nkLog(debug: "Application will enter in foreground")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            nkLog(debug: "Application did become active")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            isAppSuspending = true
            isAppInBackground = true

            nkLog(debug: "Application did enter in background")
        }
    }
}
