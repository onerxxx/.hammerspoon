-- 初始化日志记录器
local logger = hs.logger.new('apps_shortcuts', 'debug')

local function log(message)
    if logger then
        logger:d(message)
    end
end

-- 检查鼠标光标是否在抖音应用窗口内
local function isCursorInDouYinWindow()
    -- 获取鼠标当前位置
    local mousePos = hs.mouse.getAbsolutePosition()
    
    -- 获取当前所有窗口
    local windows = hs.window.orderedWindows()
    
    for _, window in ipairs(windows) do
        -- 检查窗口是否属于抖音应用
        local app = window:application()
        if app and (app:bundleID() == 'com.ss.iphone.ugc.Aweme' or app:name() == '抖音') then
            -- 检查鼠标是否在窗口内
            local frame = window:frame()
            if mousePos.x >= frame.x and mousePos.x <= frame.x + frame.w and
               mousePos.y >= frame.y and mousePos.y <= frame.y + frame.h then
                return true
            end
        end
    end
    
    return false
end

-- 抖音应用鼠标中键触发Y键，0.1秒后触发J键
local function handleMiddleClick(event)
    local app = hs.application.frontmostApplication()
    -- 检查当前应用是否为抖音且鼠标光标在抖音窗口内
    if app and (app:bundleID() == 'com.ss.iphone.ugc.Aweme' or app:name() == '抖音') and isCursorInDouYinWindow() then
        log("抖音应用检测到中键点击，且光标在抖音窗口内，触发Y键")
        hs.eventtap.keyStroke('', 'j')
      
        -- 延时0.1秒后触发J键
        hs.timer.doAfter(0.1, function()
            log("延时0.1秒后触发J键")
            hs.eventtap.keyStroke('', 'y')
        end)
    end
end

-- 创建鼠标中键事件监听器
local middleClickWatcher = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown}, function(event)
    if event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 2 then
        handleMiddleClick(event)
        
    end
end)
middleClickWatcher:start()



-- 确保脚本退出时清理资源
hs.shutdownCallback = function()
    if middleClickWatcher then
        middleClickWatcher:stop()
        log("鼠标中键监听已停止")
    end
end