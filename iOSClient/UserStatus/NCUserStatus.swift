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
    var body: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                Image("userStatusAway")
                    .resizable()
                    .frame(width: 100.0, height: 100.0)
                    .clipShape(Circle())
            }
            
            Text("Hello World44,2")
                .font(.headline)
                .foregroundColor(Color.red)
                .lineLimit(0)
            Text("test")
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
