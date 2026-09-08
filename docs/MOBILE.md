# Android 导出与真机验收

本次环境实际验证：Windows + Godot **4.6.stable.official.89cea1439**。未安装 JDK、Android SDK、导出模板，未连接 Android 手机；**未生成或安装 APK，未做 Android/iOS 真机测试**。Android 预设已写入 export_presets.cfg，以下步骤需要具备环境后执行。

## Android

1. 安装 Godot 4.6 Standard 和相同版本 Export Templates（编辑器 → 管理导出模板）。
2. 安装 OpenJDK 17、Android Studio，首次运行完成 SDK 初始化。
3. 按 Godot 4.6 文档安装 platform-tools >=35、build-tools 35.0.1、platforms android-35、cmdline-tools latest、CMake 3.10.2.4988404、NDK 28.1.13356709。这里固定的是项目对应版本工具链；上架前重新核对商店当期 target SDK 要求。
4. 在 Godot 编辑器设置 → Export → Android 设置 Java SDK Path 和 Android SDK Path。无须账号或任何运行时服务。
5. 打开项目 → 导出 → Android。包名为 studio.pocketlab.sandbox，ARMv7 与 ARM64 开启，Internet/外部存储权限关闭，Vibrate 开启。检查最低/目标 API 和签名配置。
6. 使用编辑器生成的 debug keystore 导出调试 APK，或执行：

```powershell
& '<GODOT_EXECUTABLE>' --headless --path '<PROJECT_DIR>' --export-debug Android 'builds/PocketLab.apk'
```

7. 手机开启开发者选项和 USB 调试，连接 USB 并在手机确认调试授权：

```powershell
adb devices
adb install -r '.\builds\PocketLab.apk'
adb shell am start -n studio.pocketlab.sandbox/com.godot.game.GodotApp
adb logcat -s godot
```

如果设备已有同包名但不同签名版本，直接覆盖会失败。卸载会删除本地作品；保留原签名或先通过调试工具备份数据，不要盲目卸载。

8. 应用打开即进入桌面。按下表逐项真机验证。发布 Play AAB 时启用 Gradle 构建、安装 Android build template，使用开发者自己的 release 签名；不要提交密钥。此次不包含上架或签名凭证。

官方参考：[Godot 4.6 Android 导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)。

## 真机验收表（待执行）

| 测试 | 操作及期望 |
| --- | --- |
| 首开 | 无菜单/网络等待，进入可操作桌面 |
| 五种道具 | 各拖出一次；斜坡改变滚动，磁铁吸引，风扇推动，弹簧振荡 |
| 弹簧 | 点工具后点球与空白、球与球；点弹簧解除；撤销恢复 |
| 编辑 | 拖动、左右旋转、复制、复位、删除、暂停、清空、撤销 |
| 多指/误触 | 第二根手指不抢走物体；拖出屏幕不产生极端抛速 |
| 保存 | 连续编辑后 Home 回桌面，再返回；杀进程再打开，图和偏好恢复 |
| 随机 | 重新组合后撤销；重启后设置中恢复上一组合 |
| 作品 | 保存、自建新场景、打开作品；原场景仍可撤销 |
| 音频/触觉 | 各自独立开关；静音启动；高密度碰撞无刺耳叠音/持续震动 |
| 屏幕 | 16:9、19.5:9、20:9；刘海、手势导航区域不遮挡按钮 |
| 性能 | 10、24、48 球各运行 10 分钟；记录 FPS、帧耗时、发热、耗电 |
| 离线 | 飞行模式重新启动并完整完成添加/保存/打开作品 |

“性能信息”当前显示渲染 FPS、配置的 PHYS 60 Hz、球数及种子。PHYS 是固定设定值，不是实时吞吐测量；真实物理耗时请用 Godot Profiler/Android 性能工具。建议中端机目标 60 FPS，严重受限设备至少稳定 30 FPS 后再确定默认上限。

## iOS 后续适配

需要 macOS、Xcode、相同 Godot 导出模板与开发者签名；Windows 无法完成 iOS 原生导出/签名。添加 iOS 导出预设后填写合法 Team ID、独立 Bundle ID，导出无空格命名的 Xcode 工程，在 Xcode 配置签名并连接设备构建。本项目没有伪造 Team ID，因此不提供可误用的签名预设。

GDScript、2D 物理、JSON 本地存储和单指 ScreenTouch/ScreenDrag 可共用。专项检查安全区域、Home indicator、来电/锁屏恢复、音频静音行为、60/120 Hz 显示、沙箱文件写入。Input.vibrate_handheld 是基础触觉适配，Android 需 Vibrate 权限；iOS 的持续时间/幅度和部分机型支持有限，不可假设两端一致。需要更细腻触感时再做独立原生桥接，核心玩法不得依赖它。

参考：[Godot 4.6 iOS 导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html)。后续在实际 Xcode/Godot 组合下核对设备与系统最低版本要求。

## 0.3 手机轻动专项（待真机验证）

Android 重力和加速度开关已在 project.godot 启用。分别验证自然握持、平放、左右倾斜、快速晃动及地铁模拟扰动；确认动态球轻微响应而固定道具保持。打开参数面板、拖动时不响应，切后台再回来重新校准。“随手机轻动”关闭并重启后保持关闭。iOS 需在 macOS/Xcode 与实体设备检验传感器方向和可用性；无传感器时触摸玩法继续。默认竖屏，不要未经轴向映射适配开启横屏。

交互验收以 REVISION-V3.md 为准：旧版浮动工具条和旋转把手已经取消，改用长按底部面板实时编辑。当前未执行 Android/iOS 真机验收。
