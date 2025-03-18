# Hammerspoon 配置说明

这是一个功能丰富的 Hammerspoon 配置项目，包含多个自动化模块和快捷键设置。

## 模块说明

### init.lua
主配置文件，负责：
- 禁用窗口动画效果
- 加载其他功能模块
- 提供重载配置的快捷键（Cmd+Shift+R）

### ha_control.lua
Home Assistant 智能家居控制模块：
- 通过配置文件（ha_config.json）管理 Home Assistant 连接参数
- 提供智能家居设备的控制功能
- 自定义通知样式

### lights_control.lua
灯光控制快捷键模块：
- F18 键：执行"灯光全开"场景
- F17 键：执行"关灯"场景

### edge_control.lua
Microsoft Edge 浏览器窗口管理：
- Cmd+Alt+E：在当前屏幕打开新的 Edge 窗口
- Cmd+Alt+M：将当前 Edge 标签页移动到其他屏幕

### xdownie.lua
视频下载自动化模块：
- 监听剪贴板内容
- 自动检测并使用 Downie 4 下载：
  - Twitter 视频
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

### wheelzoom.lua
网页缩放控制模块：
- 提供网页缩放功能
- 支持手动开启/关闭功能（Cmd+Alt+Ctrl+Z）
- 包含自动清理资源的功能
