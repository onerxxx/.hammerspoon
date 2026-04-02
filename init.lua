
-- 启用AppleScript支持
hs.allowAppleScript(true)

-- 下载工具模块
require('xdownie')
-- HomeAssistant智能家居控制模块
require("ha_control")
local customAlert = require("custom_alert")
-- Microsoft Edge浏览器控制模块
require("edge_control")
-- IINA播放器快捷操作模块
require("open_iina")
-- 应用程序快捷键设置模块
require("apps_shortcuts")
-- 应用程序启动控制模块
require("app_launch")
-- AppGrid 触发模块
require("appgrid")



-- 绑定快捷键 Cmd+Shift+R 来重新加载 Hammerspoon 配置
hs.hotkey.bind({"cmd", "shift"}, "r", function()
    customAlert.show("配置重载中...")
    hs.timer.doAfter(0.1, hs.reload)
end)
