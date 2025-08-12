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

-- 预览应用监控功能
local previewMonitor = {
    timer = nil,
    lastInactiveTime = nil, -- 改为记录失去焦点的时间
    isMonitoring = false,
    isPreviewActive = false, -- 记录预览应用是否当前处于前置状态
    TIMEOUT_SECONDS = 60, -- 1分钟超时
    -- 可能的预览应用名称和Bundle ID
    POSSIBLE_NAMES = {"预览", "Preview"},
    POSSIBLE_BUNDLE_IDS = {"com.apple.Preview"},
    debugMode = true -- 启用调试模式
}

-- 调试日志函数
local function debugLog(message)
    if previewMonitor.debugMode then
        print("[预览监控] " .. message)
        -- 同时显示通知以便实时查看
        showCustomAlert("🔍 " .. message, 50, 1)
    end
end

-- 列出所有正在运行的应用（用于调试）
local function listAllRunningApps()
    local apps = hs.application.runningApplications()
    local appList = "正在运行的应用:\n"
    
    for i, app in pairs(apps) do
        local appName = app:name() or "未知"
        local bundleID = app:bundleID() or "未知"
        appList = appList .. i .. ". " .. appName .. " (" .. bundleID .. ")\n"
        
        -- 检查是否可能是预览应用
        for _, name in pairs(previewMonitor.POSSIBLE_NAMES) do
            if appName:find(name) or name:find(appName) then
                appList = appList .. "   ⭐ 可能是预览应用!\n"
                break
            end
        end
        
        for _, bundleId in pairs(previewMonitor.POSSIBLE_BUNDLE_IDS) do
            if bundleID == bundleId then
                appList = appList .. "   ⭐ Bundle ID匹配预览应用!\n"
                break
            end
        end
    end
    
    debugLog(appList)
    return apps
end

-- 检查应用是否为预览应用
local function isPreviewApp(app)
    if not app then return false end
    
    local appName = app:name() or ""
    local bundleID = app:bundleID() or ""
    
    -- 检查名称匹配
    for _, name in pairs(previewMonitor.POSSIBLE_NAMES) do
        if appName == name or appName:find(name) or name:find(appName) then
            return true
        end
    end
    
    -- 检查Bundle ID匹配
    for _, bundleId in pairs(previewMonitor.POSSIBLE_BUNDLE_IDS) do
        if bundleID == bundleId then
            return true
        end
    end
    
    return false
end

-- 检查预览应用是否正在运行
local function isPreviewRunning()
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if isPreviewApp(app) then
            local appName = app:name() or "未知"
            local bundleID = app:bundleID() or "未知"
            debugLog("找到预览应用: " .. appName .. " (" .. bundleID .. ")")
            return app
        end
    end
    return nil
end

-- 检查预览应用是否当前处于前置状态
local function isPreviewFrontmost()
    local frontApp = hs.application.frontmostApplication()
    if frontApp then
        local frontAppName = frontApp:name() or "未知"
        local frontBundleID = frontApp:bundleID() or "未知"
        local isPreview = isPreviewApp(frontApp)
        debugLog("当前前置应用: " .. frontAppName .. " (" .. frontBundleID .. ") - 是否为预览: " .. (isPreview and "是" or "否"))
        return isPreview
    end
    debugLog("无法获取前置应用")
    return false
end

-- 强制关闭预览应用
local function forceQuitPreview()
    local previewApp = isPreviewRunning()
    if previewApp then
        debugLog("正在强制关闭预览应用...")
        previewApp:kill()
        showCustomAlert("🔄 预览应用已自动关闭 (1分钟未前置)", 50, 3)
        debugLog("预览应用已成功关闭")
        return true
    else
        debugLog("未找到运行中的预览应用")
        return false
    end
end

-- 开始计时（当预览应用失去焦点时）
local function startInactiveTimer()
    previewMonitor.lastInactiveTime = os.time()
    previewMonitor.isPreviewActive = false
    debugLog("开始计时 - 预览应用失去焦点")
end

-- 停止计时（当预览应用重新获得焦点时）
local function stopInactiveTimer()
    previewMonitor.lastInactiveTime = nil
    previewMonitor.isPreviewActive = true
    debugLog("停止计时 - 预览应用重新获得焦点")
end

-- 检查预览应用是否超时
local function checkPreviewTimeout()
    debugLog("执行超时检查...")
    
    -- 只有当预览应用正在运行时才检查超时
    local previewApp = isPreviewRunning()
    if not previewApp then
        if previewMonitor.lastInactiveTime or previewMonitor.isPreviewActive then
            debugLog("预览应用未运行，清理状态")
            previewMonitor.lastInactiveTime = nil
            previewMonitor.isPreviewActive = false
        end
        return
    end
    
    -- 检查当前前置状态
    local currentlyFrontmost = isPreviewFrontmost()
    
    -- 如果当前是前置的，但之前记录为非前置，则停止计时
    if currentlyFrontmost and not previewMonitor.isPreviewActive then
        debugLog("状态变化：预览应用重新获得前置")
        stopInactiveTimer()
        return
    end
    
    -- 如果当前不是前置的，但之前记录为前置，则开始计时
    if not currentlyFrontmost and previewMonitor.isPreviewActive then
        debugLog("状态变化：预览应用失去前置")
        startInactiveTimer()
        return
    end
    
    -- 如果有失去焦点的时间记录，检查是否超时
    if previewMonitor.lastInactiveTime then
        local currentTime = os.time()
        local timeSinceInactive = currentTime - previewMonitor.lastInactiveTime
        debugLog("已失去焦点 " .. timeSinceInactive .. " 秒 (超时阈值: " .. previewMonitor.TIMEOUT_SECONDS .. " 秒)")
        
        if timeSinceInactive >= previewMonitor.TIMEOUT_SECONDS then
            debugLog("超时！准备关闭预览应用")
            if forceQuitPreview() then
                previewMonitor.lastInactiveTime = nil
                previewMonitor.isPreviewActive = false
            end
        end
    else
        if not currentlyFrontmost then
            debugLog("预览应用未前置但无计时记录，开始计时")
            startInactiveTimer()
        end
    end
end

-- 启动预览应用监控
local function startPreviewMonitoring()
    if previewMonitor.isMonitoring then
        debugLog("监控已在运行中")
        return
    end
    
    previewMonitor.isMonitoring = true
    debugLog("正在启动预览应用监控...")
    
    -- 创建应用监听器，监听应用激活和失活事件
    previewMonitor.appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
        local bundleID = appObject and appObject:bundleID() or "未知"
        
        if isPreviewApp(appObject) then
            debugLog("应用事件: " .. appName .. " - " .. eventType .. " (" .. bundleID .. ")")
            
            if eventType == hs.application.watcher.activated then
                debugLog("预览应用被激活")
                stopInactiveTimer()
            elseif eventType == hs.application.watcher.deactivated then
                debugLog("预览应用被失活")
                startInactiveTimer()
            elseif eventType == hs.application.watcher.launched then
                debugLog("预览应用已启动")
                -- 启动时检查是否立即获得焦点
                hs.timer.doAfter(0.5, function()
                    if isPreviewFrontmost() then
                        previewMonitor.isPreviewActive = true
                        debugLog("预览应用启动后获得焦点")
                    else
                        startInactiveTimer()
                        debugLog("预览应用启动后未获得焦点，开始计时")
                    end
                end)
            elseif eventType == hs.application.watcher.terminated then
                debugLog("预览应用已退出")
                previewMonitor.lastInactiveTime = nil
                previewMonitor.isPreviewActive = false
            end
        end
    end)
    
    previewMonitor.appWatcher:start()
    debugLog("应用监听器已启动")
    
    -- 创建定时器，每10秒检查一次（更频繁的检查以便调试）
    previewMonitor.timer = hs.timer.new(10, checkPreviewTimeout)
    previewMonitor.timer:start()
    debugLog("定时器已启动 (每10秒检查一次)")
    
    -- 如果预览应用已经在运行，检查当前状态
    if isPreviewRunning() then
        if isPreviewFrontmost() then
            previewMonitor.isPreviewActive = true
            debugLog("预览应用已在运行且处于前置状态")
        else
            startInactiveTimer()
            debugLog("预览应用已在运行但不在前置状态，开始计时")
        end
    else
        debugLog("预览应用当前未运行")
    end
    
    debugLog("预览应用监控已完全启动 (超时时间: " .. previewMonitor.TIMEOUT_SECONDS .. "秒)")
end

-- 停止预览应用监控
local function stopPreviewMonitoring()
    if not previewMonitor.isMonitoring then
        debugLog("监控未在运行")
        return
    end
    
    previewMonitor.isMonitoring = false
    
    if previewMonitor.timer then
        previewMonitor.timer:stop()
        previewMonitor.timer = nil
        debugLog("定时器已停止")
    end
    
    if previewMonitor.appWatcher then
        previewMonitor.appWatcher:stop()
        previewMonitor.appWatcher = nil
        debugLog("应用监听器已停止")
    end
    
    previewMonitor.lastInactiveTime = nil
    previewMonitor.isPreviewActive = false
    debugLog("预览应用监控已完全停止")
end

-- 手动检查预览应用状态（用于调试）
local function checkPreviewStatus()
    local status = {}
    status.isRunning = isPreviewRunning() ~= nil
    status.isFrontmost = isPreviewFrontmost()
    status.isMonitoring = previewMonitor.isMonitoring
    status.isPreviewActive = previewMonitor.isPreviewActive
    status.lastInactiveTime = previewMonitor.lastInactiveTime
    
    local message = "预览状态检查:\n"
    message = message .. "运行中: " .. (status.isRunning and "是" or "否") .. "\n"
    message = message .. "前置: " .. (status.isFrontmost and "是" or "否") .. "\n"
    message = message .. "监控中: " .. (status.isMonitoring and "是" or "否") .. "\n"
    message = message .. "记录为活跃: " .. (status.isPreviewActive and "是" or "否") .. "\n"
    
    if status.lastInactiveTime then
        local timeSinceInactive = os.time() - status.lastInactiveTime
        message = message .. "失活时间: " .. timeSinceInactive .. "秒"
    else
        message = message .. "失活时间: 无"
    end
    
    debugLog(message)
    showCustomAlert(message, 50, 5)
    return status
end

-- 手动触发超时检查（用于测试）
local function manualTimeoutCheck()
    debugLog("手动触发超时检查")
    checkPreviewTimeout()
end

-- 切换调试模式
local function toggleDebugMode()
    previewMonitor.debugMode = not previewMonitor.debugMode
    local status = previewMonitor.debugMode and "开启" or "关闭"
    showCustomAlert("调试模式已" .. status, 50, 2)
    print("预览监控调试模式: " .. status)
end

-- 延迟启动预览监控，避免影响重新加载速度
hs.timer.doAfter(1, function()
    startPreviewMonitoring()
end)

-- 在Hammerspoon启动时运行PasteNow
launchPasteNow()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    getDouyinWindowFilter = function() return douyinWindowFilter end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = DOUYIN_APP_INFO,
    -- 预览监控相关函数
    startPreviewMonitoring = startPreviewMonitoring,
    stopPreviewMonitoring = stopPreviewMonitoring,
    isPreviewRunning = isPreviewRunning,
    previewMonitor = previewMonitor,
    -- 调试和测试函数
    checkPreviewStatus = checkPreviewStatus,
    manualTimeoutCheck = manualTimeoutCheck,
    toggleDebugMode = toggleDebugMode,
    listAllRunningApps = listAllRunningApps
}