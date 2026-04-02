local M = {}

local style = {
    textSize = 14,                            -- 文字大小
    textColor = { hex = "#f2f2f2", alpha = 1 }, -- 文字颜色 (十六进制色值, 透明度)
    fillColor = { hex = "#000000", alpha = 1 }, -- 填充颜色 (背景色)
    strokeColor = { hex = "#46ff32", alpha = 1 }, -- 描边颜色
    radius = 10,                                 -- 圆角半径 (像素)
    padding = 18,                               -- 内边距 (像素)
    fadeInDuration = 0.3,                       -- 淡入动画持续时间 (秒)
    fadeOutDuration = 0.3,                      -- 淡出动画持续时间 (秒)
    strokeWidth = 0,                            -- 描边宽度 (像素, 0表示无描边)
    maxWidthRatio = 0.55,                       -- 最大宽度比例 (相对于屏幕宽度)
}

local alertGap = 0
local defaultAlertTopPadding = -20 -- 消息框距离顶部的间距
local legacyAlertTopMargin = 50
local activeAlerts = {}
local activeAlertsByKey = {}
local resolvedFont = nil

local function resolveFont()
    if resolvedFont then
        return resolvedFont
    end

    local installedFamilies = {}
    for _, family in ipairs(hs.styledtext.fontFamilies()) do
        installedFamilies[family] = true
    end

    local preferredFonts = {
        { family = "HarmonyOS Sans OC", font = "HarmonyOS Sans OC Semibold" },
        { family = "SF Pro Text", font = "SF Pro Text Semibold" },
    }

    for _, candidate in ipairs(preferredFonts) do
        if installedFamilies[candidate.family] then
            resolvedFont = candidate.font
            return resolvedFont
        end
    end

    resolvedFont = ".AppleSystemUIFont"
    return resolvedFont
end

local function getScreenFrame(screen)
    if screen and screen.fullFrame then
        return screen:fullFrame()
    end

    if screen and screen.frame then
        return screen:frame()
    end

    return hs.screen.primaryScreen():fullFrame()
end

local function getDefaultTopMargin(screen)
    local targetScreen = screen or hs.screen.primaryScreen()
    local fullFrame = targetScreen:fullFrame()
    local usableFrame = targetScreen:frame()
    local menuBarHeight = math.max(0, usableFrame.y - fullFrame.y)

    return menuBarHeight + defaultAlertTopPadding
end

local function measureText(message, fontName, textSize, maxTextWidth)
    local rawSize = hs.drawing.getTextDrawingSize(message, {
        font = fontName,
        size = textSize,
    })
    local lineCount = select(2, message:gsub("\n", "")) + 1

    if rawSize.w <= maxTextWidth then
        return {
            w = math.ceil(rawSize.w),
            h = math.ceil(rawSize.h),
        }
    end

    local estimatedLines = math.max(lineCount, math.ceil(rawSize.w / maxTextWidth))
    local lineHeight = math.max(rawSize.h / math.max(lineCount, 1), textSize * 1.35)

    return {
        w = math.ceil(maxTextWidth),
        h = math.ceil(lineHeight * estimatedLines),
    }
end

local reflowAlerts

local function destroyAlert(alertEntry, fadeDuration, shouldReflow)
    if not alertEntry or alertEntry.isClosing then
        return
    end

    fadeDuration = tonumber(fadeDuration) or 0
    alertEntry.isClosing = true

    if alertEntry.timer then
        alertEntry.timer:stop()
        alertEntry.timer = nil
    end

    for index = #activeAlerts, 1, -1 do
        if activeAlerts[index] == alertEntry then
            table.remove(activeAlerts, index)
            break
        end
    end

    if alertEntry.key and activeAlertsByKey[alertEntry.key] == alertEntry then
        activeAlertsByKey[alertEntry.key] = nil
    end

    local alertCanvas = alertEntry.canvas
    alertEntry.canvas = nil

    if alertCanvas then
        alertCanvas:hide(fadeDuration)
        hs.timer.doAfter(fadeDuration, function()
            pcall(function()
                alertCanvas:delete()
            end)
        end)
    end

    if shouldReflow ~= false and reflowAlerts then
        reflowAlerts()
    end
end

local function buildAlertMetrics(text, fontName, screen)
    local screenFrame = getScreenFrame(screen)
    local maxTextWidth = math.max(180, math.floor(screenFrame.w * style.maxWidthRatio))
    local textSize = measureText(text, fontName, style.textSize, maxTextWidth)
    local alertSize = {
        w = textSize.w + style.padding * 2,
        h = textSize.h + style.padding * 2,
    }

    return textSize, alertSize
end

local function applyAlertContent(alertEntry, text, fontName, textSize, alertSize, screen, topMargin)
    alertEntry.screen = screen
    alertEntry.topMargin = topMargin
    alertEntry.size = alertSize

    alertEntry.canvas[1] = {
        id = "background",
        type = "rectangle",
        action = style.strokeWidth > 0 and "strokeAndFill" or "fill",
        fillColor = style.fillColor,
        strokeColor = style.strokeColor,
        strokeWidth = style.strokeWidth,
        roundedRectRadii = {
            xRadius = style.radius,
            yRadius = style.radius,
        },
        frame = {
            x = 0,
            y = 0,
            w = alertSize.w,
            h = alertSize.h,
        },
    }

    alertEntry.canvas[2] = {
        id = "message",
        type = "text",
        text = text,
        textFont = fontName,
        textSize = style.textSize,
        textColor = style.textColor,
        textAlignment = "center",
        textLineBreak = "wordWrap",
        antialias = true,
        frame = {
            x = style.padding,
            y = style.padding,
            w = textSize.w,
            h = textSize.h,
        },
    }
end

local function resetAlertTimer(alertEntry, duration)
    if alertEntry.timer then
        alertEntry.timer:stop()
        alertEntry.timer = nil
    end

    if duration >= 0 then
        alertEntry.timer = hs.timer.doAfter(duration, function()
            destroyAlert(alertEntry, style.fadeOutDuration)
        end)
    end
end

reflowAlerts = function()
    local offsetsByScreen = {}

    for _, alertEntry in ipairs(activeAlerts) do
        local screenFrame = getScreenFrame(alertEntry.screen)
        local screenId = alertEntry.screen:id()
        local offsetY = offsetsByScreen[screenId] or 0

        alertEntry.canvas:frame({
            x = screenFrame.x + (screenFrame.w - alertEntry.size.w) / 2,
            y = screenFrame.y + alertEntry.topMargin + offsetY,
            w = alertEntry.size.w,
            h = alertEntry.size.h,
        })

        offsetsByScreen[screenId] = offsetY + alertEntry.size.h + alertGap
    end
end

local function showInternal(message, topMargin, duration, screen, key)
    local fontName = resolveFont()
    local text = tostring(message or "")

    duration = tonumber(duration) or 2
    topMargin = tonumber(topMargin)
    if not topMargin then
        topMargin = getDefaultTopMargin(screen)
    elseif topMargin == legacyAlertTopMargin then
        topMargin = getDefaultTopMargin(screen)
    end

    screen = screen or hs.screen.primaryScreen()

    local textSize, alertSize = buildAlertMetrics(text, fontName, screen)

    if key then
        local existingAlert = activeAlertsByKey[key]
        if existingAlert and existingAlert.canvas and not existingAlert.isClosing then
            applyAlertContent(existingAlert, text, fontName, textSize, alertSize, screen, topMargin)
            reflowAlerts()
            resetAlertTimer(existingAlert, duration)
            return existingAlert.canvas
        end
    end

    local screenFrame = getScreenFrame(screen)
    local alertCanvas = hs.canvas.new({
        x = screenFrame.x,
        y = screenFrame.y + topMargin,
        w = alertSize.w,
        h = alertSize.h,
    })
    alertCanvas:level("status")
    alertCanvas:behavior({ "canJoinAllSpaces", "stationary" })
    alertCanvas:clickActivating(false)

    local alertEntry = {
        canvas = alertCanvas,
        screen = screen,
        topMargin = topMargin,
        size = alertSize,
        timer = nil,
        isClosing = false,
        key = key,
    }

    applyAlertContent(alertEntry, text, fontName, textSize, alertSize, screen, topMargin)
    table.insert(activeAlerts, alertEntry)
    if key then
        activeAlertsByKey[key] = alertEntry
    end

    reflowAlerts()
    alertCanvas:show(style.fadeInDuration)
    resetAlertTimer(alertEntry, duration)

    return alertCanvas
end

function M.show(message, topMargin, duration, screen)
    return showInternal(message, topMargin, duration, screen, nil)
end

function M.showKeyed(key, message, topMargin, duration, screen)
    return showInternal(message, topMargin, duration, screen, tostring(key or "default"))
end

function M.closeAll()
    for index = #activeAlerts, 1, -1 do
        destroyAlert(activeAlerts[index], style.fadeOutDuration, false)
    end
end

return M
