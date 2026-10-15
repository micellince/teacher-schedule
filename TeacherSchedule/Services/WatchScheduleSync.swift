import Foundation
import WatchConnectivity

@MainActor
final class WatchScheduleSync: NSObject, WCSessionDelegate {
    static let shared = WatchScheduleSync()

    private var latestData: ScheduleData?
    private var didActivate = false

    func sync(_ data: ScheduleData) {
        latestData = data
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if !didActivate {
            session.delegate = self
            session.activate()
            didActivate = true
        } else if session.activationState == .activated {
            publishLatestData(using: session)
        }
    }

    private func publishLatestData(using session: WCSession) {
        guard let latestData, let encoded = try? JSONEncoder().encode(latestData) else { return }
        do {
            try session.updateApplicationContext([AppConfig.dataKey: encoded])
            // Application context keeps only the latest snapshot. Transfer the
            // same snapshot as user info as well, so it is queued if the Watch
            // app is not currently reachable.
            session.transferUserInfo([AppConfig.dataKey: encoded])
        } catch {
            NSLog("Unable to sync schedule to Apple Watch: %@", error.localizedDescription)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in publishLatestData(using: session) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
