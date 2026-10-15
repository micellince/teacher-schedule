import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            Text("教师课表")
                .font(.headline)
            Text("把课表小组件加入智能叠放或表盘，即可查看当前课和下一节课。")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }
}
