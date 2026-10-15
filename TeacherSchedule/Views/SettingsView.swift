import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var exportedScheduleURL: URL?
    var body: some View {
        NavigationStack {
            Form {
                Section("课程提醒") {
                    Toggle("上课提醒", isOn: Binding(get: { store.data.settings.remindersEnabled }, set: { value in store.update { $0.settings.remindersEnabled = value }; if value { Task { _ = await NotificationScheduler.shared.requestPermission() } } }))
                    if store.data.settings.remindersEnabled {
                        Picker("提前提醒", selection: Binding(get: { store.data.settings.reminderMinutes }, set: { value in store.update { $0.settings.reminderMinutes = value } })) {
                            Text("10 分钟").tag(10); Text("5 分钟").tag(5); Text("2 分钟").tag(2)
                        }
                        Toggle("上课开始时提醒", isOn: Binding(get: { store.data.settings.startReminderEnabled }, set: { value in store.update { $0.settings.startReminderEnabled = value } }))
                        Text("最多安排未来 14 天、60 条通知；每次修改课表后自动重建提醒。请在系统设置中允许通知。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("课表设置") {
                    NavigationLink("课次时间（最多10节）", destination: PeriodSettingsView())
                    NavigationLink("班级管理（最多5个）", destination: ChoiceManagerView(title: "班级管理", keyPath: \.classes))
                    NavigationLink("科目管理（最多10个）", destination: ChoiceManagerView(title: "科目管理", keyPath: \.subjects))
                }
                Section("Widget 卡片外观") {
                    ColorPicker("背景颜色", selection: colorBinding(\.widgetBackground), supportsOpacity: false)
                    ColorPicker("文字颜色", selection: colorBinding(\.widgetTextColor), supportsOpacity: false)
                    Button("恢复默认颜色") {
                        store.update {
                            $0.settings.widgetBackground = RGBAColor(red: 0.12, green: 0.13, blue: 0.17)
                            $0.settings.widgetTextColor = RGBAColor(red: 1, green: 1, blue: 1)
                        }
                    }
                    Text("主屏幕小号和中号 Widget 会使用这里的颜色。锁屏 Widget 的颜色由 iOS 控制。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("数据") {
                    Button("导出课表 JSON（用于 PWA）", systemImage: "square.and.arrow.up") {
                        exportScheduleForPWA()
                    }
                    if let exportedScheduleURL {
                        ShareLink(item: exportedScheduleURL) {
                            Label("分享或存储导出文件", systemImage: "doc.zipper")
                        }
                    }
                    Button("恢复图片中的默认课表") { store.replace(with: .sample) }
                    Button("清空课表", role: .destructive) { store.update { $0.courses = []; $0.isConfigured = true } }
                    Text("课表保存在本机 App Group 中，供主屏幕 Widget 读取。可导出 JSON，再导入 PWA；两边的数据不会自动同步。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("Teacher Schedule · 1.0").frame(maxWidth: .infinity).foregroundStyle(.secondary) }
            }.navigationTitle("设置")
        }
    }

    private func exportScheduleForPWA() {
        guard let encoded = try? JSONEncoder().encode(store.data) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TeacherSchedule.json")
        do {
            try encoded.write(to: url, options: .atomic)
            exportedScheduleURL = url
        } catch {
            exportedScheduleURL = nil
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<ScheduleSettings, RGBAColor>) -> Binding<Color> {
        Binding(
            get: {
                let value = store.data.settings[keyPath: keyPath]
                return Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.opacity)
            },
            set: { color in
                guard let components = color.cgColor?.components else { return }
                let red: CGFloat
                let green: CGFloat
                let blue: CGFloat
                let opacity: CGFloat
                if components.count >= 3 {
                    red = components[0]; green = components[1]; blue = components[2]
                    opacity = components.count > 3 ? components[3] : 1
                } else if components.count == 2 {
                    red = components[0]; green = components[0]; blue = components[0]; opacity = components[1]
                } else { return }
                store.update { $0.settings[keyPath: keyPath] = RGBAColor(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity)) }
            }
        )
    }
}

struct ChoiceManagerView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var newValue = ""
    @State private var showingAdd = false
    @State private var editedValue: String?
    @State private var renamedValue = ""
    @State private var showingRename = false
    let title: String
    let keyPath: WritableKeyPath<ScheduleSettings, [String]>
    var values: [String] { store.data.settings[keyPath: keyPath] }
    private var maximumCount: Int { title == "班级管理" ? ScheduleSettings.maximumClasses : ScheduleSettings.maximumSubjects }
    var body: some View {
        List {
            ForEach(values, id: \.self) { value in
                Button { editedValue = value; renamedValue = value; showingRename = true } label: {
                    Text(value).foregroundStyle(.primary)
                }.swipeActions {
                    Button("删除", role: .destructive) { store.update { $0.settings[keyPath: keyPath].removeAll { $0 == value } } }
                }
            }.onMove { source, destination in
                store.update { $0.settings[keyPath: keyPath].move(fromOffsets: source, toOffset: destination) }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .disabled(values.count >= maximumCount)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("\(values.count)/\(maximumCount)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal).padding(.bottom, 4)
        }
        .alert("添加\(title)", isPresented: $showingAdd) {
            TextField("名称", text: $newValue)
            Button("取消", role: .cancel) { newValue = "" }
            Button("添加") {
                let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty && !values.contains(value) && values.count < maximumCount { store.update { $0.settings[keyPath: keyPath].append(value) } }
                newValue = ""
            }
        }
        .alert("修改名称", isPresented: $showingRename) {
            TextField("名称", text: $renamedValue)
            Button("取消", role: .cancel) { editedValue = nil }
            Button("保存") {
                let value = renamedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let original = editedValue, !value.isEmpty {
                    store.update { data in
                        var items = data.settings[keyPath: keyPath]
                        if let index = items.firstIndex(of: original) { items[index] = value }
                        var unique: [String] = []
                        for item in items where !unique.contains(item) { unique.append(item) }
                        data.settings[keyPath: keyPath] = unique
                        if title == "班级管理" {
                            for index in data.courses.indices where data.courses[index].classroom == original { data.courses[index].classroom = value }
                        } else {
                            for index in data.courses.indices where data.courses[index].subject == original { data.courses[index].subject = value }
                        }
                    }
                }
                editedValue = nil
            }
        }
    }
}

private struct PeriodTimeEditor: Identifiable {
    let period: Int
    let isStart: Bool
    var id: String { "\(period)-\(isStart ? "start" : "end")" }
}

struct PeriodSettingsView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var timeEditor: PeriodTimeEditor?
    @State private var showCannotDeletePeriod = false

    var body: some View {
        List {
            Section {
                ForEach(store.data.periods.sorted { $0.number < $1.number }) { period in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("第\(period.number)节").font(.headline)
                        HStack {
                            timeButton("开始", minute: period.startMinute) {
                                timeEditor = PeriodTimeEditor(period: period.number, isStart: true)
                            }
                            Text("–").foregroundStyle(.tertiary)
                            timeButton("结束", minute: period.endMinute) {
                                timeEditor = PeriodTimeEditor(period: period.number, isStart: false)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    let sorted = store.data.periods.sorted { $0.number < $1.number }
                    let selected = offsets.map { sorted[$0] }
                    if selected.contains(where: { period in store.data.courses.contains(where: { $0.period == period.number }) }) {
                        showCannotDeletePeriod = true
                    } else {
                        store.update { data in data.periods.removeAll { selected.contains($0) } }
                    }
                }
            } header: {
                Text("最多\(ScheduleSettings.maximumPeriods)节")
            } footer: {
                Text("时间留空表示尚未设置。同一课次在任何星期修改时间，都会同步到所有星期。已有课程的课次不能删除。")
            }

            Section {
                Button("添加课次", systemImage: "plus") {
                    store.update { data in
                        guard data.periods.count < ScheduleSettings.maximumPeriods,
                              let number = (1...ScheduleSettings.maximumPeriods).first(where: { value in !data.periods.contains(where: { $0.number == value }) }) else { return }
                        data.periods.append(PeriodTemplate(number: number, startMinute: nil, endMinute: nil))
                    }
                }
                .disabled(store.data.periods.count >= ScheduleSettings.maximumPeriods)
                Text("\(store.data.periods.count)/\(ScheduleSettings.maximumPeriods) 节")
                    .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("课次时间")
        .toolbar { EditButton() }
        .alert("已有课程不能删除该课次", isPresented: $showCannotDeletePeriod) {
            Button("好", role: .cancel) {}
        } message: {
            Text("先删除或修改该课次的日程，再删除课次设置。")
        }
        .sheet(item: $timeEditor) { editor in
            let period = store.data.periods.first(where: { $0.number == editor.period })
            let initialMinute = editor.isStart
                ? (period?.startMinute ?? period?.endMinute.map { max(0, $0 - 40) } ?? 480)
                : (period?.endMinute ?? period?.startMinute.map { $0 + 40 } ?? 520)
            PeriodTimePickerSheet(
                title: "第\(editor.period)节\(editor.isStart ? "开始" : "结束")时间",
                initialMinute: initialMinute
            ) { minute in
                saveTime(minute, for: editor)
            }
        }
    }

    private func timeButton(_ label: String, minute: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label).foregroundStyle(.secondary)
                Text(minute.map(TimeText.string) ?? "未设置")
                    .foregroundStyle(minute == nil ? .tertiary : .primary)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }.font(.body.monospacedDigit())
        }
        .buttonStyle(.plain)
    }

    private func saveTime(_ minute: Int, for editor: PeriodTimeEditor) {
        guard let period = store.data.periods.first(where: { $0.number == editor.period }) else { return }
        var start = period.startMinute
        var end = period.endMinute
        if editor.isStart { start = minute } else { end = minute }
        if let startValue = start, let endValue = end, startValue >= endValue {
            if editor.isStart { end = startValue + 40 } else { start = max(0, endValue - 40) }
        }
        store.updatePeriodTime(editor.period, startMinute: start, endMinute: end)
    }
}

private struct PeriodTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let title: String
    let onSave: (Int) -> Void

    init(title: String, initialMinute: Int, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.onSave = onSave
        _date = State(initialValue: ScheduleEngine.dateAtMinute(initialMinute, on: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("时间", selection: $date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(ScheduleEngine.minuteOfDay(date)); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
