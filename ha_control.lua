-- Home Assistant 控制脚本

-- =====================================================
-- 所有快捷键设置都在文件底部的「快捷键设置区域」，方便修改
-- =====================================================

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
        baseUrl = "http://192.168.2.111:8123/",
        entityId = "light.yeelink_colora_6b37_switch_status",
        scrollThrottleTime = 0.1,
        brightnessStep = 50,
        invertScrollDirection = false,  -- 是否反转滚轮方向
      
    }
    return false
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
            if string.find(targetEntityId, "yeelink_colora_6b37") then
                showCustomAlert("🌻切换顶灯开关", 50, 2)
            elseif string.find(targetEntityId, "yeelink_stripa_6102") then
                showCustomAlert("🌈切换灯带开关", 50, 2)
            elseif string.find(targetEntityId, "yeelink_Lamp2_e655") then
                showCustomAlert("📝切换台灯开关", 50, 2)
            elseif string.find(targetEntityId, "philips_candle_9441") then
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
            showCustomAlert("❌ 打开灯失败: " .. code, 50, 2)
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
            showCustomAlert("❌ 关闭灯失败: " .. code, 50, 2)
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
            showCustomAlert("❌ 获取亮度失败，错误码: " .. code, 50, 2)
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
            showCustomAlert(string.format("💡亮度 : %d%%", math.max(1, math.floor(brightness / 255 * 100))), 50, 1.2)
        else
            showCustomAlert("❌ 设置亮度失败: " .. code, 50, 2)
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
local logger = hs.logger.new('ha_control', 'debug')
logger.setLogLevel('info')

local function log(message)
    if logger then
        logger:i(message)
    else
        print("[ha_control] " .. tostring(message))
    end
end

-- 光照传感器监控功能
local illuminationSensorId = "sensor.xiaomi_pir1_45bb_illumination"
local lastIlluminationValue = nil
local illuminationTimer = nil

-- 获取传感器状态
local function getSensorState(sensorId, callback)
    local headers = {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json"
    }
    
    local statusUrl = config.baseUrl .. "api/states/" .. sensorId
    
    hs.http.asyncGet(statusUrl, headers, function(code, body, headers)
        if code == 200 then
            local state = hs.json.decode(body)
            if state and state.state then
                local value = tonumber(state.state)
                callback(value)
            else
                log("无法解析传感器状态: " .. sensorId)
                callback(nil)
            end
        else
            log("获取传感器状态失败，错误码: " .. code .. ", 传感器: " .. sensorId)
            callback(nil)
        end
    end)
end



-- 使用 BetterDisplay 应用设置显示器亮度
local function setBrightnessWithCLI(illumination)
    local brightness
    
    -- 根据光照度设置亮度（使用小数格式）
    if illumination <= 42 then
        brightness = "0.64"  -- 64%
    else
        brightness = "0.65"  -- 65%
    end
    
    local command = string.format('/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay set -name="LG HDR WQHD" -brightness=%s', brightness)
    
    log(string.format("光照度: %d lux, 设置亮度为: %s", illumination, brightness))
    
    hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
            log(string.format("亮度设置成功: %s", brightness))
            -- 使用 SF Symbols 显示亮度调节提示
            local brightnessIcon = "􀻟"  -- 可以替换为 SF Symbol
            showCustomAlert(string.format("%s 亮度调整为: %s%%", brightnessIcon, math.floor(tonumber(brightness) * 100)), 50, 2)
        else
            log(string.format("亮度设置失败 (退出码: %d): %s", exitCode, stdErr))
        end
    end, {"-c", command}):start()
end

-- 监控光照传感器
local function monitorIlluminationSensor()
    getSensorState(illuminationSensorId, function(illumination)
        if illumination then
            log(string.format("当前光照度: %d lux, 上次记录值: %s", illumination, tostring(lastIlluminationValue)))
            
            -- 检查光照度变化是否超过阈值
             if lastIlluminationValue == nil or math.abs(illumination - lastIlluminationValue) > 2 then
                 log(string.format("光照度变化超过3 lux，触发亮度调节"))
                 -- 使用 betterdisplaycli 控制显示器亮度
                 setBrightnessWithCLI(illumination)
                 lastIlluminationValue = illumination
             else
                 log("光照度变化未超过2 lux，跳过亮度调节")
             end
        end
    end)
end

-- 启动光照传感器监控定时器
local function startIlluminationMonitoring()
    if illuminationTimer then
        illuminationTimer:stop()
    end
    
    -- 每10秒检查一次光照传感器
    illuminationTimer = hs.timer.doEvery(10, monitorIlluminationSensor)
    log("光照传感器监控已启动")
end

-- 停止光照传感器监控
local function stopIlluminationMonitoring()
    if illuminationTimer then
        illuminationTimer:stop()
        illuminationTimer = nil
        log("光照传感器监控已停止")
    end
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
    -- 停止光照传感器监控
    stopIlluminationMonitoring()
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
end

-- 注册清理函数
hs.shutdownCallback = cleanup

-- 初始启动监听器
startWatchers()

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

-- F10 亮度控制相关变量
local f10PressTime = nil
local f10Timer = nil
local f10BrightnessTimer = nil
local f10BrightnessDirection = 1  -- 1为增加亮度，-1为减少亮度
local f10CurrentBrightness = 128
local f10IsLongPress = false
local f10EntityId = "light.yeelink_colora_6b37_switch_status"  -- F10控制的设备ID

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
            local brightnessPercent = math.floor(brightness / 255 * 100)
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

-- F10 亮度渐变函数
local function f10AdjustBrightness()
    local brightnessStep = math.floor(255 * 0.02)  -- 5%步进，约12.75个亮度单位
    
    if f10BrightnessDirection == 1 then
        -- 增加亮度
        local newBrightness = math.min(255, f10CurrentBrightness + brightnessStep)
        
        -- 如果达到最高亮度，停止调节
        if newBrightness >= 255 then
            f10CurrentBrightness = 255
            setF10Brightness(f10CurrentBrightness)
            showCustomAlert("🔆顶灯亮度已最高", 50, 2)
            f10StopBrightnessAdjustment()
            return
        else
            f10CurrentBrightness = newBrightness
            setF10Brightness(f10CurrentBrightness)
        end
    else
        -- 减少亮度
        local minBrightness = math.floor(255 * 0.02)  -- 0.5%对应的亮度值
        local newBrightness = math.max(minBrightness, f10CurrentBrightness - brightnessStep)
        
        -- 如果达到最低亮度，停止调节
        if newBrightness <= minBrightness then
            f10CurrentBrightness = minBrightness
            setF10Brightness(f10CurrentBrightness)
            showCustomAlert("🔅顶灯亮度已最低", 50, 2)
            f10StopBrightnessAdjustment()
            return
        else
            f10CurrentBrightness = newBrightness
            setF10Brightness(f10CurrentBrightness)
        end
    end
end

-- 停止F10亮度调节
local function f10StopBrightnessAdjustment()
    if f10BrightnessTimer then
        f10BrightnessTimer:stop()
        f10BrightnessTimer = nil
    end
end

-- 绑定 F10 快捷键来控制顶灯（支持长按亮度控制）
hs.hotkey.bind({}, "f10", function()
    f10PressTime = hs.timer.secondsSinceEpoch()
    f10IsLongPress = false
    
    -- 获取当前亮度作为起始值（静默获取，不显示错误）
     getF10Brightness(function(currentBrightness)
         if currentBrightness then
             f10CurrentBrightness = currentBrightness
         end
     end, false)
    
    -- 设置1秒后开始亮度调节的定时器
     f10Timer = hs.timer.doAfter(1.0, function()
         f10IsLongPress = true
         
         -- 检查当前亮度，进行智能方向判断
         local currentBrightnessPercent = f10CurrentBrightness / 255 * 100
         if currentBrightnessPercent <= 2 then
             f10BrightnessDirection = 1  -- 强制设为增加亮度
        --     showCustomAlert("🔆 亮度过低，开始增加亮度", 50, 1)
         elseif currentBrightnessPercent >= 90 then
             f10BrightnessDirection = -1  -- 强制设为减少亮度
        --     showCustomAlert("🔅 亮度过高，开始减少亮度", 50, 1)
         else
             -- 每次长按时切换亮度方向
             f10BrightnessDirection = -f10BrightnessDirection
             
             if f10BrightnessDirection == 1 then
                 showCustomAlert("🔆 开始增加亮度", 50, 1)
             else
                 showCustomAlert("🔅 开始减少亮度", 50, 1)
             end
         end
         
         -- 开始亮度渐变
         f10BrightnessTimer = hs.timer.doEvery(0.1, f10AdjustBrightness)
     end)
end, function()
    -- 按键释放时的处理
    local pressDuration = hs.timer.secondsSinceEpoch() - (f10PressTime or 0)
    
    -- 停止所有定时器
    if f10Timer then
        f10Timer:stop()
        f10Timer = nil
    end
    f10StopBrightnessAdjustment()
    
    -- 如果按键时间小于0.4秒且不是长按，则执行开关切换
    if pressDuration < 0.4 and not f10IsLongPress then
        toggleDevice("light.yeelink_colora_6b37_switch_status")
    end
    
    f10PressTime = nil
    f10IsLongPress = false
end)

-- 绑定 F9 快捷键来控制桌面灯带
hs.hotkey.bind({}, "f9", function()
    toggleDevice("light.yeelink_stripa_6102_switch_status")
end)

-- F12 亮度控制相关变量
local f12PressTime = nil
local f12Timer = nil
local f12BrightnessTimer = nil
local f12BrightnessDirection = 1  -- 1为增加亮度，-1为减少亮度
local f12CurrentBrightness = 128
local f12IsLongPress = false
local f12EntityId = "light.yeelink_Lamp2_e655_Switch_status"  -- F12控制的设备ID

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
            local brightnessPercent = math.floor(brightness / 255 * 100)
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
        -- 减少亮度
        local minBrightness = math.floor(255 * 0.02)  -- 0.5%对应的亮度值
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

-- 停止F12亮度调节
local function f12StopBrightnessAdjustment()
    if f12BrightnessTimer then
        f12BrightnessTimer:stop()
        f12BrightnessTimer = nil
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
    
    -- 设置0.8秒后开始亮度调节的定时器
      f12Timer = hs.timer.doAfter(0.8, function()
          f12IsLongPress = true
          
          -- 检查当前亮度，进行智能方向判断
          local currentBrightnessPercent = f12CurrentBrightness / 255 * 100
          if currentBrightnessPercent <= 2 then
              f12BrightnessDirection = 1  -- 强制设为增加亮度
              showCustomAlert("􁛂开始增加亮度", 50, 1)
          elseif currentBrightnessPercent >= 90 then
              f12BrightnessDirection = -1  -- 强制设为减少亮度
              showCustomAlert("􁑯亮度过高，开始减少亮度", 50, 1)
          else
              -- 每次长按时切换亮度方向
              f12BrightnessDirection = -f12BrightnessDirection
              
              if f12BrightnessDirection == 1 then
                  showCustomAlert("􁛂开始增加亮度", 50, 1)
              else
                  showCustomAlert("􁑯开始减少亮度", 50, 1)
              end
          end
          
          -- 开始亮度渐变
          f12BrightnessTimer = hs.timer.doEvery(0.15, f12AdjustBrightness)
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
        toggleDevice("light.yeelink_Lamp2_e655_Switch_status")
    end
    
    f12PressTime = nil
    f12IsLongPress = false
end)

-- 绑定 F18 快捷键来控制上台灯
hs.hotkey.bind({}, "f18", function()
    toggleDevice("light.philips_candle_9441_switch_status")
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

-- 绑定快捷键 F17 键来执行"关灯"
hs.hotkey.bind({"ctrl"}, "pagedown", function()
    -- 创建 AppleScript 命令字符串来执行快捷指令
    local script = [[
do shell script "shortcuts run 'Deskoff'"
]]
    
    -- 执行 AppleScript
    hs.osascript.applescript(script)
end)
-- 启动光照传感器监控
startIlluminationMonitoring()



-- 初始化提示
showCustomAlert("👌🏻初始化成功", 50, 2)
showCustomAlert("🌞光照传感器监控已启动", 50, 3) -- 50代表距离屏幕顶部的距离(像素), 2代表显示持续时间(秒)
