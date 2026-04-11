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

#### F9 当前控制方法

- 短按 `F9`：切换顶灯开关，实际调用的是 HA 里的按钮实体 `button.yeelink_colora_6b37_toggle`
- 长按 `F9` 超过 `0.5` 秒：进入亮度调节模式，每 `0.12` 秒调整一次亮度
- 亮度方向规则：
  - 当前亮度低于约 `2%` 时，长按会强制进入“增亮”
  - 当前亮度高于约 `90%` 时，长按会强制进入“减亮”
  - 其余情况下，每次长按会在“增亮 / 减亮”之间切换方向
- 亮度步进约为 `5%`，范围限制在 `1` 到 `255`
- 当前亮度控制采用“本地先算，再异步发送”：
  - 按下 `F9` 时会后台读取一次 HA 当前亮度，作为本地缓存的参考值
  - 真正调节时，先在本地更新 `f9CurrentBrightness`
  - 然后只把“最新目标亮度值”发送给 HA，而不是每次都等待 HA 返回当前亮度再继续算下一步
  - 如果网络慢或灯具响应慢，请求会串行发送；后续变化会覆盖为最新目标值，避免旧请求堆积
- 这样做的目的，是让长按调光的手感由本地状态驱动，不再明显受灯具响应延迟影响

### display_brightness.lua
显示器亮度自动调节模块：
- 读取 Home Assistant 光照传感器数据
- 根据环境光照强度自动调节外接显示器亮度
- 使用 BetterDisplay 应用控制显示器
- 监控的光照传感器实体为 `sensor.xiaomi_pir1_45bb_illumination`
- 启动后会先延迟一段时间再开始监控：
  - `fastReload = true` 时延迟 20 秒
  - 否则延迟 15 秒
- 监控周期为每 5 分钟一次
- 只有在以下条件同时满足时才会调整亮度：
  - 当前光照值与上次记录值相比变化超过 4 lux
  - 距离上次亮度调整已超过 5 分钟
- 当前内置的显示器亮度映射策略如下：
  - `illumination < 30` 时：LG `30%`，AOC `50%`
  - `30 <= illumination <= 38` 时：LG `31%`，AOC `51%`
  - `illumination > 38` 时：LG `32%`，AOC `52%`
- 当前通过 BetterDisplay CLI 控制以下两台显示器：
  - `LG HDR WQHD`
  - `AOC 27″`

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

### appgrid.lua
AppGrid 应用启动器触发模块：
- 鼠标移动到屏幕右下角时自动触发 AppGrid
- 支持调试模式查看触发区域
- 提供手动触发热键

## 快捷键总览

- Cmd+Shift+R：重新加载 Hammerspoon 配置
- Cmd+Alt+E：新建 Edge 窗口
- Cmd+Alt+M：移动 Edge 标签页到其他屏幕
- Cmd+Alt+S：手动触发文件夹同步
- Cmd+Alt+Ctrl+M：重启抖音快捷键监听器
- Cmd+Alt+Ctrl+V：重启剪贴板监听
- Ctrl+PageUp：开启所有灯光
- Ctrl+PageDown：关闭所有灯光
