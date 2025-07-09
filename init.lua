


-- 启用AppleScript支持
hs.allowAppleScript(true)

-- 居中置顶样式配置
local centerTopStyle = {
    textFont = "misans medium",
    textSize = 15,
    textColor = {hex = "#ffffff", alpha = 0.9},
    fillColor = {hex = "#28302f", alpha = 0.9},
    strokeColor = {hex = "#564c49", alpha = 0.8},
    radius = 17,
    padding = 30,
    fadeInDuration = 0.1,
    fadeOutDuration = 0.4,
    strokeWidth = 8,
    atScreenEdge = 1, -- 居中置顶 (0=左上, 1=上中, 2=右上)
}

-- 简化的自定义 alert 函数
local function showCustomAlert(message, topMargin, duration, screen)
    -- 暂时使用原始的 hs.alert.show，但修改样式以显示在顶部
    local customStyle = {
        textFont = centerTopStyle.textFont,
        textSize = centerTopStyle.textSize,
        textColor = centerTopStyle.textColor,
        fillColor = centerTopStyle.fillColor,
        strokeColor = centerTopStyle.strokeColor,
        radius = centerTopStyle.radius,
        padding = centerTopStyle.padding,
        fadeInDuration = centerTopStyle.fadeInDuration,
        fadeOutDuration = centerTopStyle.fadeOutDuration,
        strokeWidth = centerTopStyle.strokeWidth,
        atScreenEdge = 1 -- 居中置顶
    }
    
    duration = duration or 2
    screen = screen or hs.screen.primaryScreen()
    
    -- 使用原始的 hs.alert.show
    hs.alert.show(message, screen, customStyle, duration)
end

-- 关闭所有自定义 alert（简化版本，不需要实际操作）
local function closeAllCustomAlerts()
    -- 由于使用原生 hs.alert.show，不需要手动管理 canvas
end

-- 文件夹同步功能模块
require('folderSync')
-- 下载工具模块
require('xdownie')
-- HomeAssistant智能家居控制模块
require("ha_control")
-- Microsoft Edge浏览器控制模块
require("edge_control")
-- IINA播放器快捷操作模块
require("open_iina")
-- 应用程序快捷键设置模块
require("apps_shortcuts")
-- 应用程序启动控制模块
require("app_launch")


-- 绑定快捷键 Cmd+Shift+R 来重新加载 Hammerspoon 配置
hs.hotkey.bind({"cmd", "shift"}, "r", function()
    hs.reload()
    showCustomAlert("🔄 配置已重新加载", 50, 2)
end)
