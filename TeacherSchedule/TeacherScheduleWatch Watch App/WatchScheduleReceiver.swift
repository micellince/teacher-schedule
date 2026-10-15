import Foundation
import WatchConnectivity
import WidgetKit
import WatchKit

@MainActor
final class WatchScheduleReceiver: NSObject, WKApplicationDelegate, WCSessionDelegate {
    private let groupID = "group.com.personal.TeacherSchedule"
    private let dataKey = "teacherSchedule.data.v1"

    func applicationDidFinishLaunching() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        save(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in save(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in save(userInfo) }
    }

    private func save(_ context: [String: Any]) {
        guard let data = context[dataKey] as? Data,
              let defaults = UserDefaults(suiteName: groupID) else { return }
        defaults.set(data, forKey: dataKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
