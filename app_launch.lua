-- 应用程序启动 
local edgeControl = require("edge_control")
local shutdownManager = require("shutdown_manager")

local customAlert = nil
local initTimers = {}
local TOP_MIDDLE_TRIGGER_DELAY = 0.15
local DOUYIN_WATCHER_DELAY = 0.2
local DOUYIN_WINDOW_POLL_INTERVAL = 0.2
local DOUYIN_WINDOW_POLL_MAX_ATTEMPTS = 15
local initTopMiddleClickTrigger = nil
local DEBUG_MODE = false

local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

local function getCustomAlert()
    if not customAlert then
        customAlert = require("custom_alert")
    end

    return customAlert
end

local function showCustomAlert(...)
    return getCustomAlert().show(...)
end

local function closeAllCustomAlerts()
    return getCustomAlert().closeAll()
end

local function addInitTimer(delay, fn)
    local timer
    timer = hs.timer.doAfter(delay, function()
        for index = #initTimers, 1, -1 do
            if initTimers[index] == timer then
                table.remove(initTimers, index)
                break
            end
        end

        fn()
    end)

    table.insert(initTimers, timer)
    return timer
end

local PASTENOW_INFO = {
    bundleID = "app.pastenow.PasteNow",
    displayName = "PasteNow",
}

-- 启动应用程序，如果已启动则忽略
local function isAppRunning(bundleID, appName)
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:bundleID() == bundleID or app:name() == appName then
            return true
        end
    end

    return false
end

local function launchApp(appInfo, options)
    options = options or {}

    if isAppRunning(appInfo.bundleID, appInfo.displayName) then
        return false
    end

    local launched = false

    if options.background then
        local args = {"-g"}

        if appInfo.bundleID and appInfo.bundleID ~= "" then
            table.insert(args, "-b")
            table.insert(args, appInfo.bundleID)
        else
            table.insert(args, "-a")
            table.insert(args, appInfo.displayName)
        end

        local task = hs.task.new("/usr/bin/open", nil, args)
        launched = task and task:start() or false
    elseif appInfo.bundleID and appInfo.bundleID ~= "" then
        launched = hs.application.launchOrFocusByBundleID(appInfo.bundleID)
        if not launched then
            launched = hs.application.launchOrFocus(appInfo.displayName)
        end
    else
        launched = hs.application.launchOrFocus(appInfo.displayName)
    end

    if launched and options.notify then
        showCustomAlert("🚀 已启动" .. appInfo.displayName)
    end

    return launched
end

-- 启动PasteNow应用
local function launchPasteNow()
    return launchApp(PASTENOW_INFO, {
        background = true,
        notify = false,
    })
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

local douyinAppWatcher = nil
local douyinWindowPoller = nil
local lastHandledDouyinPid = nil

-- 抖音应用的识别信息（基于实际Bundle ID）
local DOUYIN_APP_INFO = {
    bundleID = "com.bytedance.douyin.desktop",
    displayName = "抖音",
    -- 可能的应用名称变体
    possibleNames = {"抖音", "Douyin"}
}

-- Dropover应用信息
local DROPOVER_INFO = {
    bundleID = "me.damir.dropover-mac",
    displayName = "Dropover",
    -- 可能的应用名称变体
    possibleNames = {"Dropover"}
}

local function isDouyinApp(appObject, appName)
    if appObject and appObject:bundleID() == DOUYIN_APP_INFO.bundleID then
        return true
    end

    if appName then
        if appName == DOUYIN_APP_INFO.displayName then
            return true
        end

        for _, possibleName in ipairs(DOUYIN_APP_INFO.possibleNames) do
            if appName == possibleName then
                return true
            end
        end
    end

    return false
end

local function stopDouyinWindowPolling()
    if douyinWindowPoller then
        douyinWindowPoller:stop()
        douyinWindowPoller = nil
    end
end

local function findDouyinWindow(appObject)
    if not appObject then
        return nil
    end

    local visibleWindows = appObject:visibleWindows() or {}
    for _, window in ipairs(visibleWindows) do
        if window and window:isStandard() and window:isVisible() then
            return window
        end
    end

    local mainWindow = appObject:mainWindow()
    if mainWindow and mainWindow:isStandard() and mainWindow:isVisible() then
        return mainWindow
    end

    return nil
end

local function moveDouyinWindow(window)
    if not window or not window:isStandard() or not window:isVisible() then
        return false
    end

    local secondaryScreen = getSecondaryScreen()
    if secondaryScreen then
        window:moveToScreen(secondaryScreen, true, true)
        hs.timer.doAfter(0.2, function()
            if window and window:isStandard() then
                window:maximize()
                showCustomAlert("次屏幕显示抖音")
            end
        end)
    else
        window:maximize()
        showCustomAlert("⚠️ 未检测到次屏幕，在主屏幕最大化")
    end

    return true
end

local function startDouyinWindowPolling(appObject)
    if not appObject then
        return
    end

    stopDouyinWindowPolling()

    local targetPid = appObject:pid()
    local attempts = 0

    local function poll()
        attempts = attempts + 1

        local runningApp = hs.application.get(targetPid) or hs.application.get(DOUYIN_APP_INFO.bundleID)
        if not runningApp then
            stopDouyinWindowPolling()
            return
        end

        local window = findDouyinWindow(runningApp)
        if window and moveDouyinWindow(window) then
            lastHandledDouyinPid = runningApp:pid()
            stopDouyinWindowPolling()
            return
        end

        if attempts >= DOUYIN_WINDOW_POLL_MAX_ATTEMPTS then
            debugPrint("抖音启动后未在轮询窗口中找到可移动的标准窗口")
            stopDouyinWindowPolling()
        end
    end

    poll()
    if douyinWindowPoller then
        return
    end

    douyinWindowPoller = hs.timer.doEvery(DOUYIN_WINDOW_POLL_INTERVAL, poll)
end

local function initDouyinAppWatcher()
    if douyinAppWatcher then
        return
    end

    douyinAppWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
        if eventType == hs.application.watcher.launched and isDouyinApp(appObject, appName) then
            local appPid = appObject and appObject:pid() or nil
            if appPid and appPid == lastHandledDouyinPid then
                return
            end

            startDouyinWindowPolling(appObject)
            return
        end

        if eventType == hs.application.watcher.terminated and isDouyinApp(appObject, appName) then
            local appPid = appObject and appObject:pid() or nil
            if appPid and appPid == lastHandledDouyinPid then
                lastHandledDouyinPid = nil
            end
            stopDouyinWindowPolling()
        end
    end)

    douyinAppWatcher:start()
    print("✅ 抖音应用监听器已启动 (Bundle ID: " .. DOUYIN_APP_INFO.bundleID .. ")")
end

local function scheduleDeferredInit()
    addInitTimer(TOP_MIDDLE_TRIGGER_DELAY, function()
        initTopMiddleClickTrigger()
    end)

    addInitTimer(DOUYIN_WATCHER_DELAY, function()
        initDouyinAppWatcher()
    end)
end

-- 检查Dropover是否正在运行
local function isDropoverRunning()
    return isAppRunning(DROPOVER_INFO.bundleID, DROPOVER_INFO.displayName)
end

-- 启动Dropover应用
local function launchDropover()
    return launchApp(DROPOVER_INFO, {
        background = true,
        notify = false,
    })
end

local topMiddleClickTap = nil
local lastTopClickTime = 0
local TOP_CLICK_COOLDOWN = 1.0

local function isMouseInTopCenterArea(mousePos)
    local screens = hs.screen.allScreens()
    
    for _, screen in ipairs(screens) do
        local frame = screen:fullFrame()
        local config = {
            height = 2,
            width = 400
        }
        
        local leftBound = frame.x + (frame.w - config.width) / 2
        local rightBound = leftBound + config.width
        local topBound = frame.y
        local bottomBound = frame.y + config.height
        
        if mousePos.x >= leftBound and mousePos.x <= rightBound and
           mousePos.y >= topBound and mousePos.y <= bottomBound then
            return true
        end
    end
    
    return false
end

initTopMiddleClickTrigger = function()
    if topMiddleClickTap then
        topMiddleClickTap:stop()
    end
    
    topMiddleClickTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
        if event:getType() == hs.eventtap.event.types.otherMouseDown and
           event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 2 then
           
            local currentTime = hs.timer.secondsSinceEpoch()
            
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
            
            if isMouseInTopCenterArea(mousePos) then
                debugPrint("顶部中键监听器: 鼠标在目标区域内，直接调用 Edge 新建窗口")
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
    for _, timer in ipairs(initTimers) do
        timer:stop()
    end
    initTimers = {}

    if topMiddleClickTap then
        topMiddleClickTap:stop()
        topMiddleClickTap = nil
    end
    stopDouyinWindowPolling()

    if douyinAppWatcher then
        douyinAppWatcher:stop()
        douyinAppWatcher = nil
    end
    debugPrint("🧹 所有调试元素已清理")
end

-- 注册清理回调
shutdownManager.register("app_launch", function()
    cleanupDebugElements()
    closeAllCustomAlerts()
    debugPrint("👋 Hammerspoon 正在关闭，已清理所有资源")
end)

-- 延后初始化事件监听器，避免阻塞配置重载
scheduleDeferredInit()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    launchDropover = launchDropover,
    isDropoverRunning = isDropoverRunning,
    getDouyinAppWatcher = function() return douyinAppWatcher end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = DOUYIN_APP_INFO,
    DROPOVER_INFO = DROPOVER_INFO
}
