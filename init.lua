


require('folderSync')
require('xdownie')
require("ha_control")
require("edge_control")
require("open_iina")
require("apps_shortcuts")
-- 引入应用程序启动控制
require("app_launch")

-- 绑定快捷键 Cmd+Shift+R 来重新加载 Hammerspoon 配置
hs.hotkey.bind({"cmd", "shift"}, "r", function()
    hs.reload()
    hs.alert.show("配置已重新加载")
end)
