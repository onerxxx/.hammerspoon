local M = {}

local style = {
    textSize = 14,
    textColor = {hex = "#ffffff", alpha = 0.9},
    fillColor = {hex = "#000000", alpha = 0.9},
    strokeColor = {hex = "#000000", alpha = 0.1},
    radius = 0,
    padding = 17,
    fadeInDuration = 0.2,
    fadeOutDuration = 0.3,
    strokeWidth = 0,
    maxWidthRatio = 0.55,
}

local alertGap = 0
local defaultAlertTopPadding = -10
local legacyAlertTopMargin = 50
local activeAlerts = {}
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
        {family = "MiSans", font = "MiSans Demibold"},
        {family = "PingFang SC", font = "PingFang SC Semibold"},
        {family = "SF Pro Text", font = "SF Pro Text Semibold"},
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

function M.show(message, topMargin, duration, screen)
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

    local screenFrame = getScreenFrame(screen)
    local maxTextWidth = math.max(180, math.floor(screenFrame.w * style.maxWidthRatio))
    local textSize = measureText(text, fontName, style.textSize, maxTextWidth)
    local alertSize = {
        w = textSize.w + style.padding * 2,
        h = textSize.h + style.padding * 2,
    }

    local stackedHeight = 0
    for _, alertEntry in ipairs(activeAlerts) do
        if alertEntry.screen:id() == screen:id() then
            stackedHeight = stackedHeight + alertEntry.size.h + alertGap
        end
    end

    local alertFrame = {
        x = screenFrame.x + (screenFrame.w - alertSize.w) / 2,
        y = screenFrame.y + topMargin + stackedHeight,
        w = alertSize.w,
        h = alertSize.h,
    }

    local alertCanvas = hs.canvas.new(alertFrame)
    alertCanvas:level("status")
    alertCanvas:behavior({"canJoinAllSpaces", "stationary"})
    alertCanvas:clickActivating(false)

    alertCanvas[1] = {
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

    alertCanvas[2] = {
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

    local alertEntry = {
        canvas = alertCanvas,
        screen = screen,
        topMargin = topMargin,
        size = alertSize,
        timer = nil,
        isClosing = false,
    }

    table.insert(activeAlerts, alertEntry)
    alertCanvas:show(style.fadeInDuration)

    if duration >= 0 then
        alertEntry.timer = hs.timer.doAfter(duration, function()
            destroyAlert(alertEntry, style.fadeOutDuration)
        end)
    end

    return alertCanvas
end

function M.closeAll()
    for index = #activeAlerts, 1, -1 do
        destroyAlert(activeAlerts[index], style.fadeOutDuration, false)
    end
end

return M
