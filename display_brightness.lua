-- 显示器亮度调节模块
-- 使用 BetterDisplay 应用控制外接显示器亮度

local M = {}

-- 模块配置
local config = {}
local logger = nil
local illuminationTimer = nil
local lastIlluminationValue = nil

-- 光照传感器ID
local illuminationSensorId = "sensor.xiaomi_pir1_45bb_illumination"

-- 初始化模块
function M.init(moduleConfig, moduleLogger, showCustomAlert, closeAllCustomAlerts)
    config = moduleConfig or {}
    logger = moduleLogger
    M.showCustomAlert = showCustomAlert
    M.closeAllCustomAlerts = closeAllCustomAlerts
    
    -- 设置默认配置
    config.debugMode = config.debugMode or false
    config.fastReload = config.fastReload or true
    config.token = config.token or ""
    config.baseUrl = config.baseUrl or "http://192.168.2.111:8123/"
end

-- 日志函数
local function log(message)
    if config.debugMode and logger then
        logger(message)
    end
end

-- 错误日志函数
local function logError(message)
    if logger then
        logger("[ERROR] " .. message)
    end
end

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
    local lgBrightness, aocBrightness
    
    -- 根据光照度设置LG显示器亮度（使用小数格式）
    if illumination < 30 then
        lgBrightness = "0.30"  -- 30%
    elseif illumination >= 30 and illumination <= 38 then
        lgBrightness = "0.31"  -- 31%
    else
        lgBrightness = "0.32"  -- 32%
    end
    
    -- 根据光照度设置AOC显示器亮度（使用小数格式）
    if illumination < 30 then
        aocBrightness = "0.50"  -- 50%
    elseif illumination >= 30 and illumination <= 38 then
        aocBrightness = "0.51"  -- 51%
    else
        aocBrightness = "0.52"  -- 52%
    end
    
    -- 为两个显示器设置不同的亮度
    local command1 = string.format('/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay set -name="LG HDR WQHD" -brightness=%s', lgBrightness)
    local command2 = string.format('/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay set -name="AOC 27″" -brightness=%s', aocBrightness)
    
    log(string.format("光照度: %d lux, LG亮度: %s, AOC亮度: %s", illumination, lgBrightness, aocBrightness))
    
    -- 先执行第一个显示器的命令
    hs.task.new("/bin/sh", function(exitCode1, stdOut1, stdErr1)
        if exitCode1 == 0 then
            log(string.format("LG HDR WQHD 亮度设置成功: %s", lgBrightness))
            
            -- 第一个显示器成功后，执行第二个显示器的命令
            hs.task.new("/bin/sh", function(exitCode2, stdOut2, stdErr2)
                if exitCode2 == 0 then
                    log(string.format("AOC 27″ 亮度设置成功: %s", aocBrightness))
                    -- 使用 SF Symbols 显示亮度调节提示
                    local brightnessIcon = "􀻟"  -- 可以替换为 SF Symbol

                    if M.closeAllCustomAlerts then
                        M.closeAllCustomAlerts()  -- 清除之前的alert提示
                    end
                    if M.showCustomAlert then
                        M.showCustomAlert(string.format("%s LG:%s%% AOC:%s%%", brightnessIcon, math.floor(tonumber(lgBrightness) * 100), math.floor(tonumber(aocBrightness) * 100)), 50, 2)
                    end
                else
                    log(string.format("AOC 27″ 亮度设置失败 (退出码: %d): %s", exitCode2, stdErr2))
                end
            end, {"-c", command2}):start()
        else
            log(string.format("LG HDR WQHD 亮度设置失败 (退出码: %d): %s", exitCode1, stdErr1))
        end
    end, {"-c", command1}):start()
end

-- 监控光照传感器
local function monitorIlluminationSensor()
    getSensorState(illuminationSensorId, function(illumination)
        if illumination then
            log(string.format("当前光照度: %d lux, 上次记录值: %s", illumination, tostring(lastIlluminationValue)))
            
            -- 检查光照度变化是否超过阈值
             if lastIlluminationValue == nil or math.abs(illumination - lastIlluminationValue) > 4 then
                 log("光照度变化超过4 lux，触发亮度调节")
                 -- 使用 betterdisplaycli 控制显示器亮度
                 setBrightnessWithCLI(illumination)
                 lastIlluminationValue = illumination
             end
        end
    end)
end

-- 启动光照传感器监控
function M.startIlluminationMonitoring()
    if illuminationTimer then
        illuminationTimer:stop()
    end
    
    -- 根据配置决定延迟时间
    local delayTime = config.fastReload and 20 or 15
    
    -- 延迟启动，避免重载时的网络请求影响性能
    illuminationTimer = hs.timer.doAfter(delayTime, function()
        monitorIlluminationSensor() -- 立即执行一次
        illuminationTimer = hs.timer.doEvery(30, monitorIlluminationSensor)
        log("光照传感器监控已启动")
    end)
    log(string.format("光照传感器监控已计划启动（%d秒后）", delayTime))
end

-- 停止光照传感器监控
function M.stopIlluminationMonitoring()
    if illuminationTimer then
        illuminationTimer:stop()
        illuminationTimer = nil
        log("光照传感器监控已停止")
    end
end

-- 手动设置显示器亮度（供外部调用）
function M.setBrightness(illumination)
    if illumination and illumination >= 0 then
        setBrightnessWithCLI(illumination)
    else
        logError("无效的光照度值: " .. tostring(illumination))
    end
end

-- 获取当前光照度（供外部调用）
function M.getCurrentIllumination(callback)
    getSensorState(illuminationSensorId, callback)
end

-- 清理资源
function M.cleanup()
    M.stopIlluminationMonitoring()
    lastIlluminationValue = nil
end

-- 重新配置模块
function M.reconfigure(newConfig)
    if newConfig then
        for k, v in pairs(newConfig) do
            config[k] = v
        end
    end
end

return M