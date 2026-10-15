import SwiftUI
import WidgetKit

private struct WatchCourse: Decodable, Identifiable {
    let id: UUID
    let weekday: Int
    let period: Int
    let startMinute: Int
    let endMinute: Int
    let classroom: String
    let subject: String
    let note: String
}

private struct WatchSchedule: Decodable {
    let courses: [WatchCourse]

    private enum CodingKeys: String, CodingKey { case courses }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        courses = try values.decodeIfPresent([WatchCourse].self, forKey: .courses) ?? []
    }

    static func load() -> WatchSchedule {
        guard let data = UserDefaults(suiteName: "group.com.personal.TeacherSchedule")?.data(forKey: "teacherSchedule.data.v1"),
              let schedule = try? JSONDecoder().decode(WatchSchedule.self, from: data) else {
            return WatchSchedule(courses: [])
        }
        return schedule
    }

    private init(courses: [WatchCourse]) { self.courses = courses }
}

private struct ScheduleEntry: TimelineEntry {
    let date: Date
    let schedule: WatchSchedule

    var todaysCourses: [WatchCourse] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return schedule.courses.filter { $0.weekday == weekday }.sorted { $0.startMinute < $1.startMinute }
    }
    var currentCourse: WatchCourse? {
        let minute = Self.minuteOfDay(date)
        return todaysCourses.first { minute >= $0.startMinute && minute < $0.endMinute }
    }
    var nextCourse: WatchCourse? {
        let minute = Self.minuteOfDay(date)
        return todaysCourses.first { $0.startMinute > minute }
    }
    static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
    static func time(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}

private struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: .now, schedule: .load())
    }
    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(ScheduleEntry(date: .now, schedule: .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let now = Date.now
        let schedule = WatchSchedule.load()
        var dates = [now]
        let calendar = Calendar.current
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for course in schedule.courses where course.weekday == weekday {
                for minute in [course.startMinute, course.endMinute] {
                    if let edge = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day), edge > now {
                        dates.append(edge)
                    }
                }
            }
        }
        let entries = Array(Set(dates)).sorted().map { ScheduleEntry(date: $0, schedule: schedule) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(12 * 60 * 60))))
    }
}

private struct WatchScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleEntry

    private var focusCourse: WatchCourse? { entry.currentCourse ?? entry.nextCourse }
    private var status: String { entry.currentCourse == nil && entry.nextCourse != nil ? "下一节" : "正在上课" }

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 1) {
                Text(entry.currentCourse == nil ? "下节" : "现在").font(.system(size: 9, weight: .medium))
                Text(focusCourse.map { String($0.period) } ?? "—").font(.system(size: 19, weight: .bold, design: .rounded))
                Text("课程").font(.system(size: 8))
            }
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCorner:
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18, weight: .semibold))
                .widgetLabel { Text(focusCourse.map { "第\($0.period)节 · \($0.subject)" } ?? "今日无课") }
        default:
            rectangular
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let course = focusCourse {
                Text(status).font(.caption2).foregroundStyle(.secondary)
                Text(course.subject).font(.headline).lineLimit(1)
                Text("第\(course.period)节 · \(course.currentTime)").font(.caption2).lineLimit(1)
                if !course.classroom.isEmpty { Text(course.classroom).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            } else {
                Text("今日无课").font(.headline)
                Text("打开教师课表添加课程").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineText: String {
        guard let course = focusCourse else { return "今日无课" }
        return "\(course.subject) · \(course.currentTime)"
    }
}

private extension WatchCourse {
    var currentTime: String { ScheduleEntry.time(startMinute) }
}

struct TeacherScheduleWatchWidget: Widget {
    let kind = "TeacherScheduleWatchWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            WatchScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("教师课表")
        .description("查看正在上的课和下一节课")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}
