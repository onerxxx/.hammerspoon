-- Home Assistant 控制脚本

-- =====================================================
-- 所有快捷键设置都在文件底部的「快捷键设置区域」，方便修改
-- =====================================================

-- 引入显示亮度调节模块
local displayBrightness = require("display_brightness")

-- 配置参数
local config = {}
local configLoaded = false

-- 从配置文件加载配置（带缓存）
local function loadConfig()
    if configLoaded then
        return true
    end
    
    local configPath = hs.fs.pathToAbsolute(hs.configdir .. "/ha_config.json")
    if configPath then
        local file = io.open(configPath, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local success, jsonConfig = pcall(hs.json.decode, content)
            if success and jsonConfig then
                config = jsonConfig
                configLoaded = true
                
                -- 检查必要参数
                if not config.token then
                    print("[ha_control] 警告: 配置文件缺少 token 参数")
                    return false
                end
                if not config.baseUrl then
                    print("[ha_control] 警告: 配置文件缺少 baseUrl 参数")
                    return false
                end
                
                return true
            else
                print("[ha_control] 错误: 无法解析配置文件 JSON 格式")
            end
        else
            print("[ha_control] 错误: 无法读取配置文件 " .. configPath)
        end
    else
        print("[ha_control] 错误: 找不到配置文件 ha_config.json")
    end
    
    -- 使用默认配置（但标记为不完整）
    config = {
        baseUrl = "http://192.168.2.111:8123/",
        entityId = "light.yeelink_cn_246813879_colora_S_2",
        scrollThrottleTime = 0.1,
        brightnessStep = 50,
        invertScrollDirection = false,
        debugMode = false,
        fastReload = true,
        -- 注意：这里缺少 token 参数
    }
    configLoaded = true
    print("[ha_control] 使用默认配置（缺少 token，功能受限）")
    return false
end

-- 配置验证函数
local function validateConfig()
    local issues = {}
    
    if not config.token or config.token == "" then
        table.insert(issues, "缺少 Home Assistant 访问令牌 (token)")
    end
    
    if not config.baseUrl or config.baseUrl == "" then
        table.insert(issues, "缺少 Home Assistant 基础URL (baseUrl)")
    end
    
    if #issues > 0 then
        local errorMsg = "HA配置问题:\n" .. table.concat(issues, "\n")
        showCustomAlert("❌ " .. errorMsg, 50, 5)
        print("[ha_control] 配置验证失败:")
        for _, issue in ipairs(issues) do
            print("  - " .. issue)
        end
        return false
    end
    
    return true
end

-- 加载配置
loadConfig()



-- 以下是功能实现，一般不需要修改
-- =====================================================

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

-- 关闭所有自定义 alert（简化版本，不需要实际操作）
local function closeAllCustomAlerts()
    -- 由于使用原生 hs.alert.show，不需要手动管理 canvas
end

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
                showCustomAlert("⚠️ 无法解析设备状态", 50, 2)
                callback(nil)
            end
        else
            showCustomAlert("❌ 获取设备状态失败，错误码: " .. code, 50, 2)
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
    
    -- 根据设备类型选择合适的服务
    local url, deviceType
    if string.find(targetEntityId, "button") then
        url = config.baseUrl .. "api/services/button/press"
        deviceType = "按钮"
    elseif string.find(targetEntityId, "light") then
        url = config.baseUrl .. "api/services/light/toggle"
        deviceType = "灯光"
    else
        -- 默认使用homeassistant.toggle服务
        url = config.baseUrl .. "api/services/homeassistant/toggle"
        deviceType = "设备"
    end
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            closeAllCustomAlerts()
            
            -- 根据设备类型显示不同的消息
            if string.find(targetEntityId, "button.yeelink_colora_6b37_toggle") then
                showCustomAlert("🌻切换顶灯开关", 50, 2)
            elseif string.find(targetEntityId, "yeelink_cn_404173164_stripa_s_2") then
                showCustomAlert("🌈切换灯带开关", 50, 2)
            elseif string.find(targetEntityId, "button.yeelink_lamp2_e655_toggle") then
                showCustomAlert("📝切换台灯开关", 50, 2)
            elseif string.find(targetEntityId, "philips_cn_71291406_candle_s_2") then
                showCustomAlert("🔱切换上台灯开关", 50, 2)
            else
                showCustomAlert("✅" .. deviceType .. "切换成功", 50, 2)
            end
        else
            showCustomAlert("❌ 控制" .. deviceType .. "失败: " .. code, 50, 2)
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
            closeAllCustomAlerts() -- 关闭所有已存在的alert

            showCustomAlert("💡灯光已打开", 50, 2)
        else
            showCustomAlert("❌打开灯失败: " .. code, 50, 2)
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
            closeAllCustomAlerts() -- 关闭所有已存在的alert

            showCustomAlert("💡灯光已关闭", 50, 2)
        else
            showCustomAlert("❌关闭灯失败: " .. code, 50, 2)
        end
    end)
end

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
             --   showCustomAlert("⚠️ 无法获取亮度信息", 50, 2)
                callback(nil)
            end
        else
            showCustomAlert("❌获取亮度失败，错误码: " .. code, 50, 2)
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
            closeAllCustomAlerts()
            -- 使用四舍五入以匹配HA的显示
            local brightnessPercent = math.floor(brightness / 255 * 100 + 0.5)
            if brightnessPercent < 1 then
                brightnessPercent = 1
            end
            showCustomAlert(string.format("💡亮度 : %d%%", brightnessPercent), 50, 1.2)
        else
            showCustomAlert("❌设置亮度失败: " .. code, 50, 2)
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

-- 增强的日志函数（优化性能）
local logger = hs.logger.new('ha_control', 'warning')  -- 只记录警告和错误
logger.setLogLevel('warning')

local function log(message)
    -- 只在调试模式下记录详细日志
    if config.debugMode then
        if logger then
            logger:w(message)
        else
            print("[ha_control] " .. tostring(message))
        end
    end
end

-- 错误日志函数（总是记录）
local function logError(message)
    if logger then
        logger:e(message)
    else
        print("[ha_control ERROR] " .. tostring(message))
    end
end

-- 获取滚轮值的函数（优化性能）
local function getScrollValue(event)
    -- 直接获取滚轮垂直方向的滚动值
    local scrollY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1)
    
    -- 如果主要方法失败，尝试备用方法
    if not scrollY or scrollY == 0 then
        -- 尝试其他可能的滚轮事件属性
        local properties = {
            hs.eventtap.event.properties.scrollWheelEventUnitDeltaAxis1,
            hs.eventtap.event.properties.scrollWheelEventFixedPtDeltaAxis1,
            hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1
        }
        
        -- 按优先级尝试其他属性
        for _, prop in ipairs(properties) do
            if prop then
                local value = event:getProperty(prop)
                if value and value ~= 0 then
                    scrollY = value
                    break
                end
            end
        end
    end
    
    -- 只在调试模式下记录详细信息
    if not scrollY or scrollY == 0 then
        if config.debugMode then
            logError("无法获取有效的滚轮值")
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

-- 监听器变量声明（在startWatchers函数中创建）
local keyWatcher = nil
local scrollWatcher = nil

-- 清理函数
local function cleanup()
    -- 停止事件监听器
    if keyWatcher then
        keyWatcher:stop()
        keyWatcher = nil
    end
    if scrollWatcher then
        scrollWatcher:stop()
        scrollWatcher = nil
    end
    
    -- 清理显示亮度模块
    if displayBrightness then
        displayBrightness.cleanup()
    end
    
    -- 清理F10相关定时器
    if f10Timer then
        f10Timer:stop()
        f10Timer = nil
    end
    if f10BrightnessTimer then
        f10BrightnessTimer:stop()
        f10BrightnessTimer = nil
    end
    
    -- 清理F12相关定时器（如果存在）
    if f12Timer then
        f12Timer:stop()
        f12Timer = nil
    end
    if f12BrightnessTimer then
        f12BrightnessTimer:stop()
        f12BrightnessTimer = nil
    end
    
    isWatcherInstalled = false
    log("所有监听器和定时器已停止")
end

-- 启动监听器函数
local function startWatchers()
    -- 确保清理旧的监听器
    cleanup()
    
    -- 重新创建监听器（因为cleanup中设置为nil）
    keyWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
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
    
    scrollWatcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
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
                                    -- 最低亮度设为1（1%）
                                    local minBrightness = 1
                                    local newBrightness
                                    if currentBrightness and currentBrightness > minBrightness then
                                        newBrightness = math.max(minBrightness, currentBrightness - brightnessStep)
                                    else
                                        newBrightness = minBrightness
                                    end
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
    
    -- 启动监听器
    if keyWatcher then
        keyWatcher:start()
    end
    if scrollWatcher then
        scrollWatcher:start()
    end
    
    isWatcherInstalled = true
    log("监听器已启动")
end

-- 注册清理函数
hs.shutdownCallback = cleanup



-- =====================================================
-- 快捷键设置区域 (方便修改)
-- =====================================================

-- 添加手动重启监听器的热键
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "L", function()
    if isWatcherInstalled then
        cleanup()
        showCustomAlert("⏹️ 灯光控制监听器已停止", 50, 2)
    else
        startWatchers()
    end
end)

-- F9 控制相关变量
local f9PressTime = nil
local f9Timer = nil
local f9BrightnessTimer = nil
local f9BrightnessDirection = 1  -- 1为增加亮度，-1为减少亮度
local f9CurrentBrightness = 128
local f9IsLongPress = false
local f9EntityId = "light.ding_deng"  -- F9控制的设备ID

-- 获取F9设备的当前亮度
local function getF9Brightness(callback, showError)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. f9EntityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.attributes and state.attributes.brightness then
                callback(state.attributes.brightness)
            else
                if showError then
                    showCustomAlert("⚠️ 无法获取顶灯亮度信息", 50, 2)
                end
                callback(nil)
            end
        else
            if showError then
                showCustomAlert("❌ 获取顶灯亮度失败，错误码: " .. code, 50, 2)
            end
            callback(nil)
        end
    end)
end

-- 设置F9设备的亮度
local function setF9Brightness(brightness)
    local serviceData = {
        entity_id = f9EntityId,
        brightness = brightness
    }
    
    local url = config.baseUrl .. "api/services/light/turn_on"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            closeAllCustomAlerts()
            -- 使用四舍五入以匹配HA的显示
            local brightnessPercent = math.floor(brightness / 255 * 100 + 0.5)
            if brightnessPercent < 1 then
                brightnessPercent = 1
            end
            showCustomAlert(string.format("💡顶灯亮度 : %d%%", brightnessPercent), 50, 1.2)
        else
            showCustomAlert("❌ 设置顶灯亮度失败: " .. code, 50, 2)
        end
    end)
end

-- 停止F9亮度调节
local function f9StopBrightnessAdjustment()
    if f9BrightnessTimer then
        f9BrightnessTimer:stop()
        f9BrightnessTimer = nil
    end
end

-- F9 亮度渐变函数
local function f9AdjustBrightness()
    local brightnessStep = math.floor(255 * 0.1)  -- 10%步进
    
    if f9BrightnessDirection == 1 then
        -- 增加亮度
        local newBrightness = math.min(255, f9CurrentBrightness + brightnessStep)
        if newBrightness >= 255 then
            f9CurrentBrightness = 255
            setF9Brightness(f9CurrentBrightness)
            showCustomAlert("🔆顶灯亮度已最高", 50, 2)
            f9StopBrightnessAdjustment()
            return
        else
            f9CurrentBrightness = newBrightness
            setF9Brightness(f9CurrentBrightness)
        end
    else
        -- 减少亮度，最低1%亮度
        local minBrightness = 1
        local newBrightness = math.max(minBrightness, f9CurrentBrightness - brightnessStep)
        if newBrightness <= minBrightness then
            f9CurrentBrightness = minBrightness
            setF9Brightness(f9CurrentBrightness)
            showCustomAlert("🔅顶灯亮度已最低", 50, 2)
            f9StopBrightnessAdjustment()
            return
        else
            f9CurrentBrightness = newBrightness
            setF9Brightness(f9CurrentBrightness)
        end
    end
end

-- 绑定 F9 快捷键来控制顶灯（支持长按亮度控制）
hs.hotkey.bind({}, "f9", function()
    f9PressTime = hs.timer.secondsSinceEpoch()
    f9IsLongPress = false
    
    -- 获取当前亮度作为起始值（静默获取，不显示错误）
    getF9Brightness(function(currentBrightness)
        if currentBrightness then
            f9CurrentBrightness = currentBrightness
        end
    end, false)
    
    -- 设置0.5秒后开始亮度调节的定时器
    f9Timer = hs.timer.doAfter(0.5, function()
        f9IsLongPress = true
        
        -- 检查当前亮度，进行智能方向判断
        local currentBrightnessPercent = f9CurrentBrightness / 255 * 100
        if currentBrightnessPercent <= 2 then
            f9BrightnessDirection = 1  -- 强制设为增加亮度
        elseif currentBrightnessPercent >= 90 then
            f9BrightnessDirection = -1  -- 强制设为减少亮度
        else
            -- 每次长按时切换亮度方向
            f9BrightnessDirection = -f9BrightnessDirection
        end
        
        -- 开始亮度渐变
        f9BrightnessTimer = hs.timer.doEvery(0.12, f9AdjustBrightness)
    end)
end, function()
    -- 按键释放时的处理
    local pressDuration = hs.timer.secondsSinceEpoch() - (f9PressTime or 0)
    
    -- 停止所有定时器
    if f9Timer then
        f9Timer:stop()
        f9Timer = nil
    end
    f9StopBrightnessAdjustment()
    
    -- 如果按键时间小于0.4秒且不是长按，则执行开关切换
    if pressDuration < 0.4 and not f9IsLongPress then
        toggleDevice("button.yeelink_colora_6b37_toggle")  -- 使用按钮实体控制顶灯开关
    end
    
    f9PressTime = nil
    f9IsLongPress = false
end)

-- F9 控制相关变量
local f9PressTime = nil
local f9Timer = nil
local f9BrightnessTimer = nil
local f9BrightnessDirection = 1  -- 1为增加亮度，-1为减少亮度
local f9CurrentBrightness = 128
local f9IsLongPress = false
local f9EntityId = "light.ding_deng"  -- F9控制的设备ID

-- 获取F9设备的当前亮度
local function getF9Brightness(callback, showError)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. f9EntityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.attributes and state.attributes.brightness then
                callback(state.attributes.brightness)
            else
                if showError then
                    showCustomAlert("⚠️ 无法获取顶灯亮度信息", 50, 2)
                end
                callback(nil)
            end
        else
            if showError then
                showCustomAlert("❌ 获取顶灯亮度失败，错误码: " .. code, 50, 2)
            end
            callback(nil)
        end
    end)
end

-- 设置F9设备的亮度 (第二个定义，已修复)
local function setF9Brightness(brightness)
    local serviceData = {
        entity_id = f9EntityId,
        brightness = brightness
    }
    
    local url = config.baseUrl .. "api/services/light/turn_on"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            closeAllCustomAlerts()
            -- 使用四舍五入以匹配HA的显示
            local brightnessPercent = math.floor(brightness / 255 * 100 + 0.5)
            if brightnessPercent < 1 then
                brightnessPercent = 1
            end
            showCustomAlert(string.format("💡顶灯亮度 : %d%%", brightnessPercent), 50, 1.2)
        else
            showCustomAlert("❌ 设置顶灯亮度失败: " .. code, 50, 2)
        end
    end)
end

-- 获取F10设备的当前亮度
local function getF10Brightness(callback, showError)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. f10EntityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.attributes and state.attributes.brightness then
                callback(state.attributes.brightness)
            else
                if showError then
                    showCustomAlert("⚠️ 无法获取顶灯亮度信息", 50, 2)
                end
                callback(nil)
            end
        else
            if showError then
                showCustomAlert("❌ 获取顶灯亮度失败，错误码: " .. code, 50, 2)
            end
            callback(nil)
        end
    end)
end

-- 设置F10设备的亮度
local function setF10Brightness(brightness)
    local serviceData = {
        entity_id = f10EntityId,
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
            -- 使用四舍五入以匹配HA的显示
            local brightnessPercent = math.floor(brightness / 255 * 100 + 0.5)
            -- 在0.1%-0.9%范围内显示为1%
            if brightnessPercent < 1 then
                brightnessPercent = 1
            end
            showCustomAlert(string.format("💡顶灯亮度 : %d%%", brightnessPercent), 50, 1.2)
        else
            showCustomAlert("❌ 设置顶灯亮度失败: " .. code, 50, 2)
        end
    end)
end

-- 停止F9亮度调节
local function f9StopBrightnessAdjustment()
    if f9BrightnessTimer then
        f9BrightnessTimer:stop()
        f9BrightnessTimer = nil
    end
end

-- F9 亮度渐变函数
local function f9AdjustBrightness()
    local brightnessStep = math.floor(255 * 0.1)  -- 10%步进，约25.5个亮度单位
    
    if f9BrightnessDirection == 1 then
        -- 增加亮度
        local newBrightness = math.min(255, f9CurrentBrightness + brightnessStep)
        
        -- 如果达到最高亮度，停止调节
        if newBrightness >= 255 then
            f9CurrentBrightness = 255
            setF9Brightness(f9CurrentBrightness)
            showCustomAlert("🔆顶灯亮度已最高", 50, 2)
            f9StopBrightnessAdjustment()
            return
        else
            f9CurrentBrightness = newBrightness
            setF9Brightness(f9CurrentBrightness)
        end
    else
        -- 减少亮度，最低1%亮度
        local minBrightness = 1
        local newBrightness = math.max(minBrightness, f9CurrentBrightness - brightnessStep)
        
        -- 如果达到最低亮度，停止调节
        if newBrightness <= minBrightness then
            f9CurrentBrightness = minBrightness
            setF9Brightness(f9CurrentBrightness)
            showCustomAlert("🔅顶灯亮度已最低", 50, 2)
            f9StopBrightnessAdjustment()
            return
        else
            f9CurrentBrightness = newBrightness
            setF9Brightness(f9CurrentBrightness)
        end
    end
end


-- F12 亮度控制相关变量
local f12PressTime = nil
local f12Timer = nil
local f12BrightnessTimer = nil
local f12BrightnessDirection = 1  -- 1为增加亮度，-1为减少亮度
local f12CurrentBrightness = 128
local f12IsLongPress = false
local f12EntityId = "light.yeelink_lamp2_e655_switch_status"  -- F12控制的设备ID（已修正）

-- 获取F12设备的当前亮度
local function getF12Brightness(callback, showError)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. f12EntityId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.attributes and state.attributes.brightness then
                callback(state.attributes.brightness)
            else
                if showError then
                    showCustomAlert("⚠️ 无法获取台灯亮度信息", 50, 2)
                end
                callback(nil)
            end
        else
            if showError then
                showCustomAlert("❌ 获取台灯亮度失败，错误码: " .. code, 50, 2)
            end
            callback(nil)
        end
    end)
end

-- 设置F12设备的亮度
local function setF12Brightness(brightness)
    local serviceData = {
        entity_id = f12EntityId,
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
            closeAllCustomAlerts()
            -- 使用四舍五入以匹配HA的显示
            local brightnessPercent = math.floor(brightness / 255 * 100 + 0.5)
            -- 在0.1%-0.9%范围内显示为1%
            if brightnessPercent < 1 then
                brightnessPercent = 1
            end
            showCustomAlert(string.format("􀆬台灯亮度 : %d%%", brightnessPercent), 50, 1.2)
        else
            showCustomAlert("❌ 设置台灯亮度失败: " .. code, 50, 2)
        end
    end)
end

-- 停止F12亮度调节
local function f12StopBrightnessAdjustment()
    if f12BrightnessTimer then
        f12BrightnessTimer:stop()
        f12BrightnessTimer = nil
    end
end

-- F12 亮度渐变函数
local function f12AdjustBrightness()
    local brightnessStep = math.floor(255 * 0.02)  -- 5%步进，约12.75个亮度单位
    
    if f12BrightnessDirection == 1 then
        -- 增加亮度
        local newBrightness = math.min(255, f12CurrentBrightness + brightnessStep)
        
        -- 如果达到最高亮度，停止调节
        if newBrightness >= 255 then
            f12CurrentBrightness = 255
            setF12Brightness(f12CurrentBrightness)
       --     showCustomAlert("🔆 台灯亮度已最高", 50, 1.5)
            f12StopBrightnessAdjustment()
            return
        else
            f12CurrentBrightness = newBrightness
            setF12Brightness(f12CurrentBrightness)
        end
    else
        -- 减少亮度，最低1%亮度
        local minBrightness = 1
        local newBrightness = math.max(minBrightness, f12CurrentBrightness - brightnessStep)
        
        -- 如果达到最低亮度，停止调节
        if newBrightness <= minBrightness then
            f12CurrentBrightness = minBrightness
            setF12Brightness(f12CurrentBrightness)
      --      showCustomAlert("🔅 台灯亮度已最低", 50, 1.5)
            f12StopBrightnessAdjustment()
            return
        else
            f12CurrentBrightness = newBrightness
            setF12Brightness(f12CurrentBrightness)
        end
    end
end

-- 绑定 F12 快捷键来控制桌面台灯（支持长按亮度控制）
hs.hotkey.bind({}, "f12", function()
    f12PressTime = hs.timer.secondsSinceEpoch()
    f12IsLongPress = false
    
    -- 获取当前亮度作为起始值（静默获取，不显示错误）
     getF12Brightness(function(currentBrightness)
         if currentBrightness then
             f12CurrentBrightness = currentBrightness
         end
     end, false)
    
    -- 设置0.7秒后开始亮度调节的定时器
      f12Timer = hs.timer.doAfter(0.5, function()
          f12IsLongPress = true
          
          -- 检查当前亮度，进行智能方向判断
          local currentBrightnessPercent = f12CurrentBrightness / 255 * 100
          if currentBrightnessPercent <= 2 then
              f12BrightnessDirection = 1  -- 强制设为增加亮度
     --         showCustomAlert("􁛂开始增加亮度", 50, 1)
          elseif currentBrightnessPercent >= 90 then
              f12BrightnessDirection = -1  -- 强制设为减少亮度
   --           showCustomAlert("􁑯亮度过高，开始减少亮度", 50, 1)
          else
              -- 每次长按时切换亮度方向
              f12BrightnessDirection = -f12BrightnessDirection
              
              if f12BrightnessDirection == 1 then
     --             showCustomAlert("􁛂开始增加亮度", 50, 1)
              else
    --              showCustomAlert("􁑯开始减少亮度", 50, 1)
              end
          end
          
          -- 开始亮度渐变
          f12BrightnessTimer = hs.timer.doEvery(0.12, f12AdjustBrightness)
      end)
end, function()
    -- 按键释放时的处理
    local pressDuration = hs.timer.secondsSinceEpoch() - (f12PressTime or 0)
    
    -- 停止所有定时器
    if f12Timer then
        f12Timer:stop()
        f12Timer = nil
    end
    f12StopBrightnessAdjustment()
    
    -- 如果按键时间小于0.4秒且不是长按，则执行开关切换
    if pressDuration < 0.4 and not f12IsLongPress then
        toggleDevice("button.yeelink_lamp2_e655_toggle")
    end
    
    f12PressTime = nil
    f12IsLongPress = false
end)

-- 绑定 F18 快捷键来控制上台灯
hs.hotkey.bind({}, "f18", function()
    toggleDevice("light.philips_candle_9441_switch_status")  -- 已修正为正确的实体ID
end)
-- 执行 Home Assistant 场景
local function runScene(sceneEntityId)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    -- 使用完整的entity_id格式
    local serviceData = {
        entity_id = sceneEntityId
    }
    
    local url = config.baseUrl .. "api/services/scene/turn_on"
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
   --         hs.alert.show("场景:桌面开灯", hs.screen.primaryScreen(), smallerFontStyle)
        else
            -- 显示更详细的错误信息
            local errorMsg = "执行场景失败: " .. code
            if body then
                local errorData = hs.json.decode(body)
                if errorData and errorData.message then
                    errorMsg = errorMsg .. " - " .. errorData.message
                end
            end
            showCustomAlert(errorMsg, 50, 2)
        end
    end)
end

-- 绑定 F18 键来执行"桌面开灯"
hs.hotkey.bind({"ctrl"}, "pageup", function()
    -- 创建 AppleScript 命令字符串来执行快捷指令
    local script = [[
do shell script "shortcuts run 'Deskon'"
]]
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
    
    -- 执行 Home Assistant 场景"桌面开灯"
    runScene("scene.zhuo_mian_kai_deng_zhong_zhi")
    
end)

-- 绑定 ctrl + pagedown 键来执行"桌面关灯"和"关闭顶灯"
hs.hotkey.bind({"ctrl"}, "pagedown", function()
    -- 创建 AppleScript 命令字符串来执行快捷指令
    local script = [[
do shell script "shortcuts run 'Deskoff'"
]]
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
    
    -- 关闭顶灯
    local serviceData = {
        entity_id = f10EntityId
    }
    
    local url = config.baseUrl .. "api/services/light/turn_off"
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    hs.http.asyncPost(url, hs.json.encode(serviceData), headers, function(code, body, headers)
        if code == 200 or code == 201 then
            closeAllCustomAlerts() -- 关闭所有已存在的alert
            showCustomAlert("💡顶灯已关闭", 50, 2)
        else
            showCustomAlert("❌关闭顶灯失败: " .. code, 50, 2)
        end
    end)
end)
-- 统一初始化所有监听器和服务
local configValid = validateConfig()
if configValid then
    startWatchers()
    
    -- 初始化显示亮度模块
    if displayBrightness then
        displayBrightness.init(config, log, showCustomAlert, closeAllCustomAlerts)
        displayBrightness.startIlluminationMonitoring()
    end
    
    -- 异步显示初始化提示
    hs.timer.doAfter(0.5, function()
        showCustomAlert("👌🏻 HA控制初始化成功", 50, 3)
    end)
else
    -- 配置无效时的处理
    hs.timer.doAfter(0.5, function()
        showCustomAlert("⚠️ HA配置不完整，请检查 ha_config.json", 50, 5)
    end)
end
