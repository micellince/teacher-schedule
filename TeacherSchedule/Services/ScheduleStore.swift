import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var data: ScheduleData
    private let defaults: UserDefaults
    static let shared = ScheduleStore()

    private init() {
        defaults = UserDefaults(suiteName: AppConfig.groupID) ?? .standard
        if let raw = defaults.data(forKey: AppConfig.dataKey), let saved = try? JSONDecoder().decode(ScheduleData.self, from: raw) {
            data = saved
        } else { data = ScheduleData() }
        WatchScheduleSync.shared.sync(data)
        WidgetCenter.shared.reloadTimelines(ofKind: "TeacherScheduleWidget")
    }

    func replace(with newData: ScheduleData) {
        data = newData
        if let encoded = try? JSONEncoder().encode(newData) {
            defaults.set(encoded, forKey: AppConfig.dataKey)
            defaults.synchronize()
        }
        WatchScheduleSync.shared.sync(newData)
        WidgetCenter.shared.reloadTimelines(ofKind: "TeacherScheduleWidget")
        Task { await NotificationScheduler.shared.refresh(data: newData) }
    }
    func update(_ change: (inout ScheduleData) -> Void) { var copy = data; change(&copy); replace(with: copy) }
    func add(_ course: Course) {
        update { data in
            setPeriodTime(course.period, start: course.startMinute, end: course.endMinute, in: &data)
            data.courses.append(course)
            data.isConfigured = true
            synchronizeCourses(for: course.period, start: course.startMinute, end: course.endMinute, in: &data)
        }
    }

    func update(_ course: Course) {
        update { data in
            guard let index = data.courses.firstIndex(where: { $0.id == course.id }) else { return }
            data.courses[index] = course
            setPeriodTime(course.period, start: course.startMinute, end: course.endMinute, in: &data)
            synchronizeCourses(for: course.period, start: course.startMinute, end: course.endMinute, in: &data)
        }
    }

    func updatePeriodTime(_ number: Int, startMinute: Int?, endMinute: Int?) {
        update { data in
            setPeriodTime(number, start: startMinute, end: endMinute, in: &data)
            if let startMinute, let endMinute {
                synchronizeCourses(for: number, start: startMinute, end: endMinute, in: &data)
            }
        }
    }

    func delete(_ course: Course) { update { $0.courses.removeAll { $0.id == course.id } } }
    func move(_ courses: [Course], from source: IndexSet, to destination: Int) {
        update { data in
            var day = courses; day.move(fromOffsets: source, toOffset: destination)
            let weekday = courses.first?.weekday
            guard let weekday else { return }
            data.courses.removeAll { $0.weekday == weekday }
            data.courses.append(contentsOf: day.enumerated().map { index, item in
                var c = item
                c.period = index + 1
                if let template = data.periods.first(where: { $0.number == c.period }),
                   let start = template.startMinute, let end = template.endMinute {
                    c.startMinute = start
                    c.endMinute = end
                }
                return c
            })
        }
    }

    private func setPeriodTime(_ number: Int, start: Int?, end: Int?, in data: inout ScheduleData) {
        guard let index = data.periods.firstIndex(where: { $0.number == number }) else { return }
        data.periods[index].startMinute = start
        data.periods[index].endMinute = end
    }

    private func synchronizeCourses(for number: Int, start: Int, end: Int, in data: inout ScheduleData) {
        for index in data.courses.indices where data.courses[index].period == number {
            data.courses[index].startMinute = start
            data.courses[index].endMinute = end
        }
    }
}
