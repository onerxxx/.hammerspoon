-- 应用程序启动与窗口初始化逻辑。
-- 这个模块主要负责：
-- 1. 按需启动常用应用（如 PasteNow、Dropover）
-- 2. 延后初始化若干监听器，避免在 Hammerspoon 配置重载时阻塞主流程
-- 3. 监听抖音桌面版启动，并自动把窗口移动到次屏幕
local shutdownManager = require("shutdown_manager")

-- 自定义提示组件采用懒加载，只有第一次真正需要弹提示时才 require，
-- 这样可以减少模块初始化时的依赖压力。
local customAlert = nil

-- 保存所有“延后初始化”用到的 timer，方便后续统一清理。
local initTimers = {}

-- 若干延迟/轮询参数，统一放在顶部便于调节。
local DOUYIN_WATCHER_DELAY = 0.2
local DOUYIN_WINDOW_POLL_INTERVAL = 0.2
local DOUYIN_WINDOW_POLL_MAX_ATTEMPTS = 15
local WINDOW_MOVE_SETTLE_DELAY = 0.2

-- 调试开关，打开后会输出额外日志。
local DEBUG_MODE = false

local APPS = {
    pastenow = {
        bundleID = "app.pastenow.PasteNow",
        displayName = "PasteNow",
    },
    douyin = {
        bundleID = "com.bytedance.douyin.desktop",
        displayName = "抖音",
        possibleNames = {"抖音", "Douyin"},
    },
    dropover = {
        bundleID = "me.damir.dropover-mac",
        displayName = "Dropover",
        possibleNames = {"Dropover"},
    },
}

local douyinState = {
    appWatcher = nil,
    windowPoller = nil,
    lastHandledPid = nil,
}

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

local function hasValue(value)
    return value ~= nil and value ~= ""
end

local function removeInitTimer(timerToRemove)
    for index = #initTimers, 1, -1 do
        if initTimers[index] == timerToRemove then
            table.remove(initTimers, index)
            return
        end
    end
end

-- 注册一个延迟执行的初始化任务，并把 timer 记录下来。
-- 这样在 Hammerspoon 重载或退出时，可以统一停止未执行/正在存在的 timer。
local function addInitTimer(delay, fn)
    local timer
    timer = hs.timer.doAfter(delay, function()
        removeInitTimer(timer)
        fn()
    end)

    table.insert(initTimers, timer)
    return timer
end

local function stopAllInitTimers()
    for _, timer in ipairs(initTimers) do
        timer:stop()
    end

    initTimers = {}
end

local function matchesAppInfo(appInfo, appObject, appName)
    if appObject and hasValue(appInfo.bundleID) and appObject:bundleID() == appInfo.bundleID then
        return true
    end

    if not appName then
        return false
    end

    if appName == appInfo.displayName then
        return true
    end

    for _, possibleName in ipairs(appInfo.possibleNames or {}) do
        if appName == possibleName then
            return true
        end
    end

    return false
end

local function resolveRunningApp(appInfo, pid)
    if pid then
        local appByPid = hs.application.get(pid)
        if appByPid then
            return appByPid
        end
    end

    if hasValue(appInfo.bundleID) then
        local appByBundleID = hs.application.get(appInfo.bundleID)
        if appByBundleID then
            return appByBundleID
        end
    end

    if hasValue(appInfo.displayName) then
        return hs.application.find(appInfo.displayName)
    end

    return nil
end

-- 判断某个应用是否已经在运行。
-- 优先用 bundleID 精确匹配；若 bundleID 不可用，则回退到应用名匹配。
local function isAppRunning(appInfo)
    return resolveRunningApp(appInfo) ~= nil
end

local function buildBackgroundLaunchArgs(appInfo)
    local args = {"-g"}

    if hasValue(appInfo.bundleID) then
        table.insert(args, "-b")
        table.insert(args, appInfo.bundleID)
        return args
    end

    table.insert(args, "-a")
    table.insert(args, appInfo.displayName)
    return args
end

local function launchAppInBackground(appInfo)
    local task = hs.task.new("/usr/bin/open", nil, buildBackgroundLaunchArgs(appInfo))
    return task and task:start() or false
end

local function launchAppInForeground(appInfo)
    if hasValue(appInfo.bundleID) then
        local launched = hs.application.launchOrFocusByBundleID(appInfo.bundleID)
        if launched then
            return true
        end
    end

    return hs.application.launchOrFocus(appInfo.displayName)
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
    if isAppRunning(appInfo) then
        return false
    end

    local launched = options.background
        and launchAppInBackground(appInfo)
        or launchAppInForeground(appInfo)

    if launched and options.notify then
        showCustomAlert("🚀 已启动" .. appInfo.displayName)
    end

    return launched
end

-- 后台启动 PasteNow。
local function launchPasteNow()
    return launchApp(APPS.pastenow, {
        background = true,
        notify = false,
    })
end

-- 获取“主屏幕之外的第一块屏幕”作为次屏幕。
-- 当前实现默认只取第一个非主屏幕，适用于常见双屏场景。
local function getSecondaryScreen()
    local primaryScreen = hs.screen.primaryScreen()

    for _, screen in ipairs(hs.screen.allScreens()) do
        if screen:id() ~= primaryScreen:id() then
            return screen
        end
    end

    return nil
end

local function isOperableWindow(window)
    return window and window:isStandard() and window:isVisible()
end

-- 停止当前的抖音窗口轮询器，并清空引用。
local function stopDouyinWindowPolling()
    if douyinState.windowPoller then
        douyinState.windowPoller:stop()
        douyinState.windowPoller = nil
    end
end

-- 从抖音应用中寻找一个“可操作的标准窗口”。
-- 优先从 visibleWindows 中找，因为 mainWindow 在某些时机可能还不可用。
local function findDouyinWindow(appObject)
    if not appObject then
        return nil
    end

    for _, window in ipairs(appObject:visibleWindows() or {}) do
        if isOperableWindow(window) then
            return window
        end
    end

    local mainWindow = appObject:mainWindow()
    if isOperableWindow(mainWindow) then
        return mainWindow
    end

    return nil
end

local function maximizeWindowWithAlert(window, message)
    hs.timer.doAfter(WINDOW_MOVE_SETTLE_DELAY, function()
        if window and window:isStandard() then
            window:maximize()
            showCustomAlert(message)
        end
    end)
end

-- 把抖音窗口移动到次屏幕并最大化。
-- 如果不存在次屏幕，则退回到主屏幕最大化，并给出提示。
local function moveDouyinWindow(window)
    if not isOperableWindow(window) then
        return false
    end

    local secondaryScreen = getSecondaryScreen()
    if secondaryScreen then
        window:moveToScreen(secondaryScreen, true, true)
        maximizeWindowWithAlert(window, "次屏幕显示抖音")
        return true
    end

    window:maximize()
    showCustomAlert("⚠️ 未检测到次屏幕，在主屏幕最大化")
    return true
end

local function markDouyinHandled(appObject)
    douyinState.lastHandledPid = appObject and appObject:pid() or nil
end

-- 抖音启动后，窗口不一定立刻创建完成。
-- 因此这里采用短轮询：持续找窗口，找到后再移动。
local function startDouyinWindowPolling(appObject)
    if not appObject then
        return
    end

    stopDouyinWindowPolling()

    local targetPid = appObject:pid()
    local attempts = 0

    local function poll()
        attempts = attempts + 1

        local runningApp = resolveRunningApp(APPS.douyin, targetPid)
        if not runningApp then
            stopDouyinWindowPolling()
            return true
        end

        local window = findDouyinWindow(runningApp)
        if window and moveDouyinWindow(window) then
            markDouyinHandled(runningApp)
            stopDouyinWindowPolling()
            return true
        end

        if attempts >= DOUYIN_WINDOW_POLL_MAX_ATTEMPTS then
            debugPrint("抖音启动后未在轮询窗口中找到可移动的标准窗口")
            stopDouyinWindowPolling()
            return true
        end

        return false
    end

    -- 先立即执行一次，减少首次等待时间。
    if poll() then
        return
    end

    douyinState.windowPoller = hs.timer.doEvery(DOUYIN_WINDOW_POLL_INTERVAL, poll)
end

local function handleDouyinWatcherEvent(appName, eventType, appObject)
    if not matchesAppInfo(APPS.douyin, appObject, appName) then
        return
    end

    local appPid = appObject and appObject:pid() or nil

    if eventType == hs.application.watcher.launched then
        if appPid and appPid == douyinState.lastHandledPid then
            return
        end

        startDouyinWindowPolling(appObject)
        return
    end

    if eventType == hs.application.watcher.terminated then
        if appPid and appPid == douyinState.lastHandledPid then
            douyinState.lastHandledPid = nil
        end

        stopDouyinWindowPolling()
    end
end

-- 初始化抖音应用 watcher。
-- 只初始化一次，避免重复注册多个 watcher。
local function initDouyinAppWatcher()
    if douyinState.appWatcher then
        return
    end

    douyinState.appWatcher = hs.application.watcher.new(handleDouyinWatcherEvent)
    douyinState.appWatcher:start()
    print("✅ 抖音应用监听器已启动 (Bundle ID: " .. APPS.douyin.bundleID .. ")")
end

-- 把若干初始化工作延后执行。
-- 这样可以避免配置重载的瞬间做太多事，提高 Hammerspoon 启动体验。
local function scheduleDeferredInit()
    addInitTimer(DOUYIN_WATCHER_DELAY, initDouyinAppWatcher)
end

-- 检查 Dropover 是否正在运行。
local function isDropoverRunning()
    return isAppRunning(APPS.dropover)
end

-- 后台启动 Dropover。
local function launchDropover()
    return launchApp(APPS.dropover, {
        background = true,
        notify = false,
    })
end

-- 清理本模块创建的所有运行时资源。
-- 包括：
-- 1. 尚未执行的延迟初始化 timer
-- 2. 抖音窗口轮询器
-- 3. 抖音应用 watcher
local function cleanupRuntimeResources()
    stopAllInitTimers()
    stopDouyinWindowPolling()

    if douyinState.appWatcher then
        douyinState.appWatcher:stop()
        douyinState.appWatcher = nil
    end

    debugPrint("🧹 所有调试元素已清理")
end

-- 向统一的 shutdownManager 注册清理回调。
-- 当 Hammerspoon 重载或退出时，这里会负责回收本模块资源。
shutdownManager.register("app_launch", function()
    cleanupRuntimeResources()
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
    getDouyinAppWatcher = function() return douyinState.appWatcher end,
    getSecondaryScreen = getSecondaryScreen,
    DOUYIN_APP_INFO = APPS.douyin,
    DROPOVER_INFO = APPS.dropover,
}
