# Hammerspoon 配置说明

这是一个功能丰富的 Hammerspoon 配置项目，包含多个自动化模块和快捷键设置。配置文件通过模块化设计，每个功能都被封装在独立的Lua文件中，便于维护和扩展。

所有模块都在init.lua中被加载，您可以通过编辑init.lua来启用或禁用特定功能。配置更改后，使用快捷键 **Cmd+Shift+R** 重新加载配置使其生效。

> 💡 提示：所有通知都会显示在屏幕顶部中央位置

## 修复记录

### 2026-03 AppGrid 导致顶部中键触发失效

现象：
- `init.lua` 中启用 `require("appgrid")` 后，`app_launch.lua` 的“顶部中键点击触发新建 Edge 窗口”失效
- 移除 `require("appgrid")` 后恢复正常

根因：
- 多个模块都直接使用 `hs.shutdownCallback = ...`
- 后加载的模块会覆盖先加载模块的 shutdown 回调
- `app_launch.lua` 的顶部中键监听器属于局部 `eventtap` 对象，引用链被覆盖后，监听器生命周期变得不稳定
- 顶部中键原先还是通过模拟 `Cmd+Alt+E` 间接触发 Edge，新链路更容易受其他输入模拟逻辑影响

修复：
- 新增 `shutdown_manager.lua`，统一注册各模块的 shutdown 清理函数，避免相互覆盖
- `app_launch.lua` 改为直接调用 `edge_control.lua` 导出的 `openNewEdgeWindow()`
- `edge_control.lua` 保留 `Cmd+Alt+E` 热键，但热键和顶部中键共用同一套打开 Edge 窗口逻辑

影响范围：
- `app_launch.lua`
- `appgrid.lua`
- `edge_control.lua`
- `apps_shortcuts.lua`
- `xdownie.lua`
- `open_iina.lua`
- `wheelzoom.lua`
- `ha_control.lua`

结论：
- `appgrid` 本身并没有直接抢占鼠标中键事件
- 实际问题是模块间覆盖全局 shutdown 回调，叠加“通过模拟热键间接触发功能”的链路过脆

## 模块说明

### init.lua
主配置文件，负责：
- 启用 AppleScript 支持
- 定义自定义通知样式（居中置顶）
- 加载所有功能模块
- 提供重载配置的快捷键（Cmd+Shift+R）

### app_launch.lua
应用程序启动控制模块：
- 启动 PasteNow 和 Dropover 应用
- 监听抖音窗口创建，自动移动到次屏幕并最大化
- 顶部中键点击触发新建 Edge 窗口
- 自定义通知样式

### apps_shortcuts.lua
应用程序快捷键增强模块：
- 为抖音应用提供鼠标中键快捷操作
- 中键点击时自动触发 Y 键和 J 键组合

### ha_control.lua
Home Assistant 智能家居控制模块：
- 通过配置文件（ha_config.json）管理 Home Assistant 连接参数
- Ctrl+Alt+滚轮：控制灯光亮度（向上滚动增亮，向下滚动变暗）
- F9：控制顶灯（短按开关，长按调节亮度）
- F10：控制顶灯
- F12：控制台灯（短按开关，长按调节亮度）
- F18：控制上台灯
- Ctrl+PageUp：执行"桌面开灯"场景
- Ctrl+PageDown：执行"桌面关灯"并关闭顶灯
- Cmd+Alt+Ctrl+L：重启灯光控制监听器
- 集成 display_brightness 模块实现显示器亮度自动调节

### display_brightness.lua
显示器亮度自动调节模块：
- 读取 Home Assistant 光照传感器数据
- 根据环境光照强度自动调节外接显示器亮度
- 使用 BetterDisplay 应用控制显示器

### edge_control.lua
Microsoft Edge 浏览器窗口管理：
- Cmd+Alt+E：在当前屏幕打开新的 Edge 窗口
- Cmd+Alt+M：将当前 Edge 标签页移动到其他屏幕

### xdownie.lua
视频下载自动化模块：
- 监听剪贴板内容
- 自动检测并使用 Downie 4 下载：
  - Twitter/X 视频
  - 微博视频
  - 抖音视频
  - 小红书视频
  - 新浪短链接

### open_iina.lua
视频播放自动化模块：
- 监听剪贴板内容
- 自动检测 Windows 网络视频路径（\\192.168.2.9\*.mp4, \*.mkv）
- 自动转换路径并使用系统默认播放器打开
- 支持本地 /Volumes 路径的视频文件

### folderSync.lua
文件夹自动同步工具：
- 定期同步指定的源文件夹到目标文件夹（每2小时）
- 使用 rsync 确保文件完整性
- 支持手动触发同步

### appgrid.lua
AppGrid 应用启动器触发模块：
- 鼠标移动到屏幕右下角时自动触发 AppGrid
- 支持调试模式查看触发区域
- 提供手动触发热键

### shutdown_manager.lua
退出清理回调注册模块：
- 统一管理各模块的 `hs.shutdownCallback`
- 避免模块之间互相覆盖清理回调
- 降低 `eventtap`、`timer`、`watcher` 因生命周期问题失效的风险

### virtual_keys.lua
Moonlight 虚拟按键映射模块：
- 在 Moonlight 应用中将 Cmd 键映射为 Ctrl 键
- 支持完整的 Cmd+组合键映射
- 提供多个快捷键用于调试和管理

### wheelzoom.lua
网页缩放功能模块：
- 按住 Ctrl+滚轮 时触发网页缩放
- 向上滚动放大（Cmd+=）
- 向下滚动缩小（Cmd+-）


## 快捷键总览

- Cmd+Shift+R：重新加载 Hammerspoon 配置
- Cmd+Alt+E：新建 Edge 窗口
- Cmd+Alt+M：移动 Edge 标签页到其他屏幕
- Cmd+Alt+S：手动触发文件夹同步
- Cmd+Alt+Ctrl+M：重启抖音快捷键监听器
- Cmd+Alt+Ctrl+V：重启剪贴板监听
- Ctrl+PageUp：开启所有灯光
- Ctrl+PageDown：关闭所有灯光
