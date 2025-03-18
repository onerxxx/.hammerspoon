-- Home Assistant 控制脚本
-- 配置参数
local config = {}

-- 从配置文件加载配置
local function loadConfig()
    local configPath = hs.fs.pathToAbsolute(hs.configdir .. "/ha_config.json")
    if configPath then
        local file = io.open(configPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local success, jsonConfig = pcall(hs.json.decode, content)
            if success and jsonConfig then
                config = jsonConfig
                return true
            end
        end
    end
    
    -- 使用默认配置
    config = {
        baseUrl = "http://192.168.2.9:8123/",
        entityId = "light.yeelink_colora_6b37_switch_status",
        scrollThrottleTime = 0.1,
        brightnessStep = 50,
        invertScrollDirection = false,  -- 是否反转滚轮方向
      
    }
    return false
end

-- 加载配置
loadConfig()

-- 自定义通知样式 - 缩小字体
local smallerFontStyle = {
    textFont = "misans medium",
    textSize = 15,  -- 缩小字体大小
    textColor = {hex = "#ffffff", alpha = 0.9},  
    fillColor = {hex = "#2f2928", alpha = 0.9},  -- 设置为半透明橙红色背景
    strokeColor = {hex = "#564c49", alpha = 0.8},  -- 边框颜色
    radius = 17, -- 圆角大小
    padding = 18, -- 内间距

    fadeInDuration = 0.1,  -- 快速淡入
    fadeOutDuration = 0.4, -- 平滑淡出
    strokeWidth = 8,  -- 移除边框
}

-- 获取设备状态
local function getDeviceState(callback)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. config.entityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.state then
                callback(state.state)
            else
                hs.alert.show("无法解析设备状态", hs.screen.primaryScreen(), smallerFontStyle)
                callback(nil)
            end
        else
            hs.alert.show("获取设备状态失败，错误码: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
            callback(nil)
        end
    end)
end

-- 切换设备状态
local function toggleDevice(entityId)
    local targetEntityId = entityId or config.entityId
    
    -- 构建请求头
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    -- 构建请求体
    local serviceData = {
        entity_id = targetEntityId
    }
    
    -- 发送按钮按压请求
    local url = config.baseUrl .. "api/services/button/press"
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            -- 成功时显示通知
            hs.alert.closeAll()

            -- 获取设备状态并显示
            getDeviceState(function(state)
                if state then
                    -- 获取设备状态并显示
                    local displayState = state == "on" and "开" or "关"
                    hs.alert.closeAll() -- 关闭所有已存在的alert
                    hs.alert.show("切换顶灯开关", hs.screen.primaryScreen(), smallerFontStyle)
                else
                    -- 如果无法获取状态，显示错误提示
                    hs.alert.show("无法获取设备状态", hs.screen.primaryScreen(), smallerFontStyle)
                end
            end)

        else
            -- 失败时显示错误信息
            hs.alert.show("控制设备失败: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
        end
    end)
end

-- 直接开灯
local function turnOn()
    local serviceData = {
        entity_id = config.entityId
    }
    
    local url = config.baseUrl .. "api/services/light/turn_on"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            hs.alert.closeAll() -- 关闭所有已存在的alert

            hs.alert.show("💡灯光已打开", hs.screen.primaryScreen(), smallerFontStyle)
        else
            hs.alert.show("打开灯失败: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
        end
    end)
end

-- 直接关灯
local function turnOff()
    local serviceData = {
        entity_id = config.entityId
    }
    
    local url = config.baseUrl .. "api/services/light/turn_off"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            hs.alert.closeAll() -- 关闭所有已存在的alert

            hs.alert.show("💡灯光已关闭", hs.screen.primaryScreen(), smallerFontStyle)
        else
            hs.alert.show("关闭灯失败: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
        end
    end)
end

-- 设置快捷键

-- 使用 Control(ctrl) + F 切换灯光
hs.hotkey.bind({"ctrl"}, "F", function()
     toggleDevice("button.yeelink_colora_6b37_toggle")
end)

-- 获取当前亮度
local function getBrightness(callback)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. config.entityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.attributes and state.attributes.brightness then
                callback(state.attributes.brightness)
            else
                hs.alert.show("无法获取亮度信息", hs.screen.primaryScreen(), smallerFontStyle)
                callback(nil)
            end
        else
            hs.alert.show("获取亮度失败，错误码: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
            callback(nil)
        end
    end)
end

-- 设置亮度
local function setBrightness(brightness)
    local serviceData = {
        entity_id = config.entityId,
        brightness = brightness
    }
    
    local url = config.baseUrl .. "api/services/light/turn_on"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
             -- 关闭所有已存在的 alert
            hs.alert.closeAll()
            hs.alert.show(string.format("💡亮度 : %d%%", math.max(1, math.floor(brightness / 255 * 100))), hs.screen.primaryScreen(), 1.2, smallerFontStyle)
        else
            hs.alert.show("设置亮度失败: " .. code, hs.screen.primaryScreen(), smallerFontStyle)
        end
    end)
end



-- 创建一个标志变量，用于跟踪是否已经安装了事件监听器
local isWatcherInstalled = false

-- 创建一个变量来跟踪上次滚动事件的时间戳
local lastScrollTime = 0
-- 从配置中获取滚动事件的最小间隔时间（秒）
local scrollInterval = config.scrollThrottleTime or 0.1
-- 从配置中获取亮度调节步长
local brightnessStep = config.brightnessStep or 50

-- 亮度值为1的连续检测相关变量
local brightnessOneCount = 0
local lastBrightnessOneTime = 0

-- 增强的日志函数
local logger = nil
local function log(message)
    if not logger then
        logger = hs.logger.new('ha_control', 'debug')
        -- 设置日志级别为info，减少不必要的调试信息
        logger.setLogLevel('info')
    end
    
    logger:i(message)
end

-- 获取滚轮值的函数
local function getScrollValue(event)
    -- 参考wheelzoom.lua的实现，直接获取滚轮垂直方向的滚动值
    local scrollY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1)
    
    -- 如果主要方法失败，尝试备用方法
    if not scrollY or scrollY == 0 then
        -- 尝试其他可能的滚轮事件属性
        local properties = {
            ["unitDelta"] = hs.eventtap.event.properties.scrollWheelEventUnitDeltaAxis1,
            ["fixedPtDelta"] = hs.eventtap.event.properties.scrollWheelEventFixedPtDeltaAxis1,
            ["pointDelta"] = hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1
        }
        
        -- 按优先级尝试其他属性
        for name, prop in pairs(properties) do
            if prop then
                local value = event:getProperty(prop)
                if value and value ~= 0 then
                    scrollY = value
                    log("使用备用方法 " .. name .. " 获取滚轮值: " .. tostring(scrollY))
                    break
                end
            end
        end
    else
        log("使用主要方法获取滚轮值: " .. tostring(scrollY))
    end
    
    -- 如果仍然无法获取有效值，记录调试信息
    if not scrollY or scrollY == 0 then
        log("无法获取有效的滚轮值")
        
        -- 记录所有可能的属性值，用于调试
        if config.debugMode then
            local allProps = {}
            for k, v in pairs(hs.eventtap.event.properties) do
                if k:find("scrollWheel") then
                    local value = event:getProperty(v)
                    allProps[k] = value
                end
            end
            
            local debugInfo = "滚轮事件详情: "
            for k, v in pairs(allProps) do
                debugInfo = debugInfo .. k .. "=" .. tostring(v or "nil") .. ", "
            end
            log(debugInfo)
        end
    end
    
    return scrollY
end
-- 创建一个标志变量，用于跟踪ctrl+alt组合键是否被按下
local isCtrlAltDown = false

-- 添加关灯锁定时间变量
local lastTurnOffTime = 0
-- 设置关灯锁定期为2秒
local turnOffLockDuration = 2

-- 创建键盘事件监听器，用于检测ctrl+alt组合键的按下和释放
local keyWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local flags = event:getFlags()
    
    -- 检查是否同时按下了ctrl和alt键（没有其他修饰键）
    local ctrlAltDown = flags.ctrl and flags.alt and not (flags.cmd or flags.shift or flags.fn)
    
    -- 如果状态发生变化，则更新标志变量
    if ctrlAltDown ~= isCtrlAltDown then
        isCtrlAltDown = ctrlAltDown
        if isCtrlAltDown then
            log("启用滚轮控制亮度模式")
        end
    end
    
    return false
end)

-- 创建鼠标滚轮事件监听器
local scrollWatcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
    -- 只有在ctrl+alt被按下时才处理滚轮事件
    if isCtrlAltDown then
        -- 获取当前时间
        local currentTime = hs.timer.secondsSinceEpoch()
        
        -- 检查是否已经过了最小间隔时间
        if (currentTime - lastScrollTime) >= scrollInterval then
            -- 更新上次滚动时间
            lastScrollTime = currentTime
            
            -- 获取滚轮值（使用改进后的函数）
            local scrollY = getScrollValue(event)
            
            -- 根据滚轮方向调整亮度
            if scrollY and scrollY ~= 0 then
                -- 先检查灯光状态
                getDeviceState(function(state)
                    local adjustBrightness = function()
                        local direction = scrollY > 0 and 1 or -1
                        
                        -- 检查是否需要反转方向
                        if config.invertScrollDirection then
                            direction = -direction
                        end
                        
                        if direction < 0 then
                            -- 检查是否在关灯锁定期内
                            local currentTime = hs.timer.secondsSinceEpoch()
                            if currentTime - lastTurnOffTime <= 1 then
                                log("在关灯锁定期内，忽略减少亮度操作")
                                return
                            end
                            
                            log("检测到向下滚动，减少亮度")
                            getBrightness(function(currentBrightness)
                                local newBrightness = currentBrightness and math.max(1, currentBrightness - brightnessStep) or 128
                                log("亮度调整: " .. tostring(currentBrightness) .. " -> " .. tostring(newBrightness))
                                setBrightness(newBrightness)
                                
                                -- 检测亮度值为1的连续次数
                                if newBrightness == 1 then
                                    local currentTime = hs.timer.secondsSinceEpoch()
                                    if currentTime - lastBrightnessOneTime <= 1.5 then
                                        brightnessOneCount = brightnessOneCount + 1
                                        if brightnessOneCount >= 3 then
                                            -- 连续3次检测到亮度值为1，先获取灯光状态
                                            getDeviceState(function(state)
                                                if state == "on" then
                                                    -- 如果灯光还是开启状态，执行渐变关灯
                                                    local function fadeOut()
                                                        local startBrightness = 10
                                                        setBrightness(startBrightness)
                                                        hs.timer.doAfter(0.3, function()
                                                            turnOff()
                                                            brightnessOneCount = 0
                                                            -- 设置关灯锁定时间
                                                            lastTurnOffTime = hs.timer.secondsSinceEpoch()
                                                          
                                                        end)
                                                    end
                                                    fadeOut()
                                                else
                                                    -- 如果灯光已经是关闭状态，直接重置计数器
                                                    brightnessOneCount = 0
                                                end
                                            end)
                                        end
                                    else
                                        -- 超过1.5秒，重置计数器但保留一次计数
                                        brightnessOneCount = 1
                                    end
                                    lastBrightnessOneTime = currentTime
                                else
                                    -- 亮度不为1，重置计数器
                                    brightnessOneCount = 0
                                end
                            end)
                        else
                            log("检测到向上滚动，增加亮度")
                            getBrightness(function(currentBrightness)
                                local newBrightness = currentBrightness and math.min(255, currentBrightness + brightnessStep) or 128
                                log("亮度调整: " .. tostring(currentBrightness) .. " -> " .. tostring(newBrightness))
                                setBrightness(newBrightness)
                            end)
                        end
                    end

                    if state == "on" then
                        -- 如果灯已经开着，直接调整亮度
                        adjustBrightness()
                    else
                        -- 如果灯是关闭状态
                        local direction = scrollY > 0 and 1 or -1
                        if config.invertScrollDirection then
                            direction = -direction
                        end
                        
                        if direction > 0 then
                            -- 检查是否在关灯锁定期内
                            local currentTime = hs.timer.secondsSinceEpoch()
                            if currentTime - lastTurnOffTime > turnOffLockDuration then
                                -- 不在锁定期内，允许开灯
                                turnOn()
                                hs.timer.doAfter(0.5, adjustBrightness)
                            else
                                -- 在锁定期内，忽略开灯请求
                                log("在关灯锁定期内，忽略开灯请求")
                            end
                        else
                            -- 向下滚动时，保持关闭状态
                            log("灯光关闭状态下向下滚动，保持关闭状态")
                        end
                    end
                end)
            end
        end
        
        -- 阻止原始滚轮事件继续传播
        return true
    end
    
    -- 如果没有按下cmd+alt，则不拦截事件
    return false
end)

-- 清理函数
local function cleanup()
    if keyWatcher then
        keyWatcher:stop()
    end
    if scrollWatcher then
        scrollWatcher:stop()
    end
    isWatcherInstalled = false
    log("监听器已停止")
end

-- 启动监听器函数
local function startWatchers()
    cleanup() -- 确保清理旧的监听器
    keyWatcher:start()
    scrollWatcher:start()
    isWatcherInstalled = true
    log("监听器已启动")
    hs.alert.show("灯光控制监听器已启动", hs.screen.primaryScreen(), smallerFontStyle)
end

-- 注册清理函数
hs.shutdownCallback = cleanup

-- 添加手动重启监听器的热键
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "L", function()
    if isWatcherInstalled then
        cleanup()
        hs.alert.show("灯光控制监听器已停止", hs.screen.primaryScreen(), smallerFontStyle)
    else
        startWatchers()
    end
end)

-- 初始启动监听器
startWatchers()


-- 初始化提示
hs.alert.show("使用 Ctrl+F 切换灯光", hs.screen.primaryScreen(), smallerFontStyle)
hs.alert.show("使用 Ctrl+Alt+滚轮 调节亮度", hs.screen.primaryScreen(), smallerFontStyle)
hs.alert.show(string.format("步进亮度 %d/256", config.brightnessStep), hs.screen.primaryScreen(), smallerFontStyle)

-- 绑定 F9 快捷键来控制桌面灯带
hs.hotkey.bind({}, "f9", function()
    -- 使用 AppleScript 触发快捷指令
    local script = [[tell application "Shortcuts" to run shortcut "切换桌面灯带"]]
    local ok, _, _ = hs.osascript.applescript(script)
    if ok then
        hs.alert.closeAll()
        hs.alert.show("🌈切换灯带开关", hs.screen.primaryScreen(), smallerFontStyle)
    else
        hs.alert.show("触发快捷指令失败", hs.screen.primaryScreen(), smallerFontStyle)
    end
end)

-- 绑定 F12 快捷键来控制桌面台灯
hs.hotkey.bind({}, "f12", function()
    -- 使用 AppleScript 触发快捷指令
    local script = [[tell application "Shortcuts" to run shortcut "切换桌面台灯"]]
    local ok, _, _ = hs.osascript.applescript(script)
    if ok then
        hs.alert.closeAll()
        hs.alert.show("📝切换台灯开关", hs.screen.primaryScreen(), smallerFontStyle)
    else
        hs.alert.show("触发快捷指令失败", hs.screen.primaryScreen(), smallerFontStyle)
    end
end)