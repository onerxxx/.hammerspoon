-- 应用程序启动 
local edgeControl = require("edge_control")
local shutdownManager = require("shutdown_manager")
local customAlert = require("custom_alert")

local showCustomAlert = customAlert.show
local closeAllCustomAlerts = customAlert.closeAll

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

-- Dropover应用信息
local DROPOVER_INFO = {
    bundleID = "com.dropoverapp.dropover",
    displayName = "Dropover",
    -- 可能的应用名称变体
    possibleNames = {"Dropover"}
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

-- 检查Dropover是否正在运行
local function isDropoverRunning()
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:bundleID() == DROPOVER_INFO.bundleID or app:name() == DROPOVER_INFO.displayName then
            return true
        end
    end
    return false
end

-- 启动Dropover应用
local function launchDropover()
    if not isDropoverRunning() then
        local launched = hs.application.launchOrFocusByBundleID(DROPOVER_INFO.bundleID)
        if not launched then
            hs.application.launchOrFocus(DROPOVER_INFO.displayName)
        end
        showCustomAlert("🚀 启动 Dropover", 50, 2)
        return true
    end
    return false
end

-- 调试标志（仅用于顶部中键监听器）
local DEBUG_MODE = false

local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

-- 顶部中键点击监听器 - 新建浏览器窗口
local topMiddleClickTap = nil
local lastTopClickTime = 0
local TOP_CLICK_COOLDOWN = 1.0

-- 检查鼠标是否在屏幕顶部中央区域
local function isMouseInTopCenterArea(mousePos)
    local screens = hs.screen.allScreens()
    
    for _, screen in ipairs(screens) do
        local frame = screen:fullFrame()  -- 使用fullFrame获取包含菜单栏的完整屏幕区域
        
        -- 计算居中区域的边界（在菜单栏上方）
        local config = {
            height = 2,
            width = 400
        }
        
        local leftBound = frame.x + (frame.w - config.width) / 2
        local rightBound = leftBound + config.width
        local topBound = frame.y  -- 屏幕最顶端
        local bottomBound = frame.y + config.height
        
        -- 检查鼠标是否在该区域内
        if mousePos.x >= leftBound and mousePos.x <= rightBound and 
           mousePos.y >= topBound and mousePos.y <= bottomBound then
            return true
        end
    end
    
    return false
end

-- 初始化顶部中键点击监听器
local function initTopMiddleClickTrigger()
    if topMiddleClickTap then
        topMiddleClickTap:stop()
    end
    
    topMiddleClickTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
        -- 只处理鼠标中键按下事件
        if event:getType() == hs.eventtap.event.types.otherMouseDown and 
           event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 2 then
           
            local currentTime = hs.timer.secondsSinceEpoch()
            
            -- 检查冷却时间
            if currentTime - lastTopClickTime < TOP_CLICK_COOLDOWN then
                debugPrint("顶部中键监听器: 处于冷却期，跳过执行")
                return false
            end
            
            local mousePos = hs.mouse.absolutePosition()
            if not mousePos then 
                debugPrint("顶部中键监听器: 无法获取鼠标位置")
                return false 
            end
            
            debugPrint("顶部中键监听器: 鼠标位置 (" .. mousePos.x .. ", " .. mousePos.y .. ")")
            
            -- 检查鼠标是否在顶部中央区域
            if isMouseInTopCenterArea(mousePos) then
                debugPrint("顶部中键监听器: 鼠标在目标区域内，直接调用 Edge 新建窗口")
                
                -- 更新最后触发时间
                lastTopClickTime = currentTime
                
                edgeControl.openNewEdgeWindow()
                
                
                return false
            else
                debugPrint("顶部中键监听器: 鼠标不在目标区域内")
            end
        end
        
        return false
    end)
    
    topMiddleClickTap:start()
    print("✅ 顶部中键点击监听器已启动")
end

-- 清理函数：关闭所有调试元素
local function cleanupDebugElements()
    if topMiddleClickTap then
        topMiddleClickTap:stop()
        topMiddleClickTap = nil
    end
    if douyinWindowFilter then
        douyinWindowFilter:unsubscribeAll()
        douyinWindowFilter = nil
    end
    debugPrint("🧹 所有调试元素已清理")
end

-- 注册清理回调
shutdownManager.register("app_launch", function()
    cleanupDebugElements()
    closeAllCustomAlerts()
    debugPrint("👋 Hammerspoon 正在关闭，已清理所有资源")
end)

-- 启动顶部中键点击监听
initTopMiddleClickTrigger()

-- 在Hammerspoon启动时运行PasteNow
launchPasteNow()

-- 在Hammerspoon启动时运行Dropover
launchDropover()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    launchDropover = launchDropover,
    isDropoverRunning = isDropoverRunning,
    getDouyinWindowFilter = function() return douyinWindowFilter end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = DOUYIN_APP_INFO,
    DROPOVER_INFO = DROPOVER_INFO
}
