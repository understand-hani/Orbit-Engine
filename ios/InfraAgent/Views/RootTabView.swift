import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            InboxView()
                .tabItem {
                    Label("收件箱", systemImage: "tray.full")
                }

            JDIntelligenceView()
                .tabItem {
                    Label("JD", systemImage: "briefcase")
                }

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock")
                }

            MoreView()
                .tabItem {
                    Label("更多", systemImage: "ellipsis.circle")
                }
        }
    }
}

#Preview {
    RootTabView()
}
