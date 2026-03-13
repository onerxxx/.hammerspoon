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

## 新人快速上手

### 1) 先理解整体结构

本仓库是一个「按功能拆分模块」的 Hammerspoon 配置：

- `init.lua` 是唯一入口：负责加载各模块和绑定全局重载热键。
- `*.lua` 文件是具体自动化能力模块（窗口管理、剪贴板监听、智能家居、快捷键增强等）。
- `ha_config.json` / `ha_config_template.json` 是 Home Assistant 连接配置（地址、令牌、设备映射）。
- `Spoons/` 放第三方 Spoon（当前主要是 `SpoonInstall`，用于依赖管理）。
- `clash-verge-parsers.js` 是独立于 Hammerspoon 的代理规则处理脚本。

### 2) 需要优先掌握的关键内容

建议按下面顺序读代码（越靠前越基础）：

1. **`init.lua`**：看清楚“哪些模块会在启动时被加载”，理解启动顺序与入口设计。
2. **`app_launch.lua`**：包含较多基础能力复用（应用启动、窗口过滤、屏幕判断、提示样式）。
3. **`apps_shortcuts.lua` / `edge_control.lua`**：理解事件监听 + 快捷键绑定的典型写法。
4. **`xdownie.lua` / `open_iina.lua`**：理解剪贴板轮询与 URL 模式匹配。
5. **`ha_control.lua` + `ha_config.json`**：理解配置驱动的外部 API 调用（Home Assistant）。

### 3) 常见维护点

- 新增功能优先拆成独立模块，并在 `init.lua` 中按需 `require`。
- 所有热键都要避免冲突，新增前先全局检查已绑定组合键。
- 含轮询/监听器的模块（剪贴板、鼠标、窗口）要注意“重复加载”导致的多实例问题。
- 涉及本机路径、应用名、Bundle ID 的逻辑，迁移到新机器时最容易失效。
- 涉及密钥/令牌（如 HA Token）必须放配置文件，不要写死在脚本里。

### 4) 建议的学习路径

- 第 1 周：只做“读 + 改提示文案 + 改热键”这类低风险改动，熟悉热重载流程。
- 第 2 周：尝试新增一个简单模块（例如“打开固定网站/应用”），练习模块化组织。
- 第 3 周：接触事件监听和窗口管理模块，学习如何做防抖、节流和资源清理。
- 第 4 周：再进入 Home Assistant / AppleScript 这类对外部依赖更强的能力。

### 5) 调试建议

- 每次改完先 `Cmd + Shift + R` 热重载，再用 Console 看日志输出。
- 给监听器加明显前缀日志（如 `[xdownie]`），方便区分来源。
- 出现“行为重复触发”优先检查：是否重复创建 watcher / timer。
