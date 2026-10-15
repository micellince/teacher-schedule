import SwiftUI

@main
struct TeacherScheduleApp: App {
    @StateObject private var store = ScheduleStore.shared
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .preferredColorScheme(nil)
                .task { await NotificationScheduler.shared.refresh(data: store.data) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ScheduleStore
    var body: some View {
        Group {
            if store.data.isConfigured { MainTabsView() } else { WelcomeView() }
        }
        .tint(.indigo)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var showingSetup = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "calendar.badge.clock").font(.system(size: 68, weight: .light)).foregroundStyle(.indigo)
                Text("欢迎使用教师课表").font(.largeTitle.bold())
                Text("先添加第一节课并填写班级和科目，也可以直接使用陈老师的默认课表。课次时间可随时修改。")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 30)
                Spacer()
                Button("使用图片中的默认课表") { store.replace(with: .sample) }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                Button("填写第一节课") { showingSetup = true }.buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSetup) { CourseEditorView(course: nil, weekday: 2) }
        }
    }
}

struct MainTabsView: View {
    var body: some View {
        TabView {
            TodayView().tabItem { Label("今日", systemImage: "sun.max") }
            ScheduleView().tabItem { Label("课表", systemImage: "calendar") }
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
