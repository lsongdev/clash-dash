//
//  ClashDashWeigetControl.swift
//  ClashDashWeiget
//
//  Created by Lsong on 12/19/24.
//

import AppIntents
import SwiftUI
import WidgetKit



@available(iOS 18.0, *)
struct ClashDashWeigetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ClashDash") {
            ControlWidgetButton(action: ClashDashWidgetIntent()) {
                Label{
                    Text("Clash Dash")
                } icon: {
                    Image("Symbol")
                }
                
            }
        }
        .displayName("Clash Dash")
    }
}

@available(iOS 18.0, *)
struct ClashDashWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "WidgetButton"

    static var openAppWhenRun = true
    static var isDiscoverable = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "clashdash://")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
