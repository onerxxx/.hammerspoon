-- Edge 窗口与触发器控制模块。

local shutdownManager = require("shutdown_manager")

local M = {}

local EDGE_APP_NAME = "Microsoft Edge"

local WINDOW_POLLING = {
    interval = 0.1,
    maxAttempts = 20,
}

local TOP_MIDDLE_TRIGGER = {
    initDelay = 0.15,
    cooldown = 1.0,
    height = 2,
    mouseButton = 2,
    width = 400,
}

local HOTKEYS = {
    newWindow = {
        modifiers = {"cmd", "alt"},
        key = "e",
    },
    moveTabToOtherScreen = {
        modifiers = {"cmd", "alt"},
        key = "m",
    },
}

local DEBUG_MODE = false

local state = {
    lastTopClickTime = 0,
    topMiddleClickTap = nil,
    topMiddleInitTimer = nil,
    windowPollers = {},
}

local function debugPrint(...)
    if DEBUG_MODE then
        print("[DEBUG]", ...)
    end
end

local function getEdgeApp()
    return hs.application.get(EDGE_APP_NAME)
end

local function getCurrentScreen()
    return hs.mouse.getCurrentScreen() or hs.screen.primaryScreen()
end

local function findNextScreen(currentScreen)
    local screens = hs.screen.allScreens()
    if #screens < 2 or not currentScreen then
        return nil
    end

    for index, screen in ipairs(screens) do
        if screen:id() == currentScreen:id() then
            return screens[index % #screens + 1]
        end
    end

    return nil
end

local function collectStandardWindowIds(app)
    local windowIds = {}
    if not app then
        return windowIds
    end

    for _, window in ipairs(app:allWindows() or {}) do
        if window and window:isStandard() then
            local windowId = window:id()
            if windowId then
                windowIds[windowId] = true
            end
        end
    end

    return windowIds
end

local function findNewStandardWindow(app, existingWindowIds)
    if not app then
        return nil
    end

    -- 只找本次操作后新增的标准可见窗口，避免误把旧窗口重新拉满。
    for _, window in ipairs(app:visibleWindows() or {}) do
        if window and window:isStandard() and window:isVisible() then
            local windowId = window:id()
            if windowId and not existingWindowIds[windowId] then
                return window
            end
        end
    end

    return nil
end

local function moveWindowToScreenAndMaximize(window, screen)
    if not window or not screen or not window:isStandard() then
        return false
    end

    -- 直接设为目标屏幕可用工作区，避免先平移再最大化的过渡动画。
    window:setFrame(screen:frame(), 0)
    return true
end

local function trackWindowPoller(poller)
    if poller then
        state.windowPollers[poller] = true
    end

    return poller
end

local function untrackWindowPoller(poller)
    if poller then
        state.windowPollers[poller] = nil
    end
end

local function stopWindowPoller(poller)
    if poller then
        poller:stop()
        untrackWindowPoller(poller)
    end
end

local function stopAllWindowPollers()
    for poller in pairs(state.windowPollers) do
        poller:stop()
    end

    state.windowPollers = {}
end

local function startWindowPolling(targetScreen, existingWindowIds)
    local attempts = 0
    local poller = nil

    local function stop()
        if poller then
            stopWindowPoller(poller)
            poller = nil
        end
    end

    local function poll()
        attempts = attempts + 1

        local app = getEdgeApp()
        local window = findNewStandardWindow(app, existingWindowIds)
        if window then
            moveWindowToScreenAndMaximize(window, targetScreen)
            stop()
            return true
        end

        if attempts >= WINDOW_POLLING.maxAttempts then
            stop()
        end

        return false
    end

    if poll() then
        return nil
    end

    poller = trackWindowPoller(hs.timer.doEvery(WINDOW_POLLING.interval, poll))
    return poller
end

local function runAppleScript(script)
    local ok, result, descriptor = hs.osascript.applescript(script)
    if not ok then
        debugPrint("Edge AppleScript 执行失败", result, descriptor)
    end

    return ok, result, descriptor
end

local function isMouseInTopCenterArea(mousePos)
    local screens = hs.screen.allScreens()

    for _, screen in ipairs(screens) do
        local frame = screen:fullFrame()
        local leftBound = frame.x + (frame.w - TOP_MIDDLE_TRIGGER.width) / 2
        local rightBound = leftBound + TOP_MIDDLE_TRIGGER.width
        local topBound = frame.y
        local bottomBound = frame.y + TOP_MIDDLE_TRIGGER.height

        if mousePos.x >= leftBound and mousePos.x <= rightBound and
           mousePos.y >= topBound and mousePos.y <= bottomBound then
            return true
        end
    end

    return false
end

local function isMiddleMouseDownEvent(event)
    return event:getType() == hs.eventtap.event.types.otherMouseDown and
        event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == TOP_MIDDLE_TRIGGER.mouseButton
end

local function handleTopMiddleClick(event)
    if not isMiddleMouseDownEvent(event) then
        return false
    end

    local currentTime = hs.timer.secondsSinceEpoch()
    if currentTime - state.lastTopClickTime < TOP_MIDDLE_TRIGGER.cooldown then
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
        state.lastTopClickTime = currentTime
        debugPrint("顶部中键监听器: 鼠标在目标区域内，直接调用 Edge 新建窗口")
        M.openNewEdgeWindow()
    else
        debugPrint("顶部中键监听器: 鼠标不在目标区域内")
    end

    return false
end

local function stopTopMiddleInitTimer()
    if state.topMiddleInitTimer then
        state.topMiddleInitTimer:stop()
        state.topMiddleInitTimer = nil
    end
end

local function stopTopMiddleClickTap()
    if state.topMiddleClickTap then
        state.topMiddleClickTap:stop()
        state.topMiddleClickTap = nil
    end
end

local function bindHotkeys()
    hs.hotkey.bind(HOTKEYS.newWindow.modifiers, HOTKEYS.newWindow.key, M.openNewEdgeWindow)
    hs.hotkey.bind(
        HOTKEYS.moveTabToOtherScreen.modifiers,
        HOTKEYS.moveTabToOtherScreen.key,
        M.moveCurrentTabToOtherScreen
    )
end

local function scheduleDeferredInit()
    stopTopMiddleInitTimer()

    state.topMiddleInitTimer = hs.timer.doAfter(TOP_MIDDLE_TRIGGER.initDelay, function()
        state.topMiddleInitTimer = nil
        M.initTopMiddleClickTrigger()
    end)
end

function M.openNewEdgeWindow()
    local screen = getCurrentScreen()
    if not screen then
        return false
    end

    local edge = getEdgeApp()
    local existingWindowIds = collectStandardWindowIds(edge)

    if not edge then
        local launched = hs.application.open(EDGE_APP_NAME, 0.1, false)
        if launched then
            startWindowPolling(screen, existingWindowIds)
        end
        return launched
    end

    local ok = runAppleScript([[
        tell application "Microsoft Edge"
            make new window
        end tell
    ]])

    if ok then
        startWindowPolling(screen, existingWindowIds)
    end

    return ok
end

function M.moveCurrentTabToOtherScreen()
    local currentScreen = getCurrentScreen()
    local targetScreen = findNextScreen(currentScreen)
    if not targetScreen then
        return false
    end

    local edge = getEdgeApp()
    if not edge then
        return false
    end

    local existingWindowIds = collectStandardWindowIds(edge)
    local ok = runAppleScript([[
        tell application "Microsoft Edge"
            tell front window
                move active tab to (make new window)
            end tell
        end tell
    ]])

    if ok then
        startWindowPolling(targetScreen, existingWindowIds)
    end

    return ok
end

function M.initTopMiddleClickTrigger()
    stopTopMiddleInitTimer()
    stopTopMiddleClickTap()

    state.topMiddleClickTap = hs.eventtap.new(
        {hs.eventtap.event.types.otherMouseDown},
        handleTopMiddleClick
    )
    state.topMiddleClickTap:start()

    print("✅ 顶部中键点击监听器已启动")
end

function M.cleanup()
    stopTopMiddleInitTimer()
    stopTopMiddleClickTap()
    stopAllWindowPollers()
    state.lastTopClickTime = 0
end

bindHotkeys()

shutdownManager.register("edge_control", function()
    M.cleanup()
end)

scheduleDeferredInit()

return M
