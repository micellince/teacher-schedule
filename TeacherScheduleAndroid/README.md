# 教师课表 Android APK

这是一个离线 Android 应用，打包 PWA 课表界面。数据保存在应用本机存储，不需要账号或网络。包含上课前 5 分钟的系统通知、安卓桌面组件，以及 JSON 导入/导出。

## 构建

使用 Android Studio 打开 `TeacherScheduleAndroid`，安装 Android SDK Platform 35，运行 Gradle 任务 `app > Tasks > build > assembleDebug`。生成的 APK：

`app/build/outputs/apk/debug/app-debug.apk`

把 APK 传到 Android 手机上打开，按系统提示允许安装此来源的应用即可。首次打开后，在“设置”里开启上课提醒并允许系统通知。添加桌面组件：长按桌面空白处 → 小组件 → 教师课表。它是 debug 签名的个人安装包，不用于应用商店发布。

当前生成的安装包也放在本目录的 `教师课表.apk`。
