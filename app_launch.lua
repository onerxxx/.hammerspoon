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

-- AppGrid应用信息
local APPGRID_INFO = {
    bundleID = "com.zekalogic.appgrid.app",
    displayName = "AppGrid",
    -- 可能的应用名称变体
    possibleNames = {"AppGrid"}
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

-- 屏幕右下角触发AppGrid功能
local cornerTriggerWatcher = nil
local cornerTriggerPoller = nil
local manualTriggerHotkey = nil
local lastTriggerTime = 0
local TRIGGER_COOLDOWN = 1.0
local wasInCornerLastTick = false

-- 调试标志
local DEBUG_MODE = false

-- 可视化调试相关变量
local debugCanvas = nil
local hoverTimer = nil
local isHovering = false

local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

-- 检查AppGrid是否正在运行
local function isAppGridRunning()
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:bundleID() == APPGRID_INFO.bundleID or app:name() == APPGRID_INFO.displayName then
            return true
        end
    end
    return false
end

-- 启动AppGrid应用
local function launchAppGrid()
    if not isAppGridRunning() then
        local launched = hs.application.launchOrFocusByBundleID(APPGRID_INFO.bundleID)
        if not launched then
            hs.application.launchOrFocus(APPGRID_INFO.displayName)
        end
        showCustomAlert("🚀 启动 AppGrid", 50, 2)
        return true
    end
    return false
end

-- 模拟Option+空格键组合
local function simulateOptionSpace()
    hs.eventtap.keyStroke({'alt'}, 'space')
    if DEBUG_MODE then
        showCustomAlert("⌨️ 触发 Option+空格", 50, 1)
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
        fillColor = { red = 1, green = 0.5, blue = 0, alpha = 0.3 },  -- 半透明橙色
        strokeColor = { red = 1, green = 0.8, blue = 0, alpha = 0.8 }, -- 黄色边框
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
                debugPrint("顶部中键监听器: 鼠标在目标区域内，触发 Cmd+Opt+E")
                
                -- 更新最后触发时间
                lastTopClickTime = currentTime
                
                -- 模拟按下 cmd+opt+E
                hs.eventtap.keyStroke({"cmd", "alt"}, "e")
                
                -- 显示通知提醒
                showCustomAlert("🖱️ 新建浏览器窗口", 50, 1)
                
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
    if topMiddleClickTap then
        topMiddleClickTap:stop()
        topMiddleClickTap = nil
    end
    debugPrint("🧹 所有调试元素已清理")
end

-- 注册清理回调
hs.shutdownCallback = function()
    cleanupDebugElements()
    closeAllCustomAlerts()
    debugPrint("👋 Hammerspoon 正在关闭，已清理所有资源")
end

-- 启动右下角触发监听
initCornerTrigger()

-- 启动顶部中键点击监听
initTopMiddleClickTrigger()

-- 绑定应急热键：Ctrl+Alt+G
manualTriggerHotkey = hs.hotkey.bind({"ctrl", "alt"}, "g", function()
    showCustomAlert("🧪 热键已捕获: Ctrl+Alt+G", 50, 1.2)
    print("🧪 manual hotkey captured: ctrl+alt+g")
    triggerAppGridNow()
end)

-- 导出调试函数供外部调用
local function showTriggerArea(targetScreenName)
    targetScreenName = targetScreenName or "LG HDR WQHD"  -- 默认目标显示器
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
    
    -- 如果找不到目标显示器，在主屏幕显示（调试用途）
    if DEBUG_MODE then
        local primaryScreen = hs.screen.primaryScreen()
        updateDebugCanvas(primaryScreen)
        debugPrint("⚠️ 未找到目标显示器，使用主屏幕进行调试显示")
    else
        debugPrint("❌ 未找到目标显示器:", targetScreenName)
    end
end

local function hideTriggerArea()
    hideDebugCanvas()
    debugPrint("🧹 手动隐藏触发区域")
end

-- 在Hammerspoon启动时运行PasteNow
launchPasteNow()

return {
    launchApp = launchApp,
    launchPasteNow = launchPasteNow,
    launchAppGrid = launchAppGrid,
    isAppGridRunning = isAppGridRunning,
    getDouyinWindowFilter = function() return douyinWindowFilter end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = DOUYIN_APP_INFO,
    APPGRID_INFO = APPGRID_INFO,
    -- 调试函数
    showTriggerArea = showTriggerArea,  -- 可选参数：指定显示器名称，默认为"LG HDR WQHD"
    hideTriggerArea = hideTriggerArea,
    cleanupDebugElements = cleanupDebugElements,
    triggerAppGridNow = triggerAppGridNow
}