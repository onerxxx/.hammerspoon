-- 虚拟按键功能模块
-- 当在Moonlight应用中按下cmd键时，模拟键盘按下ctrl键

local virtualKeys = {}

-- 按键状态管理
local keyState = {
    cmdPressed = false,        -- cmd键是否被按下
    ctrlSimulated = false,     -- ctrl键是否已被模拟
    lastEventTime = 0,         -- 上次事件时间
    pressStartTime = 0,        -- 按下开始时间
    isLongPress = false        -- 是否为长按
}

-- 配置参数
local config = {
    debounceTime = 0.05,       -- 防抖动时间（秒）
    longPressThreshold = 0.5,  -- 长按阈值（秒）
    maxAlertFrequency = 1.0    -- 最大提示频率（秒）
}

-- 存储当前活动的应用程序
local currentApp = nil
local lastAlertTime = 0  -- 初始化为0

-- 检查当前应用是否为Moonlight
local function isMoonlightActive()
    local frontApp = hs.application.frontmostApplication()
    if frontApp then
        local appName = frontApp:name()
        local bundleID = frontApp:bundleID()
        local appPath = frontApp:path()
        
        -- 启用调试信息以排查问题
        print("=== Moonlight 检测调试信息 ===")
        print("当前应用: " .. (appName or "未知"))
        print("Bundle ID: " .. (bundleID or "未知"))
        print("应用路径: " .. (appPath or "未知"))
        
        -- 多种识别方式确保准确性
        if appName then
            local lowerAppName = string.lower(appName)
            -- 1. 检查应用名称是否包含moonlight
            if lowerAppName:find("moonlight") then
                print("✅ 通过应用名称识别为 Moonlight")
                return true
            end
        end
        
        -- 2. 检查Bundle ID
        if bundleID and string.lower(bundleID):find("moonlight") then
            print("✅ 通过 Bundle ID 识别为 Moonlight")
            return true
        end
        
        -- 3. 检查应用路径
        if appPath and string.lower(appPath):find("moonlight") then
            print("✅ 通过应用路径识别为 Moonlight")
            return true
        end
        
        -- 4. 特定的Moonlight应用识别
        if bundleID == "com.moonlight-stream.Moonlight" or 
           bundleID == "com.moonlight.Moonlight" or
           bundleID == "com.limelight.Limelight" or  -- 旧版本名称
           (appName and (appName == "Moonlight" or appName == "Limelight")) then
            print("✅ 通过特定标识符识别为 Moonlight")
            return true
        end
        
        print("❌ 未识别为 Moonlight 应用")
    else
        print("❌ 无法获取前台应用信息")
    end
    return false
end

-- 强制重置按键状态
function resetKeyState()
    keyState.cmdPressed = false
    keyState.ctrlSimulated = false
    keyState.lastEventTime = 0
    keyState.pressStartTime = 0
    keyState.isLongPress = false
    
    -- 安全地清空按键状态
    if pressedKeys then
        pressedKeys = {}
    else
        pressedKeys = {}
    end
    
    if pendingKeyEvents then
        pendingKeyEvents = {}
    else
        pendingKeyEvents = {}
    end
    
    print("按键状态已重置")
end

-- 显示带频率限制的提示信息
function showAlert(message, duration)
    local currentTime = hs.timer.secondsSinceEpoch()
    -- 确保lastAlertTime已初始化
    if not lastAlertTime then
        lastAlertTime = 0
    end
    -- 使用正确的配置变量名
    if currentTime - lastAlertTime >= config.maxAlertFrequency then
        hs.alert.show(message, duration or 1.0)
        lastAlertTime = currentTime
    end
end

-- 创建组合键映射表
local keyMappings = {
    -- 基础编辑操作
    ["cmd+c"] = "ctrl+c",      -- 复制
    ["cmd+v"] = "ctrl+v",      -- 粘贴
    ["cmd+x"] = "ctrl+x",      -- 剪切
    ["cmd+z"] = "ctrl+z",      -- 撤销
    ["cmd+y"] = "ctrl+y",      -- 重做
    ["cmd+a"] = "ctrl+a",      -- 全选
    
    -- 文件操作
    ["cmd+s"] = "ctrl+s",      -- 保存
    ["cmd+n"] = "ctrl+n",      -- 新建
    ["cmd+o"] = "ctrl+o",      -- 打开
    ["cmd+w"] = "ctrl+w",      -- 关闭
    ["cmd+q"] = "alt+f4",      -- 退出应用
    
    -- 浏览器/应用操作
    ["cmd+t"] = "ctrl+t",      -- 新标签
    ["cmd+r"] = "ctrl+r",      -- 刷新
    ["cmd+l"] = "ctrl+l",      -- 地址栏
    ["cmd+d"] = "ctrl+d",      -- 书签
    ["cmd+f"] = "ctrl+f",      -- 查找
    ["cmd+g"] = "ctrl+g",      -- 查找下一个
    ["cmd+h"] = "ctrl+h",      -- 替换
    
    -- 标签页操作
    ["cmd+shift+t"] = "ctrl+shift+t",  -- 恢复标签
    ["cmd+shift+w"] = "ctrl+shift+w",  -- 关闭窗口
    ["cmd+shift+n"] = "ctrl+shift+n",  -- 新建隐私窗口
    
    -- 编辑增强
    ["cmd+shift+z"] = "ctrl+shift+z",  -- 重做
    ["cmd+shift+v"] = "ctrl+shift+v",  -- 纯文本粘贴
    
    -- 导航操作
    ["cmd+left"] = "home",     -- 行首
    ["cmd+right"] = "end",     -- 行尾
    ["cmd+up"] = "ctrl+home",  -- 文档开头
    ["cmd+down"] = "ctrl+end", -- 文档结尾
    
    -- 选择操作
    ["cmd+shift+left"] = "shift+home",     -- 选择到行首
    ["cmd+shift+right"] = "shift+end",     -- 选择到行尾
    ["cmd+shift+up"] = "ctrl+shift+home",  -- 选择到文档开头
    ["cmd+shift+down"] = "ctrl+shift+end", -- 选择到文档结尾
    
    -- 游戏常用
    ["cmd+tab"] = "alt+tab",   -- 切换应用
    ["cmd+space"] = "ctrl+space", -- 输入法切换
}

-- 存储当前按下的按键
local pressedKeys = {}
local pendingKeyEvents = {}

-- 创建多事件监听器来捕获所有按键
local keyTap = hs.eventtap.new({
    hs.eventtap.event.types.flagsChanged,
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.keyUp
}, function(event)
    -- 确保变量已初始化
    if not pressedKeys then pressedKeys = {} end
    if not pendingKeyEvents then pendingKeyEvents = {} end
    
    -- 检查是否在Moonlight应用中
    local isMoonlight = isMoonlightActive()
    
    -- 如果不在Moonlight中但有按键状态，重置状态
    if not isMoonlight then
        if keyState.cmdPressed or keyState.ctrlSimulated or next(pressedKeys) then
            resetKeyState()
        end
        return false  -- 不拦截事件，让其正常传递
    end
    
    -- 在Moonlight中，记录事件信息用于调试
    local eventType = event:getType()
    local currentTime = hs.timer.secondsSinceEpoch()
    local keyCode = event:getKeyCode()
    local keyName = hs.keycodes.map[keyCode] or "unknown"
    local flags = event:getFlags()
    
    print(string.format("🎮 Moonlight事件: 类型=%s, 按键=%s(code:%d), 修饰键=%s", 
        eventType == hs.eventtap.event.types.keyDown and "KeyDown" or
        eventType == hs.eventtap.event.types.keyUp and "KeyUp" or
        eventType == hs.eventtap.event.types.flagsChanged and "FlagsChanged" or "Other",
        keyName, keyCode or -1,
        table.concat({
            flags.cmd and "⌘" or "",
            flags.shift and "⇧" or "",
            flags.alt and "⌥" or "",
            flags.ctrl and "⌃" or ""
        }, "")
    ))
    
    -- 防抖动检查
    if currentTime - keyState.lastEventTime < config.debounceTime then
        print("⏱️ 防抖动: 事件被忽略")
        return false
    end
    
    keyState.lastEventTime = currentTime
    
    if eventType == hs.eventtap.event.types.flagsChanged then
        return handleModifierChange(event, currentTime)
    elseif eventType == hs.eventtap.event.types.keyDown then
        return handleKeyDown(event, currentTime)
    elseif eventType == hs.eventtap.event.types.keyUp then
        return handleKeyUp(event, currentTime)
    end
    
    return false
end)

-- 处理修饰键变化
function handleModifierChange(event, currentTime)
    -- 确保变量已初始化
    if not pressedKeys then pressedKeys = {} end
    
    local flags = event:getFlags()
    local cmdCurrentlyPressed = flags.cmd
    
    -- 检测cmd键状态变化
    if cmdCurrentlyPressed and not keyState.cmdPressed then
        -- cmd键被按下
        keyState.cmdPressed = true
        keyState.pressStartTime = currentTime
        keyState.isLongPress = false
        pressedKeys["cmd"] = true
        
        showAlert("⌘ 准备映射", 0.3)
        return false  -- 不拦截，让其他按键能正常检测到cmd状态
        
    elseif not cmdCurrentlyPressed and keyState.cmdPressed then
        -- cmd键被释放
        local pressDuration = currentTime - keyState.pressStartTime
        keyState.cmdPressed = false
        pressedKeys["cmd"] = nil
        
        -- 如果没有其他按键组合，说明是单独按cmd键
        if not next(pressedKeys) then
            if pressDuration >= config.longPressThreshold then
                keyState.isLongPress = true
                showAlert("⌘ 长按释放", 0.3)
            else
                showAlert("⌘ 单击释放", 0.3)
            end
        end
        
        keyState.isLongPress = false
        keyState.pressStartTime = 0
        
        return false  -- 不拦截
    end
    
    return false
end

-- 处理按键按下
function handleKeyDown(event, currentTime)
    -- 确保变量已初始化
    if not pressedKeys then pressedKeys = {} end
    
    local keyCode = event:getKeyCode()
    local keyName = hs.keycodes.map[keyCode]
    
    if not keyName then
        return false
    end
    
    pressedKeys[keyName] = true
    
    -- 检查是否是cmd组合键
    if keyState.cmdPressed then
        local combination = buildKeyCombination()
        local mapping = keyMappings[combination]
        
        if mapping then
            -- 找到映射，拦截原事件并发送映射后的组合键
            showAlert("🔄 " .. combination .. " → " .. mapping, 0.5)
            
            -- 延迟发送映射的组合键，确保cmd键状态正确
            hs.timer.doAfter(0.01, function()
                sendMappedKey(mapping)
            end)
            
            return true  -- 拦截原始事件
        end
    end
    
    return false  -- 不拦截
end

-- 处理按键释放
function handleKeyUp(event, currentTime)
    -- 确保变量已初始化
    if not pressedKeys then pressedKeys = {} end
    
    local keyCode = event:getKeyCode()
    local keyName = hs.keycodes.map[keyCode]
    
    if keyName then
        pressedKeys[keyName] = nil
    end
    
    return false  -- 不拦截
end

-- 构建按键组合字符串
function buildKeyCombination()
    -- 确保变量已初始化
    if not pressedKeys then pressedKeys = {} end
    
    local parts = {}
    
    -- 按固定顺序添加修饰键
    if pressedKeys["cmd"] then table.insert(parts, "cmd") end
    if pressedKeys["shift"] then table.insert(parts, "shift") end
    if pressedKeys["alt"] then table.insert(parts, "alt") end
    if pressedKeys["ctrl"] then table.insert(parts, "ctrl") end
    
    -- 添加普通按键
    for key, _ in pairs(pressedKeys) do
        if key ~= "cmd" and key ~= "shift" and key ~= "alt" and key ~= "ctrl" then
            table.insert(parts, key)
        end
    end
    
    return table.concat(parts, "+")
end

-- 发送映射后的组合键
function sendMappedKey(mapping)
    print("🔄 开始发送映射按键: " .. mapping)
    
    local parts = {}
    for part in mapping:gmatch("[^+]+") do
        table.insert(parts, part)
    end
    
    if #parts < 1 then
        print("❌ 映射格式错误: " .. mapping)
        return false
    end
    
    -- 分离修饰键和普通键
    local modifiers = {}
    local key = parts[#parts]  -- 最后一个是普通键
    
    -- 处理修饰键
    for i = 1, #parts - 1 do
        local mod = parts[i]
        if mod == "ctrl" then
            modifiers.ctrl = true
        elseif mod == "shift" then
            modifiers.shift = true
        elseif mod == "alt" then
            modifiers.alt = true
        elseif mod == "cmd" then
            modifiers.cmd = true
        end
    end
    
    print(string.format("🎯 发送按键: %s + %s", 
        table.concat(parts, "+"), 
        key))
    
    -- 使用更可靠的按键发送方法
    local success = false
    
    -- 方法1: 使用 hs.eventtap.event.newKeyEvent
    success = pcall(function()
        local keyDownEvent = hs.eventtap.event.newKeyEvent(modifiers, key, true)
        local keyUpEvent = hs.eventtap.event.newKeyEvent(modifiers, key, false)
        
        if keyDownEvent and keyUpEvent then
            keyDownEvent:post()
            hs.timer.doAfter(0.02, function()  -- 稍微延长按键持续时间
                keyUpEvent:post()
            end)
            print("✅ 方法1成功: eventtap.event.newKeyEvent")
            return true
        end
        return false
    end)
    
    -- 方法2: 如果方法1失败，尝试使用 hs.eventtap.keyStroke
    if not success then
        success = pcall(function()
            hs.eventtap.keyStroke(modifiers, key, 20000)  -- 20ms延迟
            print("✅ 方法2成功: eventtap.keyStroke")
            return true
        end)
    end
    
    -- 方法3: 如果前两种方法都失败，尝试使用 hs.application:selectMenuItem
    if not success and key == "c" or key == "v" or key == "x" then
        success = pcall(function()
            local frontApp = hs.application.frontmostApplication()
            if frontApp then
                local menuItem = nil
                if key == "c" then menuItem = {"Edit", "Copy"}
                elseif key == "v" then menuItem = {"Edit", "Paste"}
                elseif key == "x" then menuItem = {"Edit", "Cut"}
                end
                
                if menuItem then
                    frontApp:selectMenuItem(menuItem)
                    print("✅ 方法3成功: selectMenuItem")
                    return true
                end
            end
            return false
        end)
    end
    
    if not success then
        print("❌ 所有方法都失败了，无法发送映射按键: " .. mapping)
        showAlert("❌ 按键映射失败: " .. mapping, 2)
        return false
    end
    
    return true
end

-- 启动虚拟按键功能
function virtualKeys.start()
    if keyTap then
        -- 重置状态
        resetKeyState()
        keyTap:start()
        print("虚拟按键功能已启动 - Moonlight中cmd键将映射为ctrl键")
        print("配置: 防抖动=" .. config.debounceTime .. "s, 长按阈值=" .. config.longPressThreshold .. "s")
        return true
    else
        print("错误: 无法启动虚拟按键功能")
        return false
    end
end

-- 停止虚拟按键功能
function virtualKeys.stop()
    if keyTap then
        keyTap:stop()
        -- 确保清理所有状态
        resetKeyState()
        print("虚拟按键功能已停止")
        return true
    else
        print("警告: 虚拟按键功能未初始化")
        return false
    end
end

-- 重启虚拟按键功能
function virtualKeys.restart()
    local stopSuccess = virtualKeys.stop()
    hs.timer.doAfter(0.1, function()  -- 短暂延迟确保完全停止
        local startSuccess = virtualKeys.start()
        if stopSuccess and startSuccess then
            print("虚拟按键功能重启成功")
        else
            print("虚拟按键功能重启失败")
        end
    end)
end

-- 获取当前状态
function virtualKeys.isRunning()
    return keyTap and keyTap:isEnabled()
end

-- 获取详细状态信息
function virtualKeys.getStatus()
    return {
        running = virtualKeys.isRunning(),
        cmdPressed = keyState.cmdPressed,
        ctrlSimulated = keyState.ctrlSimulated,
        isLongPress = keyState.isLongPress,
        lastEventTime = keyState.lastEventTime,
        pressStartTime = keyState.pressStartTime
    }
end

-- 获取组合键映射数量
function getKeyMappingCount()
    if not keyMappings then return 0 end
    local count = 0
    for _ in pairs(keyMappings) do
        count = count + 1
    end
    return count
end

-- 获取当前按下的按键
function getCurrentPressedKeys()
    if not pressedKeys then return "无" end
    local keys = {}
    for key, _ in pairs(pressedKeys) do
        table.insert(keys, key)
    end
    return #keys > 0 and table.concat(keys, "+") or "无"
end

-- 显示组合键映射表
function showKeyMappings()
    if not keyMappings then 
        showAlert("❌ 组合键映射表未初始化", 2)
        return
    end
    
    print("=== 组合键映射表 ===")
    local mappingText = "🎮 支持的组合键映射:\n\n"
    local categories = {
        ["基础编辑"] = {"cmd+c", "cmd+v", "cmd+x", "cmd+z", "cmd+y", "cmd+a"},
        ["文件操作"] = {"cmd+s", "cmd+n", "cmd+o", "cmd+w", "cmd+q"},
        ["浏览器"] = {"cmd+t", "cmd+r", "cmd+l", "cmd+d", "cmd+f", "cmd+g", "cmd+h"},
        ["标签页"] = {"cmd+shift+t", "cmd+shift+w", "cmd+shift+n"},
        ["导航"] = {"cmd+left", "cmd+right", "cmd+up", "cmd+down"},
        ["选择"] = {"cmd+shift+left", "cmd+shift+right", "cmd+shift+up", "cmd+shift+down"},
        ["系统"] = {"cmd+tab", "cmd+space"}
    }
    
    for category, keys in pairs(categories) do
        mappingText = mappingText .. "【" .. category .. "】\n"
        for _, key in ipairs(keys) do
            local mapping = keyMappings[key]
            if mapping then
                mappingText = mappingText .. key .. " → " .. mapping .. "\n"
                print(key .. " → " .. mapping)
            end
        end
        mappingText = mappingText .. "\n"
    end
    
    hs.alert.show(mappingText, 8)
    print("==================")
end

-- 测试Moonlight应用检测
function virtualKeys.testMoonlightDetection()
    print("=== 🔍 Moonlight 应用检测测试 ===")
    local frontApp = hs.application.frontmostApplication()
    
    if not frontApp then
        print("❌ 无法获取前台应用")
        hs.alert.show("❌ 无法获取前台应用", 2)
        return false
    end
    
    local appName = frontApp:name()
    local bundleID = frontApp:bundleID()
    local appPath = frontApp:path()
    
    print("当前前台应用信息:")
    print("  应用名称: " .. (appName or "未知"))
    print("  Bundle ID: " .. (bundleID or "未知"))
    print("  应用路径: " .. (appPath or "未知"))
    
    local isMoonlight = isMoonlightActive()
    print("  是否为Moonlight: " .. (isMoonlight and "✅ 是" or "❌ 否"))
    
    local alertText = string.format(
        "🔍 应用检测结果:\n\n" ..
        "应用名称: %s\n" ..
        "Bundle ID: %s\n" ..
        "是否为Moonlight: %s\n\n" ..
        "如果这是Moonlight应用但未被识别，\n请截图此信息并报告问题。",
        appName or "未知",
        bundleID or "未知",
        isMoonlight and "✅ 是" or "❌ 否"
    )
    
    hs.alert.show(alertText, 5)
    print("=== 测试完成 ===")
    return isMoonlight
end

-- 测试按键映射功能
function virtualKeys.testKeyMapping()
    print("=== 🎮 按键映射功能测试 ===")
    
    if not virtualKeys.isRunning() then
        print("❌ 虚拟按键功能未运行")
        hs.alert.show("❌ 请先启动虚拟按键功能", 2)
        return false
    end
    
    if not isMoonlightActive() then
        print("❌ 当前不在Moonlight应用中")
        hs.alert.show("❌ 请在Moonlight应用中进行测试", 2)
        return false
    end
    
    print("✅ 开始测试按键映射...")
    hs.alert.show("🧪 测试模式\n请按 Cmd+C 测试复制功能", 3)
    
    -- 设置测试模式标志
    keyState.testMode = true
    
    -- 3秒后自动退出测试模式
    hs.timer.doAfter(10, function()
        keyState.testMode = false
        print("🧪 测试模式结束")
        hs.alert.show("🧪 测试模式结束", 1)
    end)
    
    return true
end

-- 诊断系统权限
function virtualKeys.diagnosePemissions()
    print("=== 🔐 系统权限诊断 ===")
    
    local diagnostics = {}
    
    -- 检查辅助功能权限
    local hasAccessibility = hs.accessibilityState()
    table.insert(diagnostics, "辅助功能权限: " .. (hasAccessibility and "✅ 已授权" or "❌ 未授权"))
    
    -- 检查事件监听权限
    local canCreateEventTap = pcall(function()
        local testTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function() end)
        if testTap then
            testTap = nil
            return true
        end
        return false
    end)
    table.insert(diagnostics, "事件监听权限: " .. (canCreateEventTap and "✅ 正常" or "❌ 异常"))
    
    -- 检查按键发送权限
    local canSendKeys = pcall(function()
        -- 尝试创建一个测试事件
        local testEvent = hs.eventtap.event.newKeyEvent({}, "a", true)
        return testEvent ~= nil
    end)
    table.insert(diagnostics, "按键发送权限: " .. (canSendKeys and "✅ 正常" or "❌ 异常"))
    
    -- 输出诊断结果
    for _, diagnostic in ipairs(diagnostics) do
        print(diagnostic)
    end
    
    local alertText = "🔐 权限诊断结果:\n\n" .. table.concat(diagnostics, "\n")
    
    if not hasAccessibility then
        alertText = alertText .. "\n\n⚠️ 需要在系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能中授权Hammerspoon"
    end
    
    hs.alert.show(alertText, 6)
    print("=== 诊断完成 ===")
    
    return hasAccessibility and canCreateEventTap and canSendKeys
end

-- 自动启动
virtualKeys.start()

-- 安全的快捷键绑定函数
local function safeHotkeyBind(mods, key, description, callback)
    local success, hotkey = pcall(function()
        return hs.hotkey.bind(mods, key, callback)
    end)
    
    if success and hotkey then
        print("✅ 快捷键绑定成功: " .. table.concat(mods, "+") .. "+" .. key .. " - " .. description)
        return hotkey
    else
        print("❌ 快捷键绑定失败: " .. table.concat(mods, "+") .. "+" .. key .. " - " .. description)
        print("   可能与系统快捷键冲突，请检查系统偏好设置->键盘->快捷键")
        return nil
    end
end

-- 快捷键配置表
local hotkeyConfigs = {
    {
        mods = {"cmd", "shift"},
        key = "v",
        description = "开启/关闭虚拟按键功能",
        callback = function()
            if virtualKeys.isRunning() then
                virtualKeys.stop()
                hs.alert.show("🎮 虚拟按键功能已关闭", 2)
            else
                virtualKeys.start()
                hs.alert.show("🎮 虚拟按键功能已开启\nMoonlight中cmd键→ctrl键", 2)
            end
        end
    },
    {
        mods = {"cmd", "shift"},
        key = "r",
        description = "紧急重置按键状态",
        callback = function()
            resetKeyState()
            hs.alert.show("🔄 按键状态已重置", 1.5)
        end
    },
    {
        mods = {"cmd", "shift", "ctrl"},
        key = "s",
        description = "查看虚拟按键状态",
        callback = function()
            local status = virtualKeys.getStatus()
            local statusText = string.format(
                "🔍 虚拟按键状态:\n" ..
                "运行状态: %s\n" ..
                "Cmd按下: %s\n" ..
                "Ctrl模拟: %s\n" ..
                "长按状态: %s",
                status.running and "✅ 运行中" or "❌ 已停止",
                status.cmdPressed and "✅ 是" or "❌ 否",
                status.ctrlSimulated and "✅ 是" or "❌ 否",
                status.isLongPress and "✅ 是" or "❌ 否"
            )
            hs.alert.show(statusText, 3)
        end
    },
    {
        mods = {"cmd", "shift"},
        key = "d",
        description = "测试Moonlight应用检测",
        callback = function()
            virtualKeys.testMoonlightDetection()
        end
    },
    {
        mods = {"cmd", "shift"},
        key = "m",
        description = "显示组合键映射表",
        callback = function()
            showKeyMappings()
        end
    },
    {
        mods = {"cmd", "shift", "ctrl"},
        key = "t",
        description = "测试按键映射功能",
        callback = function()
            virtualKeys.testKeyMapping()
        end
    },
    {
        mods = {"cmd", "shift", "ctrl"},
        key = "p",
        description = "诊断系统权限",
        callback = function()
            virtualKeys.diagnosePemissions()
        end
    },
    {
        mods = {"cmd", "shift", "ctrl"},
        key = "h",
        description = "显示帮助信息",
        callback = function()
            virtualKeys.showHelp()
        end
    }
}

-- 存储成功绑定的快捷键
local boundHotkeys = {}

-- 绑定所有快捷键
for _, config in ipairs(hotkeyConfigs) do
    local hotkey = safeHotkeyBind(config.mods, config.key, config.description, config.callback)
    if hotkey then
        table.insert(boundHotkeys, {
            hotkey = hotkey,
            description = config.description,
            keys = table.concat(config.mods, "+") .. "+" .. config.key
        })
    end
end

-- 显示快捷键帮助信息
function virtualKeys.showHelp()
    local helpText = "🎮 虚拟按键快捷键帮助:\n\n"
    for _, bound in ipairs(boundHotkeys) do
        helpText = helpText .. bound.keys .. " - " .. bound.description .. "\n"
    end
    hs.alert.show(helpText, 5)
    print("=== 虚拟按键快捷键帮助 ===")
    for _, bound in ipairs(boundHotkeys) do
        print(bound.keys .. " - " .. bound.description)
    end
    print("========================")
end

-- 清理快捷键绑定
function virtualKeys.cleanup()
    for _, bound in ipairs(boundHotkeys) do
        if bound.hotkey then
            bound.hotkey:delete()
        end
    end
    boundHotkeys = {}
    print("快捷键绑定已清理")
end

return virtualKeys