//
//  NCUserStatus.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/11/20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Foundation
import NCCommunication

@available(iOS 13.0, *)
struct NCUserStatus: View {
    @State var counter = 0
    var body: some View {
        VStack {
            Button("Tap me") {
                self.counter += 1
            }
            if counter > 0 {
                Text("tapped \(counter) time")
            }
        }
    }
}

@available(iOS 13.0, *)
struct NCUserStatus_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NCUserStatus()
        }
    }
}

@available(iOS 13.0, *)
@objc class NCUserStatusViewController: NSObject {
 
    @objc func makeUserStatusUI() -> UIViewController{
        
        NCCommunication.shared.getUserStatusPredefinedStatuses { (account, userStatuses, errorCode, errorDescription) in
            if errorCode == 0 {
                if let userStatuses = userStatuses {
                    NCManageDatabase.shared.addUserStatus(userStatuses, account: account, predefined: true)
                }
            }
        }
        
        NCCommunication.shared.getUserStatusRetrieveStatuses(limit: 1000, offset: 0, customUserAgent: nil, addCustomHeaders: nil) { (account, userStatuses, errorCode, errorDescription) in
            if errorCode == 0 {
                if let userStatuses = userStatuses {
                    NCManageDatabase.shared.addUserStatus(userStatuses, account: account, predefined: false)
                }
            }
        }
        
        let userStatus = NCUserStatus()
        //details.shipName = name
        return UIHostingController(rootView: userStatus)
    }
}
