# Teacher Schedule（教师课表）

一个离线优先的原生 iOS 教师课表应用，使用 SwiftUI、WidgetKit 和 UserNotifications，不依赖服务端或第三方 SDK。

另外提供了 `TeacherSchedule/PWA/`：同一套课表数据结构和时间状态规则的主屏幕网页版本。PWA 与原生 App 分开保存数据，需要通过 JSON 文件导入/导出迁移。

## 项目内容

- `TeacherSchedule/TeacherSchedule.xcodeproj`：Xcode 项目，包含 `TeacherSchedule` App 与 `TeacherScheduleWidget` Extension 两个 Target。
- App Group：`group.com.personal.TeacherSchedule`，用于共享本机课表数据。
- 最低部署版本：iOS 17.0。
- 示例课表、每周课程编辑、课次时间模板、班级/科目管理、按周复制、课程状态首页、本地通知、小/中/锁屏 Widget。
- `ScheduleOverride` 数据结构预留特殊日期覆盖；A/B 周扩展字段已预留，第一版按普通每周循环运行。

## 构建与安装

1. 在 macOS 上用 Xcode 打开 `TeacherSchedule/TeacherSchedule.xcodeproj`。
2. 选择 `TeacherSchedule` Scheme 和你的 iPhone 或 iOS Simulator。
3. 在两个 Target 的 **Signing & Capabilities** 中选择你的 Apple ID Team。项目已配置 App Groups；若 Xcode 要求，确认 `group.com.personal.TeacherSchedule` 已由该 Team 注册并勾选。
4. 连接并信任 iPhone，在设备上启用 Developer Mode（如系统提示），然后点击 Run。
5. 在主屏幕长按添加 Widget。首次启用课程提醒时允许通知。

免费 Apple ID 通常可用于个人设备签名安装，但签名有效期和可安装设备受 Apple 当前政策限制；开发者账号的签名配置以 Xcode 实际提示为准。

## 数据与提醒

课表以 Codable 编码保存在 App Group UserDefaults。每次数据更新会请求 WidgetKit 刷新，并取消旧提醒、在未来 14 天内重新排程（最多 60 条待发送提醒）。iOS 会自行调度 Widget Timeline，刷新时间可能受系统资源策略影响。

## PWA 桌面课表

- 入口：`TeacherSchedule/PWA/index.html`；包含桌面实时倒计时、当天课程、周课表编辑、班级/学科、课次时间、颜色设置和 JSON 备份导入/导出。
- PWA 使用浏览器本机存储，支持离线打开；不需要账号或服务器保存个人课表。iOS 会暂停后台网页，因此倒计时在页面打开时逐秒更新，回到页面后会按当前时间重新计算。
- 首次安装到 iPhone 主屏幕需要通过 HTTPS 访问。把 `TeacherSchedule/PWA/` 目录发布到任意静态 HTTPS 主机后，用 iPhone Safari 打开地址，再选 **分享 → 添加到主屏幕**。
- 原生 App 的“设置 → 数据 → 导出课表 JSON（用于 PWA）”可以把现有课程带到 PWA；在 PWA 的“设置 → 备份与迁移”导入。两边之后不会自动同步。

## 当前状态

原生 iOS App、iPhone Widget 和 Watch Widget 保留在 Xcode 项目中；本次新增的 PWA 是可独立部署的静态网页版本。iPhone 添加到主屏幕前，需先把 `TeacherSchedule/PWA/` 发布到 HTTPS 地址。PWA 尚未托管到线上，也尚未在实体 iPhone 上安装验证。

## Android APK

`TeacherScheduleAndroid/` 是离线 Android 应用，包含上课前 5 分钟系统通知、桌面组件，以及 JSON 导入/导出。个人侧载 APK 已生成在 `TeacherScheduleAndroid/教师课表.apk`，安装后在“设置”开启提醒；桌面组件通过长按桌面空白处添加。也可用 Android Studio 打开该目录并构建 `app` 的 `assembleDebug` 重新生成，无需上架商店。
