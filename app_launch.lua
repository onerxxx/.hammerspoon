-- 应用程序启动 
-- 自定义通知样式 - 缩小字体
local smallerFontStyle = {
    textFont = "misans Demibold",
    textSize = 14.4,  -- 缩小字体大小
    textColor = {hex = "#ffffff", alpha = 0.9},  
    fillColor = {hex = "#000000", alpha = 1},  -- 设置为半透明深灰色背景
    strokeColor = {hex = "#eeeeee", alpha = 0.1},  -- 边框颜色
    radius = 13, -- 圆角大小
    padding = 21, -- 内间距
    fadeInDuration = 0.2,  -- 快速淡入
    fadeOutDuration = 0.3, -- 平滑淡出
    strokeWidth = 0,  -- 移除边框
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

-- 初始化自定义alerts数组
local customAlerts = {}

-- 关闭所有自定义 alert
local function closeAllCustomAlerts()
    -- 使用hs.alert.closeAll()来关闭所有alert
    hs.alert.closeAll()
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

-- 获取次屏幕的函数
local function getSecondaryScreen()
    local screens = hs.screen.allScreens()
    local primaryScreen = hs.screen.primaryScreen()
    
    for _, screen in ipairs(screens) do
        if screen:id() ~= primaryScreen:id() then
            return screen
        end
    end
    return nil
end

-- 使用窗口过滤器监听抖音窗口创建（优化版本）
local douyinWindowFilter = nil

-- 抖音应用的识别信息（基于实际Bundle ID）
local DOUYIN_APP_INFO = {
    bundleID = "com.bytedance.douyin.desktop",
    displayName = "抖音",
    -- 可能的应用名称变体
    possibleNames = {"抖音", "Douyin"}
}

-- 延迟创建窗口过滤器，避免影响重新加载速度
local function initDouyinWindowFilter()
    hs.timer.doAfter(0.3, function()
        -- 使用Bundle ID创建更精确的过滤器
        douyinWindowFilter = hs.window.filter.new(false)
        douyinWindowFilter:setAppFilter(DOUYIN_APP_INFO.displayName, true)
        
        douyinWindowFilter:subscribe(hs.window.filter.windowCreated, function(window, appName, event)
    --        showCustomAlert("🎯 检测到抖音启动,移动到次屏幕.", 50, 2)
            
            -- 延迟处理，确保窗口完全加载
            hs.timer.doAfter(0.3, function()
                if window and window:isVisible() and window:isStandard() then
                    local secondaryScreen = getSecondaryScreen()
                    
                    if secondaryScreen then
                        window:moveToScreen(secondaryScreen, true, true)
                        hs.timer.doAfter(0.2, function()
                            window:maximize()
                            showCustomAlert("次屏幕显示抖音", 50, 1, secondaryScreen)
                        end)
                    else
                        window:maximize()
                        showCustomAlert("⚠️ 未检测到次屏幕，在主屏幕最大化", 50, 2)
                    end
                end
            end)
        end)
        print("✅ 抖音窗口过滤器已初始化 (Bundle ID: " .. DOUYIN_APP_INFO.bundleID .. ")")
    end)
end

-- 启动延迟初始化
initDouyinWindowFilter()


-- 在Hammerspoon启动时运行PasteNow
launchPasteNow()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    getDouyinWindowFilter = function() return douyinWindowFilter end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = DOUYIN_APP_INFO,
}