-- 新建Edge窗口管理模块

-- 绑定快捷键 Cmd+Alt+E 来打开新的 Edge 窗口
hs.hotkey.bind({"cmd", "alt"}, "e", function()
    -- 获取鼠标当前所在屏幕的信息
    local screen = hs.mouse.getCurrentScreen()  -- 获取鼠标指针所在的屏幕对象
    local frame = screen:frame()  -- 获取屏幕的尺寸和位置信息（x, y, width, height）
    
    -- 获取 Edge 应用程序对象，如果 Edge 未运行则返回 nil
    local edge = hs.application.get("Microsoft Edge")
    
    -- 创建 AppleScript 命令字符串
    -- string.format 用于将屏幕坐标注入到 AppleScript 字符串中
    local script = string.format([[
        tell application "Microsoft Edge"
           
            make new window            -- 创建新窗口
            -- 设置前置窗口的位置和大小
            -- bounds 参数格式为 {左边距, 上边距, 右边距, 下边距}
            set bounds of front window to {%d, %d, %d, %d}
        end tell
    ]], frame.x, frame.y, frame.x + frame.w, frame.y + frame.h)
    
    if not edge then
        -- Edge 未运行时，先启动它
        -- 参数说明：
        -- "Microsoft Edge" - 应用程序名称
        -- 0.5 - 等待启动的超时时间（秒）
        -- true - 隐藏启动时的动画效果
        hs.application.open("Microsoft Edge", 0.1, false)
    end
    
    -- 延迟 0.1 秒后执行 AppleScript
    -- 这个延迟确保 Edge 已经完全启动和准备就绪
    hs.timer.doAfter(0.1, function()
        -- 执行 AppleScript 命令来创建新窗口并设置位置
        hs.osascript.applescript(script)
    end)
end)

-- 绑定快捷键 Cmd+Alt+M 来将当前 Edge 标签页移动到新窗口并移至其他屏幕
hs.hotkey.bind({"cmd", "alt"}, "m", function()
    -- 获取所有屏幕
    local screens = hs.screen.allScreens()
    if #screens < 2 then
        hs.alert.show("⚠️ 需要至少两个屏幕才能移动窗口")
        return
    end
    
    -- 获取当前屏幕和目标屏幕
    local currentScreen = hs.mouse.getCurrentScreen()
    local targetScreen = nil
    
    -- 找到下一个屏幕（如果当前是最后一个屏幕，则选择第一个屏幕）
    for i, screen in ipairs(screens) do
        if screen:id() == currentScreen:id() then
            targetScreen = screens[i % #screens + 1]
            break
        end
    end
    
    local frame = targetScreen:frame()
    
    -- 创建 AppleScript 命令字符串
    local script = string.format([[
        tell application "Microsoft Edge"
            tell front window
                -- 将当前标签页移动到新窗口
                move active tab to (make new window)
                -- 设置新窗口的位置和大小
                set bounds of front window to {%d, %d, %d, %d}
            end tell
        end tell
    ]], frame.x, frame.y, frame.x + frame.w, frame.y + frame.h)
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
end)