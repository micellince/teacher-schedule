import SwiftUI

private struct DayChoice: Identifiable {
    let weekday: Int
    let label: String
    var id: Int { weekday }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var weekday = Calendar.current.component(.weekday, from: .now)
    @State private var editing: Course?
    @State private var adding = false
    @State private var copySource: Int?
    private let days: [DayChoice] = [DayChoice(weekday: 2, label: "周一"), DayChoice(weekday: 3, label: "周二"), DayChoice(weekday: 4, label: "周三"), DayChoice(weekday: 5, label: "周四"), DayChoice(weekday: 6, label: "周五"), DayChoice(weekday: 7, label: "周六"), DayChoice(weekday: 1, label: "周日")]

    private var courses: [Course] { store.data.courses.filter { $0.weekday == weekday }.sorted(by: ScheduleEngine.courseOrder) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(days) { day in
                        Button(day.label) { weekday = day.weekday }.buttonStyle(.borderedProminent).tint(weekday == day.weekday ? .indigo : .gray.opacity(0.15)).foregroundStyle(weekday == day.weekday ? .white : .primary)
                    } }.padding()
                }
                List {
                    if courses.isEmpty { ContentUnavailableView("这天还没有课程", systemImage: "calendar.badge.plus", description: Text("点击下方按钮添加课程。")) }
                    ForEach(courses) { course in
                        Button { editing = course } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("第\(course.period)节").font(.headline)
                                    Text("\(TimeText.string(course.startMinute)) – \(TimeText.string(course.endMinute))").font(.subheadline).foregroundStyle(.secondary)
                                }.frame(width: 130, alignment: .leading)
                                VStack(alignment: .leading, spacing: 5) { Text(course.classroom).font(.headline); Text(course.displaySubject).font(.subheadline).foregroundStyle(.secondary) }
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }.onDelete { indexes in indexes.map { courses[$0] }.forEach(store.delete) }
                    .onMove { source, destination in store.move(courses, from: source, to: destination) }
                    Section {
                        Button { adding = true } label: { Label("添加课程", systemImage: "plus.circle.fill") }.frame(maxWidth: .infinity, alignment: .center)
                    }
                }.listStyle(.insetGrouped)
            }
            .navigationTitle("周课表")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("复制到其他星期…", systemImage: "doc.on.doc") { copySource = weekday }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .confirmationDialog("复制到星期", isPresented: Binding(get: { copySource != nil }, set: { if !$0 { copySource = nil } }), titleVisibility: .visible) {
                ForEach(days.filter { $0.weekday != copySource }) { day in
                    Button(day.label) { if let source = copySource { copySchedule(from: source, to: day.weekday) }; copySource = nil }
                }
            }
            .sheet(isPresented: $adding) { CourseEditorView(course: nil, weekday: weekday) }
            .sheet(item: $editing) { CourseEditorView(course: $0) }
        }
    }
    private func copySchedule(from source: Int, to destination: Int) {
        store.update { data in
            let copied = data.courses.filter { $0.weekday == source }.map { course -> Course in var c = course; c.id = UUID(); c.weekday = destination; return c }
            data.courses.removeAll { $0.weekday == destination }
            data.courses.append(contentsOf: copied)
        }
    }
}

struct CourseEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var course: Course
    @State private var isNew: Bool
    @State private var showDelete = false
    @State private var isAddingClass = false
    @State private var isAddingSubject = false
    @State private var classDraft = ""
    @State private var subjectDraft = ""
    @State private var hasStartTime: Bool
    @State private var hasEndTime: Bool
    private let weekdays: [(Int,String)] = [(2,"星期一"),(3,"星期二"),(4,"星期三"),(5,"星期四"),(6,"星期五"),(7,"星期六"),(1,"星期日")]
    init(course: Course?, weekday: Int = 2) {
        let value = course ?? Course(weekday: weekday, period: 1, startMinute: 480, endMinute: 520, classroom: "", subject: "")
        _course = State(initialValue: value)
        _isNew = State(initialValue: course == nil)
        _hasStartTime = State(initialValue: course != nil)
        _hasEndTime = State(initialValue: course != nil)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("课程信息") {
                    Picker("星期", selection: $course.weekday) { ForEach(weekdays, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker("课次", selection: $course.period) {
                        ForEach(store.data.periods.sorted { $0.number < $1.number }) { p in
                            let time = periodTimeLabel(p)
                            Text("第\(p.number)节 · \(time)").tag(p.number)
                        }
                    }.onChange(of: course.period) { _, value in
                        if let template = store.data.periods.first(where: { $0.number == value }),
                           let start = template.startMinute, let end = template.endMinute {
                            course.startMinute = start
                            course.endMinute = end
                            hasStartTime = true
                            hasEndTime = true
                        } else if isNew {
                            hasStartTime = false
                            hasEndTime = false
                        }
                    }
                    Menu {
                        ForEach(availableClasses, id: \.self) { item in Button(item) { course.classroom = item } }
                        Button("＋ 添加常用班级…") { isAddingClass = true }
                            .disabled(store.data.settings.classes.count >= ScheduleSettings.maximumClasses)
                    } label: {
                        LabeledContent("班级", value: course.classroom.isEmpty ? "先添加常用班级" : course.classroom)
                            .foregroundStyle(course.classroom.isEmpty ? .secondary : .primary)
                    }
                    if isAddingClass {
                        HStack {
                            TextField("例如：五年级一班", text: $classDraft)
                            Button("添加并使用") { addChoice(classDraft, to: \.classes, selection: \.classroom, limit: ScheduleSettings.maximumClasses); classDraft = "" }
                                .disabled(classDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.data.settings.classes.count >= ScheduleSettings.maximumClasses)
                        }
                        Text("最多\(ScheduleSettings.maximumClasses)个班级（\(store.data.settings.classes.count)/\(ScheduleSettings.maximumClasses)）")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if store.data.settings.classes.isEmpty {
                        Text("先添加你常带的班级，之后排课时就能直接选择。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Menu {
                        ForEach(availableSubjects, id: \.self) { item in Button(item) { course.subject = item } }
                        Button("＋ 添加常用学科…") { isAddingSubject = true }
                            .disabled(store.data.settings.subjects.count >= ScheduleSettings.maximumSubjects)
                    } label: {
                        LabeledContent("学科", value: course.subject.isEmpty ? "先添加常用学科" : course.subject)
                            .foregroundStyle(course.subject.isEmpty ? .secondary : .primary)
                    }
                    if isAddingSubject {
                        HStack {
                            TextField("例如：数学", text: $subjectDraft)
                            Button("添加并使用") { addChoice(subjectDraft, to: \.subjects, selection: \.subject, limit: ScheduleSettings.maximumSubjects); subjectDraft = "" }
                                .disabled(subjectDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.data.settings.subjects.count >= ScheduleSettings.maximumSubjects)
                        }
                        Text("最多\(ScheduleSettings.maximumSubjects)个科目（\(store.data.settings.subjects.count)/\(ScheduleSettings.maximumSubjects)）")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if store.data.settings.subjects.isEmpty {
                        Text("先添加你常教的学科，之后排课时就能直接选择。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    TextField("备注（可选）", text: $course.note, axis: .vertical)
                }
                Section("上课时间") {
                    if hasStartTime {
                        DatePicker("开始", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    } else {
                        Button("设置开始时间") { hasStartTime = true }
                    }
                    if hasEndTime {
                        DatePicker("结束", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                    } else {
                        Button("设置结束时间") { hasEndTime = true }
                    }
                    if isNew && (!hasStartTime || !hasEndTime) {
                        Text("该课次还没有默认时间，请设置开始和结束时间。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !isNew { Section { Button("删除课程", role: .destructive) { showDelete = true } } }
            }
            .navigationTitle(isNew ? "添加课程" : "编辑课程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(course.classroom.trimmingCharacters(in: .whitespaces).isEmpty || course.subject.trimmingCharacters(in: .whitespaces).isEmpty || !hasStartTime || !hasEndTime || course.endMinute <= course.startMinute) }
            }
            .confirmationDialog("删除这节课？", isPresented: $showDelete, titleVisibility: .visible) {
                Button("删除课程", role: .destructive) { store.delete(course); dismiss() }
            }
            .onAppear {
                if isNew,
                   let template = store.data.periods.first(where: { $0.number == course.period }),
                   let start = template.startMinute, let end = template.endMinute {
                    course.startMinute = start
                    course.endMinute = end
                    hasStartTime = true
                    hasEndTime = true
                }
            }
        }
    }
    private func minuteBinding(_ keyPath: WritableKeyPath<Course, Int>) -> Binding<Date> {
        Binding(get: { ScheduleEngine.dateAtMinute(course[keyPath: keyPath], on: .now) ?? .now }, set: { course[keyPath: keyPath] = ScheduleEngine.minuteOfDay($0) })
    }
    private var availableClasses: [String] { Array(Set(store.data.settings.classes + (course.classroom.isEmpty ? [] : [course.classroom]))).sorted() }
    private var availableSubjects: [String] { Array(Set(store.data.settings.subjects + (course.subject.isEmpty ? [] : [course.subject]))).sorted() }
    private func periodTimeLabel(_ period: PeriodTemplate) -> String {
        guard let start = period.startMinute, let end = period.endMinute else { return "时间未设置" }
        return "\(TimeText.string(start))–\(TimeText.string(end))"
    }
    private func addChoice(_ draft: String, to keyPath: WritableKeyPath<ScheduleSettings, [String]>, selection: WritableKeyPath<Course, String>, limit: Int) {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              store.data.settings[keyPath: keyPath].contains(value) || store.data.settings[keyPath: keyPath].count < limit else { return }
        store.update { data in if !data.settings[keyPath: keyPath].contains(value) { data.settings[keyPath: keyPath].append(value) } }
        course[keyPath: selection] = value
        isAddingClass = false
        isAddingSubject = false
    }
    private func save() { if isNew { store.add(course) } else { store.update(course) }; dismiss() }
}
