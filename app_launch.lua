-- 应用程序启动 
-- 自定义通知样式 - 缩小字体
local smallerFontStyle = {
    textFont = "misans medium",
    textSize = 15,  -- 
    textColor = {hex = "#ffffff", alpha = 0.9},  
    fillColor = {hex = "#28302f", alpha = 0.9},  -- 设置为半透明蓝绿色背景
    strokeColor = {hex = "#564c49", alpha = 0.8},  -- 边框颜色
    radius = 17, -- 圆角大小
    padding = 18, -- 内间距
    fadeInDuration = 0.1,  -- 快速淡入
    fadeOutDuration = 0.4, -- 平滑淡出
    strokeWidth = 8,  -- 移除边框
    atScreenEdge = 1, -- 居中置顶 (0=左上, 1=上中, 2=右上)
}

-- 简化的自定义 alert 函数
local function showCustomAlert(message, topMargin, duration, screen)
    -- 暂时使用原始的 hs.alert.show，但修改样式以显示在顶部
    local customStyle = {
        textFont = smallerFontStyle.textFont,
        textSize = smallerFontStyle.textSize,
        textColor = smallerFontStyle.textColor,
        fillColor = smallerFontStyle.fillColor,
        strokeColor = smallerFontStyle.strokeColor,
        radius = smallerFontStyle.radius,
        padding = smallerFontStyle.padding,
        fadeInDuration = smallerFontStyle.fadeInDuration,
        fadeOutDuration = smallerFontStyle.fadeOutDuration,
        strokeWidth = smallerFontStyle.strokeWidth,
        atScreenEdge = 1 -- 居中置顶
    }
    
    duration = duration or 2
    screen = screen or hs.screen.primaryScreen()
    
    -- 使用原始的 hs.alert.show
    hs.alert.show(message, screen, customStyle, duration)
end

-- 关闭所有自定义 alert
local function closeAllCustomAlerts()
    for _, canvas in ipairs(customAlerts) do
        if canvas then
            canvas:delete()
        end
    end
    customAlerts = {}
end

-- 启动应用程序，如果已启动则忽略
local function launchApp(appName)
    local appRunning = false
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:name() == appName then
            appRunning = true
            break
        end
    end
    
    if not appRunning then
        hs.application.launchOrFocus(appName)
        showCustomAlert("🚀 已启动" .. appName, 50, 2)
    end
end

-- 启动PasteNow应用
local function launchPasteNow()
    launchApp("PasteNow")
end

-- 监听抖音应用启动并最大化窗口
local function maximizeDouyin(appName, eventType, appObject)
    if eventType == hs.application.watcher.launched and appName == "抖音" then
        -- 使用重试机制确保窗口最大化成功
        local function tryMaximize(retryCount)
            retryCount = retryCount or 0
            local maxRetries = 5
            
            local app = hs.application.get("抖音")
            if app then
                local win = app:mainWindow()
                if win and win:isVisible() then
                    win:maximize()
                    return
                end
            end
            
            -- 如果窗口还没准备好，继续重试
            if retryCount < maxRetries then
                hs.timer.doAfter(0.3, function()
                    tryMaximize(retryCount + 1)
                end)
            else
                showCustomAlert("❌ 抖音窗口最大化失败", 50, 2)
            end
        end
        
        -- 初始延迟后开始尝试
        hs.timer.doAfter(0.8, function()
            tryMaximize()
        end)
    end
end

-- 创建应用程序监听器
local appWatcher = hs.application.watcher.new(maximizeDouyin)
appWatcher:start()

-- 在Hammerspoon启动时运行PasteNow
launchPasteNow()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    appWatcher = appWatcher
}