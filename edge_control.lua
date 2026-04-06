-- 新建Edge窗口管理模块

local M = {}
local EDGE_APP_NAME = "Microsoft Edge"
local WINDOW_POLL_INTERVAL = 0.1
local WINDOW_POLL_MAX_ATTEMPTS = 20

local function getEdgeApp()
    return hs.application.get(EDGE_APP_NAME)
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

    -- 只找“本次操作后新增”的标准可见窗口，避免误把旧窗口重新拉满。
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

    -- 直接把窗口设为目标屏幕的可用工作区，并把动画时长设为 0。
    -- 这样跨屏移动和铺满窗口会一步完成，不会出现平移动画。
    window:setFrame(screen:frame(), 0)

    return true
end

local function waitForNewWindowAndResize(targetScreen, existingWindowIds)
    local attempts = 0
    local poller = nil
    local didResize = false

    local function stopPolling()
        if poller then
            poller:stop()
            poller = nil
        end
    end

    local function poll()
        attempts = attempts + 1

        local app = getEdgeApp()
        local window = findNewStandardWindow(app, existingWindowIds)
        if window then
            didResize = true
            moveWindowToScreenAndMaximize(window, targetScreen)
            stopPolling()
            return
        end

        -- Edge 新窗口创建有时会慢半拍，这里短轮询一小段时间等窗口真正出现。
        if attempts >= WINDOW_POLL_MAX_ATTEMPTS then
            stopPolling()
        end
    end

    poll()
    if didResize then
        return
    end

    poller = hs.timer.doEvery(WINDOW_POLL_INTERVAL, poll)
end

function M.openNewEdgeWindow()
    local screen = hs.mouse.getCurrentScreen() or hs.screen.primaryScreen()
    if not screen then
        return false
    end

    local edge = getEdgeApp()
    local existingWindowIds = collectStandardWindowIds(edge)

    if not edge then
        hs.application.open(EDGE_APP_NAME, 0.1, false)
        waitForNewWindowAndResize(screen, existingWindowIds)
        return true
    end

    local script = [[
        tell application "Microsoft Edge"
            make new window
        end tell
    ]]

    hs.osascript.applescript(script)
    waitForNewWindowAndResize(screen, existingWindowIds)

    return true
end

function M.moveCurrentTabToOtherScreen()
    local screens = hs.screen.allScreens()
    if #screens < 2 then
        return false
    end

    local currentScreen = hs.mouse.getCurrentScreen() or hs.screen.primaryScreen()
    if not currentScreen then
        return false
    end

    local targetScreen = nil
    for i, screen in ipairs(screens) do
        if screen:id() == currentScreen:id() then
            targetScreen = screens[i % #screens + 1]
            break
        end
    end

    if not targetScreen then
        return false
    end

    local edge = getEdgeApp()
    if not edge then
        return false
    end

    local existingWindowIds = collectStandardWindowIds(edge)
    local script = [[
        tell application "Microsoft Edge"
            tell front window
                move active tab to (make new window)
            end tell
        end tell
    ]]

    hs.osascript.applescript(script)
    waitForNewWindowAndResize(targetScreen, existingWindowIds)
    return true
end

hs.hotkey.bind({"cmd", "alt"}, "e", M.openNewEdgeWindow)
hs.hotkey.bind({"cmd", "alt"}, "m", M.moveCurrentTabToOtherScreen)

return M
