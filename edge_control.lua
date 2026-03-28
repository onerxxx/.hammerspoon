-- 新建Edge窗口管理模块

local M = {}

function M.openNewEdgeWindow()
    local screen = hs.mouse.getCurrentScreen() or hs.screen.primaryScreen()
    if not screen then
        return false
    end

    local frame = screen:frame()
    local edge = hs.application.get("Microsoft Edge")
    local script = string.format([[
        tell application "Microsoft Edge"
            make new window
            set bounds of front window to {%d, %d, %d, %d}
        end tell
    ]], frame.x, frame.y, frame.x + frame.w, frame.y + frame.h)

    if not edge then
        hs.application.open("Microsoft Edge", 0.1, false)
    end

    hs.timer.doAfter(0.1, function()
        hs.osascript.applescript(script)
    end)

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

    local frame = targetScreen:frame()
    local script = string.format([[
        tell application "Microsoft Edge"
            tell front window
                move active tab to (make new window)
                set bounds of front window to {%d, %d, %d, %d}
            end tell
        end tell
    ]], frame.x, frame.y, frame.x + frame.w, frame.y + frame.h)

    hs.osascript.applescript(script)
    return true
end

hs.hotkey.bind({"cmd", "alt"}, "e", M.openNewEdgeWindow)
hs.hotkey.bind({"cmd", "alt"}, "m", M.moveCurrentTabToOtherScreen)

return M
