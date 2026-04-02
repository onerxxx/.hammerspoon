-- AppGrid 触发模块
-- 从 app_launch.lua 分离出来的 AppGrid 相关功能
local shutdownManager = require("shutdown_manager")
local customAlert = require("custom_alert")

-- AppGrid应用信息
local APPGRID_INFO = {
    bundleID = "com.zekalogic.appgrid.app",
    displayName = "AppGrid",
    possibleNames = {"AppGrid"}
}

-- 调试标志
local DEBUG_MODE = false

-- 可视化调试相关变量
local debugCanvas = nil
local hoverTimer = nil
local isHovering = false

-- 触发器相关变量
local cornerTriggerWatcher = nil
local cornerTriggerPoller = nil
local manualTriggerHotkey = nil
local lastTriggerTime = 0
local TRIGGER_COOLDOWN = 1.0
local wasInCornerLastTick = false

local showCustomAlert = customAlert.show
local closeAllCustomAlerts = customAlert.closeAll

-- 调试打印函数
local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

-- 通用函数：检查应用是否正在运行
local function isAppRunning(bundleID, appName)
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:bundleID() == bundleID or app:name() == appName then
            return true
        end
    end
    return false
end

-- 检查AppGrid是否正在运行
local function isAppGridRunning()
    return isAppRunning(APPGRID_INFO.bundleID, APPGRID_INFO.displayName)
end

-- 启动AppGrid应用
local function launchAppGrid()
    if not isAppGridRunning() then
        local launched = hs.application.launchOrFocusByBundleID(APPGRID_INFO.bundleID)
        if not launched then
            hs.application.launchOrFocus(APPGRID_INFO.displayName)
        end
        showCustomAlert("🚀 启动 AppGrid")
        return true
    end
    return false
end

-- 模拟Option+空格键组合
local function simulateOptionSpace()
    hs.eventtap.keyStroke({'alt'}, 'space')
    if DEBUG_MODE then
        showCustomAlert("⌨️ 触发 Option+空格")
    end
end

-- 手动触发 AppGrid（应急热键）
local function triggerAppGridNow()
    local appGridLaunched = launchAppGrid()
    if not appGridLaunched then
        hs.timer.doAfter(0.02, function()
            simulateOptionSpace()
        end)
    else
        hs.timer.doAfter(0.2, function()
            simulateOptionSpace()
        end)
    end
end

-- 创建可视化调试画布
local function createDebugCanvas(screen, cornerRect)
    -- 先清除现有的画布
    if debugCanvas then
        debugCanvas:delete()
        debugCanvas = nil
    end
    
    -- 创建新的画布
    debugCanvas = hs.canvas.new(cornerRect)
    debugCanvas[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = { red = 1, green = 0.5, blue = 0, alpha = 0.3 },
        strokeColor = { red = 1, green = 0.8, blue = 0, alpha = 0.8 },
        strokeWidth = 2
    }
    
    -- 添加文字标签
    debugCanvas[2] = {
        type = "text",
        text = "触发区域",
        textSize = 12,
        textColor = { red = 1, green = 1, blue = 1, alpha = 0.9 },
        frame = { x = "5%", y = "30%", w = "90%", h = "40%" }
    }
    
    debugCanvas:show()
    debugPrint("🎯 可视化调试画布已创建并显示")
end

-- 更新可视化画布位置
local function updateDebugCanvas(screen)
    local screenFrame = screen:frame()
    local cornerSize = 24
    local cornerRect = {
        x = screenFrame.x + screenFrame.w - cornerSize,
        y = screenFrame.y + screenFrame.h - cornerSize,
        w = cornerSize,
        h = cornerSize
    }
    if debugCanvas then
        debugCanvas:frame(cornerRect)
    else
        createDebugCanvas(screen, cornerRect)
    end
end

-- 隐藏调试画布
local function hideDebugCanvas()
    if debugCanvas then
        debugCanvas:hide()
        debugCanvas:delete()
        debugCanvas = nil
        debugPrint("🧹 调试画布已隐藏并删除")
    end
    isHovering = false
end

-- 检查鼠标是否在屏幕右下角区域（多显示器兼容版本）
local function isMouseInBottomRightCorner(screen)
    local mousePos = hs.mouse.absolutePosition()
    local primary = hs.screen.primaryScreen()
    if not primary then
        return false
    end
    local screenFrame = primary:frame()
    local fullFrame = primary:fullFrame()
    local cornerSize = 2
    local cornerRect = {
        x = screenFrame.x + screenFrame.w - cornerSize,
        y = screenFrame.y + screenFrame.h - cornerSize,
        w = cornerSize,
        h = cornerSize
    }
    local fullCornerRect = {
        x = fullFrame.x + fullFrame.w - cornerSize,
        y = fullFrame.y + fullFrame.h - cornerSize,
        w = cornerSize,
        h = cornerSize
    }
    local inFrameCorner = mousePos.x >= cornerRect.x and mousePos.x <= cornerRect.x + cornerRect.w and
                          mousePos.y >= cornerRect.y and mousePos.y <= cornerRect.y + cornerRect.h
    local inFullCorner = mousePos.x >= fullCornerRect.x and mousePos.x <= fullCornerRect.x + fullCornerRect.w and
                         mousePos.y >= fullCornerRect.y and mousePos.y <= fullCornerRect.y + fullCornerRect.h
    local inCorner = inFrameCorner or inFullCorner
    if DEBUG_MODE and inCorner and not isHovering then
        isHovering = true
        updateDebugCanvas(screen)
    elseif DEBUG_MODE and not inCorner and isHovering then
        hideDebugCanvas()
    end
    return inCorner
end

-- 右下角触发处理函数（主屏幕专用）
local function handleCornerTrigger(screen)
    local currentTime = hs.timer.secondsSinceEpoch()
    local primaryScreen = hs.screen.primaryScreen()
    if not primaryScreen or screen:id() ~= primaryScreen:id() then
        wasInCornerLastTick = false
        return
    end
    local inCorner = isMouseInBottomRightCorner(screen)
    local justEnteredCorner = inCorner and (not wasInCornerLastTick)
    wasInCornerLastTick = inCorner

    if justEnteredCorner then
        if currentTime - lastTriggerTime < TRIGGER_COOLDOWN then
            return
        end
        print("🎯 AppGrid hot corner hit")
        lastTriggerTime = currentTime
        
        -- 先尝试启动AppGrid
        local appGridLaunched = launchAppGrid()
        
        -- 命中后触发延迟：已运行20ms，刚启动200ms
        if not appGridLaunched then
            hs.timer.doAfter(0.02, function()
                simulateOptionSpace()
            end)
        else
            hs.timer.doAfter(0.2, function()
                simulateOptionSpace()
            end)
        end
    end
end

-- 初始化右下角触发监听器（主屏幕版本）
local function initCornerTrigger()
    debugPrint("开始初始化右下角触发器（主屏幕版本）...")
    hs.timer.doAfter(0.2, function()
        debugPrint("🔄 延迟初始化开始执行")
        print("✅ AppGrid hot corner poller started")
        -- 只用轮询实现触发角，避免 eventtap 权限/事件漏掉造成不触发
        cornerTriggerPoller = hs.timer.doEvery(0.05, function()
            local primary = hs.screen.primaryScreen()
            if primary then
                handleCornerTrigger(primary)
            end
        end)
        debugPrint("✅ 主屏幕右下角触发器已初始化并启动")
    end)
end

-- 清理函数：关闭所有调试元素
local function cleanupDebugElements()
    hideDebugCanvas()
    if hoverTimer then
        hoverTimer:stop()
        hoverTimer = nil
    end
    if cornerTriggerPoller then
        cornerTriggerPoller:stop()
        cornerTriggerPoller = nil
    end
    if cornerTriggerWatcher then
        cornerTriggerWatcher:stop()
        cornerTriggerWatcher = nil
    end
    debugPrint("🧹 AppGrid 所有调试元素已清理")
end

-- 显示触发区域（调试用）
local function showTriggerArea(targetScreenName)
    targetScreenName = targetScreenName or "LG HDR WQHD"
    local allScreens = hs.screen.allScreens()
    
    debugPrint("🔍 搜索显示器:", targetScreenName)
    debugPrint("📊 检测到", #allScreens, "个显示器:")
    
    for i, screen in ipairs(allScreens) do
        local screenName = screen:name()
        local isPrimary = screen:id() == hs.screen.primaryScreen():id()
        debugPrint(string.format("  %d. %s %s", i, screenName, isPrimary and "(主屏幕)" or ""))
        
        if screenName == targetScreenName then
            updateDebugCanvas(screen)
            debugPrint("🎯 在目标显示器显示触发区域:", screenName)
            return
        end
    end
    
    if DEBUG_MODE then
        local primaryScreen = hs.screen.primaryScreen()
        updateDebugCanvas(primaryScreen)
        debugPrint("⚠️ 未找到目标显示器，使用主屏幕进行调试显示")
    else
        debugPrint("❌ 未找到目标显示器:", targetScreenName)
    end
end

-- 隐藏触发区域（调试用）
local function hideTriggerArea()
    hideDebugCanvas()
    debugPrint("🧹 手动隐藏触发区域")
end

-- 启用调试模式
local function setDebugMode(enabled)
    DEBUG_MODE = enabled
end

-- 初始化 AppGrid 触发器
local function init()
    initCornerTrigger()
end

-- 启动并运行 AppGrid 模块
init()

-- 注册清理回调
shutdownManager.register("appgrid", function()
    cleanupDebugElements()
    closeAllCustomAlerts()
    debugPrint("👋 AppGrid 模块正在关闭，已清理所有资源")
end)

-- 导出模块接口
return {
    APPGRID_INFO = APPGRID_INFO,
    isAppGridRunning = isAppGridRunning,
    launchAppGrid = launchAppGrid,
    triggerAppGridNow = triggerAppGridNow,
    init = init,
    cleanupDebugElements = cleanupDebugElements,
    setDebugMode = setDebugMode,
    -- 调试函数
    showTriggerArea = showTriggerArea,
    hideTriggerArea = hideTriggerArea,
}
