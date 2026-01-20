//
//  SophisWidgetLiveActivity.swift
//  SophisWidget
//
//  Created by tension on 19.01.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SophisWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SophisWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SophisWidgetAttributes.self) { context in
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

extension SophisWidgetAttributes {
    fileprivate static var preview: SophisWidgetAttributes {
        SophisWidgetAttributes(name: "World")
    }
}

extension SophisWidgetAttributes.ContentState {
    fileprivate static var smiley: SophisWidgetAttributes.ContentState {
        SophisWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SophisWidgetAttributes.ContentState {
         SophisWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SophisWidgetAttributes.preview) {
   SophisWidgetLiveActivity()
} contentStates: {
    SophisWidgetAttributes.ContentState.smiley
    SophisWidgetAttributes.ContentState.starEyes
}
