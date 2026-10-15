import Foundation

enum AppConfig {
    static let groupID = "group.com.personal.TeacherSchedule"
    static let dataKey = "teacherSchedule.data.v1"
    static let appName = "教师课表"
}

struct Course: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekday: Int // Calendar weekday: Sunday = 1
    var period: Int
    var startMinute: Int
    var endMinute: Int
    var classroom: String
    var subject: String
    var note: String = ""

    var displaySubject: String { subject.isEmpty ? "科目待填写" : subject }
}

struct PeriodTemplate: Identifiable, Codable, Hashable {
    var id: Int { number }
    var number: Int
    var startMinute: Int?
    var endMinute: Int?
}

struct ScheduleOverride: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var dateKey: String
    var courses: [Course] // empty means no classes on that date
}

struct ScheduleSettings: Codable, Hashable {
    static let maximumClasses = 5
    static let maximumSubjects = 10
    static let maximumPeriods = 10
    var remindersEnabled = false
    var reminderMinutes = 5
    var startReminderEnabled = true
    var classes: [String] = []
    var subjects: [String] = []
    var widgetBackground = RGBAColor(red: 0.12, green: 0.13, blue: 0.17)
    var widgetTextColor = RGBAColor(red: 1, green: 1, blue: 1)

    private enum CodingKeys: String, CodingKey {
        case remindersEnabled, reminderMinutes, startReminderEnabled, classes, subjects, widgetBackground, widgetTextColor
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        remindersEnabled = try values.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        reminderMinutes = try values.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 5
        startReminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .startReminderEnabled) ?? true
        classes = Array((try values.decodeIfPresent([String].self, forKey: .classes) ?? []).prefix(Self.maximumClasses))
        subjects = Array((try values.decodeIfPresent([String].self, forKey: .subjects) ?? []).prefix(Self.maximumSubjects))
        widgetBackground = try values.decodeIfPresent(RGBAColor.self, forKey: .widgetBackground) ?? RGBAColor(red: 0.12, green: 0.13, blue: 0.17)
        widgetTextColor = try values.decodeIfPresent(RGBAColor.self, forKey: .widgetTextColor) ?? RGBAColor(red: 1, green: 1, blue: 1)
    }
}

struct RGBAColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1
}

struct ScheduleData: Codable {
    var courses: [Course] = []
    var periods: [PeriodTemplate] = ScheduleData.defaultPeriods
    var settings = ScheduleSettings()
    var overrides: [ScheduleOverride] = []
    var isConfigured = false
    var usesAlternatingWeeks = false // reserved for A/B week support

    private enum CodingKeys: String, CodingKey {
        case courses, periods, settings, overrides, isConfigured, usesAlternatingWeeks
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        courses = try values.decodeIfPresent([Course].self, forKey: .courses) ?? []
        periods = try values.decodeIfPresent([PeriodTemplate].self, forKey: .periods) ?? Self.defaultPeriods
        settings = try values.decodeIfPresent(ScheduleSettings.self, forKey: .settings) ?? ScheduleSettings()
        overrides = try values.decodeIfPresent([ScheduleOverride].self, forKey: .overrides) ?? []
        isConfigured = try values.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? false
        usesAlternatingWeeks = try values.decodeIfPresent(Bool.self, forKey: .usesAlternatingWeeks) ?? false

        // Remove the old placeholder lists even if a schedule has already been started.
        // They were app-provided examples, not choices the teacher explicitly added.
        let oldClassDefaults = ["五年级2班", "三年级1班", "四年级3班", "六年级1班"]
        let oldSubjectDefaults = ["语文", "数学", "英语", "体育", "音乐", "美术", "科学", "班会"]
        if settings.classes.count == oldClassDefaults.count && Set(settings.classes) == Set(oldClassDefaults) { settings.classes = [] }
        if settings.subjects.count == oldSubjectDefaults.count && Set(settings.subjects) == Set(oldSubjectDefaults) { settings.subjects = [] }

        let oldExampleRows: Set<String> = [
            "2|1|五年级2班|数学", "2|2|五年级2班|语文", "2|3|三年级1班|英语",
            "2|4|四年级3班|英语", "2|5|五年级2班|数学", "2|6|六年级1班|班会"
        ]
        let decodedRows = Set(courses.map { "\($0.weekday)|\($0.period)|\($0.classroom)|\($0.subject)" })
        if courses.count == oldExampleRows.count && decodedRows == oldExampleRows {
            let replacement = Self.sample
            courses = replacement.courses
            periods = replacement.periods
            settings.classes = replacement.settings.classes
            settings.subjects = replacement.settings.subjects
            isConfigured = true
        }

        let decodedPeriods = periods
        // Pad older schedules to the new ten-period limit without assigning
        // invented times to the additional periods.
        if courses.isEmpty && decodedPeriods == Self.legacyPeriods {
            periods = Self.defaultPeriods
        } else {
            periods = Self.normalizedPeriods(decodedPeriods)
        }
    }

    static let defaultPeriods: [PeriodTemplate] = (1...ScheduleSettings.maximumPeriods).map {
        PeriodTemplate(number: $0, startMinute: nil, endMinute: nil)
    }

    static let legacyPeriods: [PeriodTemplate] = [
        .init(number: 1, startMinute: 480, endMinute: 520),
        .init(number: 2, startMinute: 540, endMinute: 580),
        .init(number: 3, startMinute: 600, endMinute: 640),
        .init(number: 4, startMinute: 660, endMinute: 700),
        .init(number: 5, startMinute: 840, endMinute: 880),
        .init(number: 6, startMinute: 900, endMinute: 940)
    ]

    static let imageDefaultPeriods: [PeriodTemplate] = [
        .init(number: 1, startMinute: 480, endMinute: 520),  // 08:00–08:40
        .init(number: 2, startMinute: 555, endMinute: 595),  // 09:15–09:55
        .init(number: 3, startMinute: 610, endMinute: 655),  // 10:10–10:55
        .init(number: 4, startMinute: 670, endMinute: 720),  // 11:10–12:00
        .init(number: 5, startMinute: 840, endMinute: 880),  // 14:00–14:40
        .init(number: 6, startMinute: 895, endMinute: 935),  // 14:55–15:35
        .init(number: 7, startMinute: 950, endMinute: 990),  // 15:50–16:30
        .init(number: 8, startMinute: 1005, endMinute: 1045), // 16:45–17:25
        .init(number: 9, startMinute: nil, endMinute: nil),
        .init(number: 10, startMinute: nil, endMinute: nil)
    ]

    private static func normalizedPeriods(_ periods: [PeriodTemplate]) -> [PeriodTemplate] {
        var byNumber: [Int: PeriodTemplate] = [:]
        for period in periods where (1...ScheduleSettings.maximumPeriods).contains(period.number) {
            byNumber[period.number] = period
        }
        return (1...ScheduleSettings.maximumPeriods).map { number in
            byNumber.removeValue(forKey: number) ?? PeriodTemplate(number: number, startMinute: nil, endMinute: nil)
        }
    }

    static var sample: ScheduleData {
        var data = ScheduleData()
        data.isConfigured = true
        data.periods = imageDefaultPeriods
        data.settings.classes = ["2班", "6班"]
        data.settings.subjects = ["数学"]
        let rows: [(weekday: Int, period: Int, classNumber: Int)] = [
            (2,1,6), (3,1,2),
            (4,2,2), (6,2,6),
            (5,3,2), (6,3,2),
            (4,4,6), (5,4,2),
            (5,5,6),
            (5,6,6),
            (2,7,2), (3,7,6),
            (2,8,2), (3,8,6)
        ]
        data.courses = rows.map { row in
            let period = imageDefaultPeriods[row.period - 1]
            return Course(weekday: row.weekday, period: row.period, startMinute: period.startMinute!, endMinute: period.endMinute!, classroom: "\(row.classNumber)班", subject: "数学")
        }
        return data
    }
}

enum CourseState {
    case inClass(Course)
    case breakTime(next: Course?)
    case finished(last: Course?, nextDay: Course?)
    case noClasses(nextDay: Course?)
}

enum ScheduleEngine {
    static func coursesForToday(in data: ScheduleData, at date: Date = .now) -> [Course] {
        let key = dateKey(date)
        if let override = data.overrides.first(where: { $0.dateKey == key }) {
            return override.courses.sorted(by: courseOrder)
        }
        let weekday = Calendar.current.component(.weekday, from: date)
        return data.courses.filter { $0.weekday == weekday }.sorted(by: courseOrder)
    }

    static func currentCourse(in data: ScheduleData, at date: Date = .now) -> Course? {
        let minute = minuteOfDay(date)
        return coursesForToday(in: data, at: date).first { minute >= $0.startMinute && minute < $0.endMinute }
    }

    static func nextCourse(in data: ScheduleData, after date: Date = .now) -> Course? {
        let minute = minuteOfDay(date)
        return coursesForToday(in: data, at: date).first { $0.startMinute > minute }
    }

    static func currentPeriod(in data: ScheduleData, at date: Date = .now) -> Int? { currentCourse(in: data, at: date)?.period }
    static func remainingTime(in data: ScheduleData, at date: Date = .now) -> TimeInterval? {
        guard let course = currentCourse(in: data, at: date), let end = dateAtMinute(course.endMinute, on: date) else { return nil }
        return max(0, end.timeIntervalSince(date))
    }
    static func isBreak(in data: ScheduleData, at date: Date = .now) -> Bool {
        currentCourse(in: data, at: date) == nil && nextCourse(in: data, after: date) != nil && !coursesForToday(in: data, at: date).isEmpty
    }
    static func state(in data: ScheduleData, at date: Date = .now) -> CourseState {
        let courses = coursesForToday(in: data, at: date)
        if courses.isEmpty { return .noClasses(nextDay: nextCourseInFollowingDays(in: data, after: date)) }
        if let active = currentCourse(in: data, at: date) { return .inClass(active) }
        if let upcoming = nextCourse(in: data, after: date) { return .breakTime(next: upcoming) }
        return .finished(last: courses.last, nextDay: nextCourseInFollowingDays(in: data, after: date))
    }
    static func dateAtMinute(_ minute: Int, on date: Date) -> Date? {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date)
    }
    static func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    static func dateKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func courseOrder(_ a: Course, _ b: Course) -> Bool { a.startMinute == b.startMinute ? a.period < b.period : a.startMinute < b.startMinute }
    private static func nextCourseInFollowingDays(in data: ScheduleData, after date: Date) -> Course? {
        for offset in 1...7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: date) else { continue }
            if let first = coursesForToday(in: data, at: day).first { return first }
        }
        return nil
    }
}

enum TimeText {
    static func string(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let hours = seconds / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, (seconds / 60) % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
