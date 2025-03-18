-- 绑定 F18 键来执行"灯光全开"
hs.hotkey.bind({}, "F18", function()
    -- 创建 AppleScript 命令字符串来执行快捷指令
    local script = [[tell application "Shortcuts"
        run shortcut "灯光全开"
    end tell]]
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
end)

-- 绑定快捷键 F17 键来执行"关灯"
hs.hotkey.bind({}, "F17", function()
    -- 创建 AppleScript 命令字符串来执行快捷指令
    local script = [[tell application "Shortcuts"
        run shortcut "关灯"
    end tell]]
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
end)