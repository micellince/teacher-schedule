import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var selectedCourse: Course?
    @State private var showingEditor = false
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(now.formatted(date: .omitted, time: .shortened)).font(.system(size: 58, weight: .light, design: .rounded)).monospacedDigit()
                                .accessibilityLabel("当前时间 \(now.formatted(date: .omitted, time: .shortened))")
                            Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.title3).foregroundStyle(.secondary)
                        }
                        statusCard(at: now)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text("今日课程").font(.title2.bold()); Spacer(); Text("\(ScheduleEngine.coursesForToday(in: store.data, at: now).count) 节").foregroundStyle(.secondary) }
                            let courses = ScheduleEngine.coursesForToday(in: store.data, at: now)
                            if courses.isEmpty {
                                ContentUnavailableView("今日无课程", systemImage: "calendar", description: Text("可以在课表页添加课程。"))
                            } else {
                                ForEach(courses) { course in
                                    let current = ScheduleEngine.currentCourse(in: store.data, at: now)?.id == course.id
                                    let ended = ScheduleEngine.minuteOfDay(now) >= course.endMinute
                                    Button { selectedCourse = course; showingEditor = true } label: {
                                        HStack(spacing: 14) {
                                            Text(ended ? "✓" : (current ? "●" : "" )).font(.title3.bold()).foregroundStyle(current ? .indigo : .secondary).frame(width: 24)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("第\(course.period)节  ·  \(TimeText.string(course.startMinute))–\(TimeText.string(course.endMinute))").font(.subheadline).foregroundStyle(.secondary)
                                                Text("\(course.classroom) · \(course.subject)").font(.headline).foregroundStyle(.primary)
                                            }
                                            Spacer()
                                            if current { Image(systemName: "chevron.right").foregroundStyle(.indigo) }
                                        }.padding(14).background(current ? Color.indigo.opacity(0.10) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("教师课表").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditor) { if let selectedCourse { CourseEditorView(course: selectedCourse) } }
        }
    }

    @ViewBuilder private func statusCard(at date: Date) -> some View {
        switch ScheduleEngine.state(in: store.data, at: date) {
        case .inClass(let course):
            VStack(alignment: .leading, spacing: 16) {
                Label("第 \(course.period) 节课 · 正在上课", systemImage: "play.circle.fill")
                    .font(.headline).foregroundStyle(.indigo)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.classroom).font(.system(size: 27, weight: .semibold))
                        Text(course.subject).font(.system(size: 36, weight: .bold))
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("下课还剩").font(.subheadline).foregroundStyle(.secondary)
                        Text(TimeText.countdown(ScheduleEngine.remainingTime(in: store.data, at: date) ?? 0))
                            .font(.system(size: 27, weight: .bold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText())
                    }.padding(.bottom, 4)
                }
                HStack(spacing: 10) {
                    Text(TimeText.string(course.startMinute))
                    ProgressView(value: progress(for: course, at: date)).tint(.indigo)
                    Text(TimeText.string(course.endMinute))
                }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
        case .breakTime(let next):
            VStack(alignment: .leading, spacing: 12) {
                let first = ScheduleEngine.coursesForToday(in: store.data, at: date).first
                let isBeforeFirst = first.map { ScheduleEngine.minuteOfDay(date) < $0.startMinute } ?? false
                Label(isBeforeFirst ? "课前" : "课间", systemImage: isBeforeFirst ? "sunrise" : "cup.and.saucer.fill").font(.headline).foregroundStyle(.orange)
                if let next {
                    Text("下一节 · 第 \(next.period) 节").font(.title2.bold())
                    Text("\(next.classroom) · \(next.subject)").font(.title3)
                    HStack {
                        Text("\(TimeText.string(next.startMinute)) 开始")
                        Spacer()
                        if let start = ScheduleEngine.dateAtMinute(next.startMinute, on: date) {
                            HStack(spacing: 5) {
                                Text("距离上课")
                                Text(TimeText.countdown(start.timeIntervalSince(date))).monospacedDigit().contentTransition(.numericText())
                            }.font(.title3.weight(.semibold)).foregroundStyle(.primary)
                        }
                    }.foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
        case .finished(let last, let next):
            VStack(alignment: .leading, spacing: 10) {
                Label("今日课程已结束", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(.green)
                if let last { Text("最后一节 · 第\(last.period)节").font(.subheadline).foregroundStyle(.secondary); Text("\(last.classroom) · \(last.subject)").font(.title3.bold()) }
                if let next { Divider(); Text("下一节 · \(next.classroom) · \(next.subject)").font(.subheadline); Text("第\(next.period)节 · \(TimeText.string(next.startMinute)) 开始").foregroundStyle(.secondary) }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
        case .noClasses(let next):
            VStack(alignment: .leading, spacing: 10) {
                Label("今日无课", systemImage: "calendar").font(.headline).foregroundStyle(.secondary)
                if let next { Text("下一节 · \(next.classroom) · \(next.subject)").font(.subheadline); Text("第\(next.period)节 · \(TimeText.string(next.startMinute))").foregroundStyle(.secondary) }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private func progress(for course: Course, at date: Date) -> Double {
        let span = max(1, course.endMinute - course.startMinute)
        return min(1, max(0, Double(ScheduleEngine.minuteOfDay(date) - course.startMinute) / Double(span)))
    }
}
