//
//  ClashDashWeigetLiveActivity.swift
//  ClashDashWeiget
//
//  Created by Lsong on 12/19/24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ClashDashWeigetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ClashDashWeigetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClashDashWeigetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ClashDashWeigetAttributes {
    fileprivate static var preview: ClashDashWeigetAttributes {
        ClashDashWeigetAttributes(name: "World")
    }
}

extension ClashDashWeigetAttributes.ContentState {
    fileprivate static var smiley: ClashDashWeigetAttributes.ContentState {
        ClashDashWeigetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ClashDashWeigetAttributes.ContentState {
         ClashDashWeigetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ClashDashWeigetAttributes.preview) {
   ClashDashWeigetLiveActivity()
} contentStates: {
    ClashDashWeigetAttributes.ContentState.smiley
    ClashDashWeigetAttributes.ContentState.starEyes
}
