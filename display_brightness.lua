-- 显示器亮度调节模块
-- 使用 BetterDisplay 应用控制外接显示器亮度

local M = {}

local config = {}
local logger = nil
local illuminationTimer = nil
local lastIlluminationValue = nil
local lastBrightnessAdjustTime = nil

local ILLUMINATION_SENSOR_ID = "sensor.xiaomi_pir1_45bb_illumination"
local BETTER_DISPLAY_PATH = "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
local ILLUMINATION_CHANGE_THRESHOLD = 4
local BRIGHTNESS_ADJUST_INTERVAL = 300
local MONITOR_INTERVAL = 300
local FAST_RELOAD_DELAY = 20
local DEFAULT_RELOAD_DELAY = 15
local BRIGHTNESS_ICON = "􀻟"

local DISPLAY_CONFIGS = {
    {
        name = "LG HDR WQHD",
        low = "0.30",
        medium = "0.31",
        high = "0.32",
    },
    {
        name = "AOC 27″",
        low = "0.50",
        medium = "0.51",
        high = "0.52",
    },
}

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

local function buildHeaders()
    return {
        ["Authorization"] = "Bearer " .. config.token,
        ["Content-Type"] = "application/json",
    }
end

-- 获取传感器状态
local function getSensorState(sensorId, callback)
    local headers = buildHeaders()
    local statusUrl = config.baseUrl .. "api/states/" .. sensorId

    hs.http.asyncGet(statusUrl, headers, function(code, body, _)
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

local function getDisplayBrightness(displayConfig, illumination)
    if illumination < 30 then
        return displayConfig.low
    end

    if illumination <= 38 then
        return displayConfig.medium
    end

    return displayConfig.high
end

local function getBrightnessPercent(brightness)
    return math.floor(tonumber(brightness) * 100)
end

local function showBrightnessAlert(lgBrightness, aocBrightness)
    if M.closeAllCustomAlerts then
        M.closeAllCustomAlerts()
    end

    if M.showCustomAlert then
        M.showCustomAlert(
            string.format(
                "%s LG:%s%% AOC:%s%%",
                BRIGHTNESS_ICON,
                getBrightnessPercent(lgBrightness),
                getBrightnessPercent(aocBrightness)
            ),
            50,
            2
        )
    end
end

local function runBrightnessCommand(displayName, brightness, callback)
    local command = string.format('%s set -name="%s" -brightness=%s', BETTER_DISPLAY_PATH, displayName, brightness)

    hs.task.new("/bin/sh", function(exitCode, _, stdErr)
        if exitCode ~= 0 then
            log(string.format("%s 亮度设置失败 (退出码: %d): %s", displayName, exitCode, stdErr))
            return
        end

        log(string.format("%s 亮度设置成功: %s", displayName, brightness))
        if callback then
            callback()
        end
    end, {"-c", command}):start()
end

-- 使用 BetterDisplay 应用设置显示器亮度
local function setBrightnessWithCLI(illumination)
    local lgBrightness = getDisplayBrightness(DISPLAY_CONFIGS[1], illumination)
    local aocBrightness = getDisplayBrightness(DISPLAY_CONFIGS[2], illumination)

    log(string.format("光照度: %d lux, LG亮度: %s, AOC亮度: %s", illumination, lgBrightness, aocBrightness))

    runBrightnessCommand(DISPLAY_CONFIGS[1].name, lgBrightness, function()
        runBrightnessCommand(DISPLAY_CONFIGS[2].name, aocBrightness, function()
            showBrightnessAlert(lgBrightness, aocBrightness)
        end)
    end)
end

local function hasMeaningfulIlluminationChange(illumination)
    return lastIlluminationValue == nil
        or math.abs(illumination - lastIlluminationValue) > ILLUMINATION_CHANGE_THRESHOLD
end

local function getAdjustCooldown(currentTime)
    if lastBrightnessAdjustTime == nil then
        return 0
    end

    local elapsed = currentTime - lastBrightnessAdjustTime
    if elapsed >= BRIGHTNESS_ADJUST_INTERVAL then
        return 0
    end

    return BRIGHTNESS_ADJUST_INTERVAL - elapsed
end

-- 监控光照传感器
local function monitorIlluminationSensor()
    getSensorState(ILLUMINATION_SENSOR_ID, function(illumination)
        if not illumination then
            return
        end

        log(string.format("当前光照度: %d lux, 上次记录值: %s", illumination, tostring(lastIlluminationValue)))

        if not hasMeaningfulIlluminationChange(illumination) then
            return
        end

        local currentTime = os.time()
        local remainingCooldown = getAdjustCooldown(currentTime)

        if remainingCooldown > 0 then
            local elapsed = BRIGHTNESS_ADJUST_INTERVAL - remainingCooldown
            log(string.format(
                "光照度变化超过%d lux，但距上次调整仅%d秒，需要等待%d秒后才能再次调整",
                ILLUMINATION_CHANGE_THRESHOLD,
                elapsed,
                remainingCooldown
            ))
            return
        end

        log("光照度变化超过4 lux，且距上次调整已超过5分钟，触发亮度调节")
        setBrightnessWithCLI(illumination)
        lastIlluminationValue = illumination
        lastBrightnessAdjustTime = currentTime
    end)
end

-- 启动光照传感器监控
function M.startIlluminationMonitoring()
    if illuminationTimer then
        illuminationTimer:stop()
    end

    local delayTime = config.fastReload and FAST_RELOAD_DELAY or DEFAULT_RELOAD_DELAY

    illuminationTimer = hs.timer.doAfter(delayTime, function()
        monitorIlluminationSensor()
        illuminationTimer = hs.timer.doEvery(MONITOR_INTERVAL, monitorIlluminationSensor)
        log("光照传感器监控已启动（每5分钟检查一次）")
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
    getSensorState(ILLUMINATION_SENSOR_ID, callback)
end

-- 清理资源
function M.cleanup()
    M.stopIlluminationMonitoring()
    lastIlluminationValue = nil
    lastBrightnessAdjustTime = nil
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
