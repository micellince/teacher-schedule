//
//  TeacherScheduleWatchApp.swift
//  TeacherScheduleWatch Watch App
//
//  Created by micellince on 2026/9/28.
//

import SwiftUI
import WatchKit

@main
struct TeacherScheduleWatch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchScheduleReceiver.self) private var receiver

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
