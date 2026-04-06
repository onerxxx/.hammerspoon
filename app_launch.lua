-- 应用程序启动与窗口初始化逻辑。
-- 这个模块主要负责：
-- 1. 按需启动常用应用（如 PasteNow、Dropover）
-- 2. 延后初始化若干监听器，避免在 Hammerspoon 配置重载时阻塞主流程
-- 3. 监听抖音桌面版启动，并自动把窗口移动到次屏幕
-- 4. 监听屏幕顶部中间区域的鼠标中键点击，触发 Edge 新窗口
local edgeControl = require("edge_control")
local shutdownManager = require("shutdown_manager")

-- 自定义提示组件采用懒加载，只有第一次真正需要弹提示时才 require，
-- 这样可以减少模块初始化时的依赖压力。
local customAlert = nil

-- 保存所有“延后初始化”用到的 timer，方便后续统一清理。
local initTimers = {}

-- 若干延迟/轮询参数，统一放在顶部便于调节。
-- TOP_MIDDLE_TRIGGER_DELAY:
--   顶部中键监听器的延后初始化时间。
local TOP_MIDDLE_TRIGGER_DELAY = 0.15
-- DOUYIN_WATCHER_DELAY:
--   抖音应用监听器的延后初始化时间。
local DOUYIN_WATCHER_DELAY = 0.2
-- DOUYIN_WINDOW_POLL_INTERVAL:
--   抖音启动后轮询窗口出现的间隔。
local DOUYIN_WINDOW_POLL_INTERVAL = 0.2
-- DOUYIN_WINDOW_POLL_MAX_ATTEMPTS:
--   最多轮询次数，避免无限轮询。
local DOUYIN_WINDOW_POLL_MAX_ATTEMPTS = 15

-- 这里先声明变量，稍后再赋值函数，便于在 scheduleDeferredInit 中引用。
local initTopMiddleClickTrigger = nil

-- 调试开关，打开后会输出额外日志。
local DEBUG_MODE = false

-- 统一的调试输出入口，避免散落的 if DEBUG_MODE 判断。
local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

-- 获取自定义提示模块。
-- 使用懒加载模式：只有真正需要时才 require("custom_alert")。
local function getCustomAlert()
    if not customAlert then
        customAlert = require("custom_alert")
    end

    return customAlert
end

-- 对外统一的提示展示函数，减少调用方对 custom_alert 模块结构的直接依赖。
local function showCustomAlert(...)
    return getCustomAlert().show(...)
end

-- 关闭当前所有自定义提示。
local function closeAllCustomAlerts()
    return getCustomAlert().closeAll()
end

-- 注册一个延迟执行的初始化任务，并把 timer 记录下来。
-- 这样在 Hammerspoon 重载或退出时，可以统一停止未执行/正在存在的 timer。
local function addInitTimer(delay, fn)
    local timer
    timer = hs.timer.doAfter(delay, function()
        -- timer 触发后，主动把自己从 initTimers 中移除，
        -- 避免列表中残留无效引用。
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

-- PasteNow 的应用信息。
-- 这里统一用 bundleID + 展示名描述应用，方便 launchApp 复用。
local PASTENOW_INFO = {
    bundleID = "app.pastenow.PasteNow",
    displayName = "PasteNow",
}

-- 判断某个应用是否已经在运行。
-- 优先用 bundleID 精确匹配；若 bundleID 不可用，则回退到应用名匹配。
local function isAppRunning(bundleID, appName)
    local apps = hs.application.runningApplications()
    for _, app in pairs(apps) do
        if app:bundleID() == bundleID or app:name() == appName then
            return true
        end
    end

    return false
end

-- 通用应用启动函数。
-- appInfo: { bundleID = "...", displayName = "..." }
-- options:
--   background = true  -> 后台启动，不抢焦点
--   notify = true      -> 启动成功后显示提示
--
-- 返回值：
--   true  -> 本次确实发起了启动且调用结果成功
--   false -> 应用已在运行，或启动失败
local function launchApp(appInfo, options)
    options = options or {}

    -- 已在运行时直接跳过，避免重复启动或把现有窗口抢到前台。
    if isAppRunning(appInfo.bundleID, appInfo.displayName) then
        return false
    end

    local launched = false

    if options.background then
        -- 后台启动使用 macOS 的 open 命令配合 -g 参数（不切前台）。
        local args = {"-g"}

        if appInfo.bundleID and appInfo.bundleID ~= "" then
            -- 优先按 bundleID 启动，更稳定。
            table.insert(args, "-b")
            table.insert(args, appInfo.bundleID)
        else
            -- 没有 bundleID 时退回应用名。
            table.insert(args, "-a")
            table.insert(args, appInfo.displayName)
        end

        local task = hs.task.new("/usr/bin/open", nil, args)
        launched = task and task:start() or false
    elseif appInfo.bundleID and appInfo.bundleID ~= "" then
        -- 正常启动时，优先按 bundleID 定位应用，失败再回退到名称。
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

-- 后台启动 PasteNow。
local function launchPasteNow()
    return launchApp(PASTENOW_INFO, {
        background = true,
        notify = false,
    })
end

-- 获取“主屏幕之外的第一块屏幕”作为次屏幕。
-- 当前实现默认只取第一个非主屏幕，适用于常见双屏场景。
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

-- 与抖音窗口自动处理相关的状态变量。
-- douyinAppWatcher:
--   监听抖音应用启动/退出事件。
-- douyinWindowPoller:
--   抖音刚启动时，轮询窗口是否已经创建完成。
-- lastHandledDouyinPid:
--   记录最近一次已处理过的抖音进程，避免重复搬运窗口。
local douyinAppWatcher = nil
local douyinWindowPoller = nil
local lastHandledDouyinPid = nil

-- 抖音应用的识别信息。
-- bundleID 是最可靠标识；possibleNames 用于兼容某些情况下 watcher 只给应用名的场景。
local DOUYIN_APP_INFO = {
    bundleID = "com.bytedance.douyin.desktop",
    displayName = "抖音",
    -- 可能的应用名称变体
    possibleNames = {"抖音", "Douyin"}
}

-- Dropover 应用信息。
local DROPOVER_INFO = {
    bundleID = "me.damir.dropover-mac",
    displayName = "Dropover",
    -- 可能的应用名称变体
    possibleNames = {"Dropover"}
}

-- 判断给定 appObject / appName 是否为抖音。
-- 这里同时兼容 bundleID 和名称匹配，尽量提高识别成功率。
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

-- 停止当前的抖音窗口轮询器，并清空引用。
local function stopDouyinWindowPolling()
    if douyinWindowPoller then
        douyinWindowPoller:stop()
        douyinWindowPoller = nil
    end
end

-- 从抖音应用中寻找一个“可操作的标准窗口”。
-- 优先从 visibleWindows 中找，因为 mainWindow 在某些时机可能还不可用。
local function findDouyinWindow(appObject)
    if not appObject then
        return nil
    end

    -- 先尝试可见窗口列表，找第一个标准且可见的窗口。
    local visibleWindows = appObject:visibleWindows() or {}
    for _, window in ipairs(visibleWindows) do
        if window and window:isStandard() and window:isVisible() then
            return window
        end
    end

    -- 如果 visibleWindows 中没有，再尝试 mainWindow。
    local mainWindow = appObject:mainWindow()
    if mainWindow and mainWindow:isStandard() and mainWindow:isVisible() then
        return mainWindow
    end

    return nil
end

-- 把抖音窗口移动到次屏幕并最大化。
-- 如果不存在次屏幕，则退回到主屏幕最大化，并给出提示。
local function moveDouyinWindow(window)
    if not window or not window:isStandard() or not window:isVisible() then
        return false
    end

    local secondaryScreen = getSecondaryScreen()
    if secondaryScreen then
        -- 第 2、3 个参数为 true，表示尽量保持相对位置比例并进行动画/过渡式移动。
        window:moveToScreen(secondaryScreen, true, true)
        hs.timer.doAfter(0.2, function()
            -- 延迟一点再 maximize，给系统留出窗口真正完成跨屏移动的时间。
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

-- 抖音启动后，窗口不一定立刻创建完成。
-- 因此这里采用短轮询：持续找窗口，找到后再移动。
local function startDouyinWindowPolling(appObject)
    if not appObject then
        return
    end

    -- 开始新一轮轮询前，先确保旧轮询已停止。
    stopDouyinWindowPolling()

    local targetPid = appObject:pid()
    local attempts = 0

    local function poll()
        attempts = attempts + 1

        -- 优先按 pid 找运行中的应用对象；如果对象丢失，再按 bundleID 兜底获取。
        local runningApp = hs.application.get(targetPid) or hs.application.get(DOUYIN_APP_INFO.bundleID)
        if not runningApp then
            stopDouyinWindowPolling()
            return
        end

        local window = findDouyinWindow(runningApp)
        if window and moveDouyinWindow(window) then
            -- 标记该进程已处理，避免 watcher 再次重复操作。
            lastHandledDouyinPid = runningApp:pid()
            stopDouyinWindowPolling()
            return
        end

        if attempts >= DOUYIN_WINDOW_POLL_MAX_ATTEMPTS then
            debugPrint("抖音启动后未在轮询窗口中找到可移动的标准窗口")
            stopDouyinWindowPolling()
        end
    end

    -- 先立即执行一次，减少首次等待时间。
    poll()
    if douyinWindowPoller then
        -- 如果第一次 poll 已经找到窗口并完成处理，poller 会被 stop，不再需要 doEvery。
        return
    end

    douyinWindowPoller = hs.timer.doEvery(DOUYIN_WINDOW_POLL_INTERVAL, poll)
end

-- 初始化抖音应用 watcher。
-- 只初始化一次，避免重复注册多个 watcher。
local function initDouyinAppWatcher()
    if douyinAppWatcher then
        return
    end

    douyinAppWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
        -- 应用启动时：如果是抖音，则开始等待窗口出现并搬运。
        if eventType == hs.application.watcher.launched and isDouyinApp(appObject, appName) then
            local appPid = appObject and appObject:pid() or nil
            -- 如果这个进程已经被处理过，直接跳过。
            if appPid and appPid == lastHandledDouyinPid then
                return
            end

            startDouyinWindowPolling(appObject)
            return
        end

        -- 应用退出时：清理该应用相关状态。
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

-- 把若干初始化工作延后执行。
-- 这样可以避免配置重载的瞬间做太多事，提高 Hammerspoon 启动体验。
local function scheduleDeferredInit()
    addInitTimer(TOP_MIDDLE_TRIGGER_DELAY, function()
        initTopMiddleClickTrigger()
    end)

    addInitTimer(DOUYIN_WATCHER_DELAY, function()
        initDouyinAppWatcher()
    end)
end

-- 检查 Dropover 是否正在运行。
local function isDropoverRunning()
    return isAppRunning(DROPOVER_INFO.bundleID, DROPOVER_INFO.displayName)
end

-- 后台启动 Dropover。
local function launchDropover()
    return launchApp(DROPOVER_INFO, {
        background = true,
        notify = false,
    })
end

-- 顶部中键监听相关状态。
-- topMiddleClickTap:
--   鼠标事件监听器对象。
-- lastTopClickTime:
--   上一次触发时间戳，用于防抖/冷却。
local topMiddleClickTap = nil
local lastTopClickTime = 0

-- 中键触发冷却时间，避免短时间内重复开多个 Edge 窗口。
local TOP_CLICK_COOLDOWN = 1.0

-- 判断鼠标是否位于任意屏幕顶部中间的“热区”内。
-- 当前热区配置：
--   宽度 400 像素，位于屏幕正中
--   高度 2 像素，贴着屏幕最上边缘
local function isMouseInTopCenterArea(mousePos)
    local screens = hs.screen.allScreens()
    
    for _, screen in ipairs(screens) do
        local frame = screen:fullFrame()
        -- 热区配置局部化，后续如果要调宽高，只需要改这里。
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

-- 初始化顶部中间区域的鼠标中键触发器。
-- 触发条件：
-- 1. 鼠标事件是“其他鼠标键按下”
-- 2. 该按钮编号为 2（通常对应中键）
-- 3. 鼠标位于任一屏幕顶部中间热区
-- 4. 不在冷却时间内
--
-- 满足后调用 edgeControl.openNewEdgeWindow()。
initTopMiddleClickTrigger = function()
    if topMiddleClickTap then
        -- 重建前先停掉旧监听器，避免重复监听。
        topMiddleClickTap:stop()
    end
    
    topMiddleClickTap = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
        if event:getType() == hs.eventtap.event.types.otherMouseDown and
           event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 2 then
           
            local currentTime = hs.timer.secondsSinceEpoch()
            
            -- 通过冷却时间防止连续误触。
            if currentTime - lastTopClickTime < TOP_CLICK_COOLDOWN then
                debugPrint("顶部中键监听器: 处于冷却期，跳过执行")
                return false
            end
            
            -- 读取当前鼠标绝对坐标。
            local mousePos = hs.mouse.absolutePosition()
            if not mousePos then
                debugPrint("顶部中键监听器: 无法获取鼠标位置")
                return false
            end
            
            debugPrint("顶部中键监听器: 鼠标位置 (" .. mousePos.x .. ", " .. mousePos.y .. ")")
            
            if isMouseInTopCenterArea(mousePos) then
                debugPrint("顶部中键监听器: 鼠标在目标区域内，直接调用 Edge 新建窗口")
                lastTopClickTime = currentTime
                -- 真正执行功能：打开一个新的 Edge 窗口。
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

-- 清理本模块创建的所有运行时资源。
-- 包括：
-- 1. 尚未执行的延迟初始化 timer
-- 2. 顶部中键监听器
-- 3. 抖音窗口轮询器
-- 4. 抖音应用 watcher
local function cleanupDebugElements()
    -- 停止所有待执行的初始化 timer，防止模块即将销毁时又触发新的初始化。
    for _, timer in ipairs(initTimers) do
        timer:stop()
    end
    initTimers = {}

    -- 停止顶部中键监听器。
    if topMiddleClickTap then
        topMiddleClickTap:stop()
        topMiddleClickTap = nil
    end

    -- 停止抖音窗口轮询器。
    stopDouyinWindowPolling()

    -- 停止抖音应用 watcher。
    if douyinAppWatcher then
        douyinAppWatcher:stop()
        douyinAppWatcher = nil
    end
    debugPrint("🧹 所有调试元素已清理")
end

-- 向统一的 shutdownManager 注册清理回调。
-- 当 Hammerspoon 重载或退出时，这里会负责回收本模块资源。
shutdownManager.register("app_launch", function()
    cleanupDebugElements()
    closeAllCustomAlerts()
    debugPrint("👋 Hammerspoon 正在关闭，已清理所有资源")
end)

-- 模块加载后立刻安排延后初始化，而不是同步初始化所有监听器。
scheduleDeferredInit()

-- 对外暴露的模块接口。
-- 这里既包含操作函数，也导出部分状态/配置，供其他模块复用。
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
