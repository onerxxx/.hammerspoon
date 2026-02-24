# Hammerspoon 配置说明

这是一个功能丰富的 Hammerspoon 配置项目，包含多个自动化模块和快捷键设置。配置文件通过模块化设计，每个功能都被封装在独立的Lua文件中，便于维护和扩展。

所有模块都在init.lua中被加载，您可以通过编辑init.lua来启用或禁用特定功能。配置更改后，使用快捷键Cmd+Shift+R重新加载配置使其生效。

## 模块说明

### init.lua
主配置文件，负责：
- 禁用窗口动画效果
- 加载其他功能模块
- 提供重载配置的快捷键（Cmd+Shift+R）

### app_launch.lua
应用程序启动控制模块：
- 提供应用程序启动函数，避免重复启动
- 自定义通知样式，使用美观的半透明提示
- 在Hammerspoon启动时自动运行PasteNow应用

### apps_shortcuts.lua
应用程序快捷键增强模块：
- 为抖音应用提供鼠标中键快捷操作
- 中键点击时自动触发Y键和J键组合
- 提供重启监听器的快捷键（Cmd+Alt+Ctrl+M）

### ha_control.lua
Home Assistant 智能家居控制模块：
- 通过配置文件（ha_config.json）管理 Home Assistant 连接参数
- 提供智能家居设备的控制功能
- 自定义通知样式

### edge_control.lua
Microsoft Edge 浏览器窗口管理：
- Cmd+Alt+E：在当前屏幕打开新的 Edge 窗口
- Cmd+Alt+M：将当前 Edge 标签页移动到其他屏幕

### xdownie.lua
视频下载自动化模块：
- 监听剪贴板内容
- 自动检测并使用 Downie 4 下载：
  - Twitter视频
  - 微博视频
  - 抖音视频
  - 新浪短链接

### open_iina.lua
网络视频自动播放模块：
- 监听剪贴板内容
- 自动检测网络视频文件路径
- 使用系统默认播放器打开视频文件
- 支持网络路径转换

### folderSync.lua
文件夹自动同步工具：
- 定期同步指定的源文件夹到目标文件夹
- 使用 rsync 确保文件完整性
- 每两小时自动执行同步
- 支持手动触发同步（Cmd+Alt+S）



## 快捷键总览

- Cmd+Shift+R：重新加载 Hammerspoon 配置
- Cmd+Alt+E：新建 Edge 窗口
- Cmd+Alt+M：移动 Edge 标签页到其他屏幕
- Cmd+Alt+S：手动触发文件夹同步
- Cmd+Alt+Ctrl+M：重启抖音快捷键监听器
- Cmd+Alt+Ctrl+V：重启剪贴板监听
- Ctrl+PageUp：开启所有灯光
- Ctrl+PageDown：关闭所有灯光
