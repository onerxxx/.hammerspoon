# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## 项目定位
这是一个 macOS Hammerspoon 配置仓库：Lua 脚本在 Hammerspoon 运行时加载执行，不存在传统意义上的 build/lint/test 流水线。

## 常用开发/调试方式
- 重载整个配置：`Cmd+Shift+R`（见 `init.lua`）
- 仅重载单个模块（在 Hammerspoon Console 执行）：
  - `package.loaded["模块名"] = nil; require("模块名")`
  - 适用于调试某个 watcher/热键模块，避免每次全量重载

## 代码结构（大图景）

### 入口与加载顺序
入口文件是 `init.lua`：
- 开启 AppleScript：`hs.allowAppleScript(true)`
- 通过 `require()` 加载模块（当前顺序）：
  1) `folderSync`
  2) `xdownie`
  3) `ha_control`
  4) `edge_control`
  5) `open_iina`
  6) `apps_shortcuts`
  7) `app_launch`
- 绑定全局重载热键（Cmd+Shift+R）

模块通常在被 `require()` 时就会“自启动”（注册 hotkey / timer / eventtap 等），仓库里基本没有统一的“main/start”编排层。

### 模块类型划分（按运行机制）
- 定时轮询（`hs.timer.new/doEvery`）
  - `xdownie.lua`：0.5s 轮询剪贴板，识别特定链接后用 Downie 4 打开
  - `open_iina.lua`：0.5s 轮询剪贴板，识别视频路径后 `open` 播放，并清空剪贴板
  - `folderSync.lua`：2 小时执行一次 `rsync` 同步，并在启动时立即同步
- 输入/鼠标事件监听（`hs.eventtap`）
  - `apps_shortcuts.lua`：监听鼠标中键（otherMouseDown），在“抖音”窗口内触发按键序列
  - `wheelzoom.lua`：监听滚轮 + ctrl，实现网页缩放（本文件目前**未在 `init.lua` 加载**）
  - `virtual_keys.lua`：复杂的键盘事件映射（Moonlight 场景，本文件目前**未在 `init.lua` 加载**）
- AppleScript 自动化（`hs.osascript.applescript`）
  - `edge_control.lua`：创建 Edge 新窗口、移动标签页到新窗口并放到目标屏幕
  - `ha_control.lua`：通过 AppleScript 调用 macOS Shortcuts（`shortcuts run 'Deskon'/'Deskoff'`）
- HTTP 调用（`hs.http.asyncGet/asyncPost`）
  - `ha_control.lua`：调用 Home Assistant REST API（灯光 toggle、亮度、场景等）
  - `display_brightness.lua`：通过 HA 获取光照传感器值，用 BetterDisplay CLI 调外接显示器亮度

### Home Assistant 相关模块的关系
- `ha_control.lua` 是智能家居控制的中心模块：
  - 启动时读取 `ha_config.json`（`baseUrl/entityId/token/...`）
  - 文件末尾明确标注“快捷键设置区域”，主要交互都在这一段
  - 初始化时会调用 `display_brightness.init(...)` 并启动光照监控（见文件末尾）
- `display_brightness.lua` 使用 `config.token/baseUrl` 请求 HA 的传感器状态，并调用 BetterDisplay CLI 设置外接显示器亮度。

### 关键约定 / 易踩坑
- `hs.shutdownCallback` 是全局单值：仓库中多个模块（如 `xdownie.lua`、`open_iina.lua`、`apps_shortcuts.lua` 等）都会直接赋值 `hs.shutdownCallback = ...`，后加载的模块会覆盖先前的清理逻辑。
  - 如果你新增/修改模块需要做清理，优先检查现有 `hs.shutdownCallback` 是否已被占用，并考虑改成集中管理。
- `ha_config.json` 当前包含 `token` 字段（并且 `ha_control.lua` 会直接使用 `config.token` 作为 Bearer token）。这是运行所需配置，但也意味着它属于敏感信息来源。
- “抖音”应用识别在不同模块里使用了不同 bundleID（`app_launch.lua` vs `apps_shortcuts.lua`），如果相关功能不生效，优先统一 bundleID/应用名判断逻辑。

## 外部依赖（与功能强相关）
- Home Assistant 实例（`ha_config.json` 的 `baseUrl`）
- BetterDisplay（`display_brightness.lua` 里硬编码调用 `/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay`）
- Downie 4（`xdownie.lua` 通过 `open -a "Downie 4"` 调起）
- IINA/系统默认播放器（`open_iina.lua` 通过 `open` 播放文件）

## 其他目录
- `Spoons/SpoonInstall.spoon` 存在，但当前未在 `init.lua` 中加载；若后续要引入更多 spoon，可从这里扩展。