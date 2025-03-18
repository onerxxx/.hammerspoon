-- wheelzoom.lua
-- 实现网页缩放功能：按住ctrl+滚轮时触发cmd+或cmd-

-- 创建一个日志函数，方便调试
local function log(message)
    print(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message)
end

-- 初始化提示
log("网页缩放功能已启动，按住ctrl+滚轮可缩放网页")

-- 创建一个标志变量，用于跟踪是否已经安装了事件监听器
local isWatcherInstalled = false

-- 创建一个变量来跟踪上次滚动事件的时间戳
local lastScrollTime = 0
-- 定义滚动事件的最小间隔时间（秒）
local scrollInterval = 0.1
-- 创建一个标志变量，用于跟踪ctrl键是否被按下
local isCtrlDown = false

-- 创建键盘事件监听器，用于检测ctrl键的按下和释放
local keyWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local flags = event:getFlags()
    
    -- 检查ctrl键的状态
    local ctrlDown = flags.ctrl
    
    -- 如果状态发生变化，则更新标志变量并记录日志
    if ctrlDown ~= isCtrlDown then
        isCtrlDown = ctrlDown
        if isCtrlDown then
            log("检测到ctrl按下，开始监听滚轮事件")
        else
            log("检测到ctrl释放，停止监听滚轮事件")
        end
    end
    
    return false
end)

-- 创建鼠标滚轮事件监听器
local scrollWatcher = hs.eventtap.new({hs.eventtap.event.types.scrollWheel}, function(event)
    -- 只有在ctrl被按下时才处理滚轮事件
    if isCtrlDown then
        -- 获取当前时间
        local currentTime = hs.timer.secondsSinceEpoch()
        
        -- 检查是否已经过了最小间隔时间
        if (currentTime - lastScrollTime) >= scrollInterval then
            -- 更新上次滚动时间
            lastScrollTime = currentTime
            
            -- 获取滚轮垂直方向的滚动值
            local scrollY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1)
            
            -- 根据滚动方向模拟按下cmd+或cmd-
            if scrollY < 0 then
                -- 向上滚动，缩小网页 (cmd+减号)
                log("检测到向上滚动，模拟cmd+减号")
                hs.eventtap.keyStroke({"cmd"}, "-")
            elseif scrollY > 0 then
                -- 向下滚动，放大网页 (cmd+加号)
                log("检测到向下滚动，模拟cmd+加号")
                hs.eventtap.keyStroke({"cmd"}, "=")
            end
        end
        
        -- 阻止原始滚轮事件继续传播
        return true
    end
    
    -- 如果没有按下ctrl，则不拦截事件
    return false
end)

-- 启动监听器
keyWatcher:start()
scrollWatcher:start()
isWatcherInstalled = true

-- 添加一个热键来手动重启监听器
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Z", function()
    if isWatcherInstalled then
        keyWatcher:stop()
        scrollWatcher:stop()
        isWatcherInstalled = false
        log("网页缩放功能已停止")
        hs.notify.new({title="网页缩放", informativeText="功能已停止"}):send()
    else
        keyWatcher:start()
        scrollWatcher:start()
        isWatcherInstalled = true
        log("网页缩放功能已启动")
        hs.notify.new({title="网页缩放", informativeText="功能已启动"}):send()
    end
end)

-- 确保脚本退出时清理资源
hs.shutdownCallback = function()
    if isWatcherInstalled then
        keyWatcher:stop()
        scrollWatcher:stop()
        log("网页缩放功能已停止")
    end
end

log("网页缩放模块加载完成")