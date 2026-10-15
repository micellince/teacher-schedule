import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func refresh(data: ScheduleData) async {
        center.removeAllPendingNotificationRequests()
        guard data.settings.remindersEnabled else { return }
        let allowed = await requestPermission()
        guard allowed else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var scheduled = 0
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            for course in ScheduleEngine.coursesForToday(in: data, at: day) {
                let leads = [data.settings.reminderMinutes, data.settings.startReminderEnabled ? 0 : nil].compactMap { $0 }
                for lead in Set(leads) {
                    guard scheduled < 60, let fire = cal.date(byAdding: .minute, value: -lead, to: ScheduleEngine.dateAtMinute(course.startMinute, on: day) ?? day), fire > .now else { continue }
                    var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    components.calendar = cal
                    let content = UNMutableNotificationContent()
                    content.title = lead == 0 ? "第\(course.period)节课开始" : "\(lead)分钟后上课"
                    content.body = "\(course.classroom) · \(course.subject)\n第\(course.period)节"
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: "course-\(course.id)-\(ScheduleEngine.dateKey(day))-\(lead)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                    try? await center.add(request); scheduled += 1
                }
            }
        }
    }
}
