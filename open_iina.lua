-- 监听剪贴板并使用系统默认播放器打开网络视频文件

-- 保存上一次的剪贴板内容，避免重复处理
local lastClipboardContent = ""
-- 初始化 lastFocusedApp 为当前焦点应用的名称，如果获取不到则为空字符串
local lastFocusedApp = hs.window.focusedWindow() and hs.window.focusedWindow():application() and hs.window.focusedWindow():application():name() or ""

-- 创建一个日志函数，方便调试
local function log(message)
    print(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message)
end

-- 初始化提示
log("剪贴板监听已启动，将自动检测网络视频文件路径并使用系统默认播放器打开")
log("初始焦点应用: " .. lastFocusedApp)

-- 处理剪贴板内容的函数
local function handleClipboardChange()
    local currentFocusedWindow = hs.window.focusedWindow()
    local currentAppObject = currentFocusedWindow and currentFocusedWindow:application()
    local currentAppName = currentAppObject and currentAppObject:name() or ""

    -- 获取当前剪贴板内容
    local currentContent = hs.pasteboard.getContents()

    -- 1. 如果剪贴板为空，则不处理
    if not currentContent then
        lastFocusedApp = currentAppName -- 更新最后焦点应用
        return
    end

    -- 2. 核心逻辑：如果从 Moonlight 切换出来，并且剪贴板内容是特定视频链接
    if lastFocusedApp == "Moonlight" and currentAppName ~= "Moonlight" then
        local server, path = currentContent:match("^\\\\(192%.168%.2%.9)\\(.+%.mp4)$") or currentContent:match("^\\\\(192%.168%.2%.9)\\(.+%.mkv)$")
        if server and path then
            log("从 Moonlight 切换到 " .. currentAppName .. "，剪贴板匹配视频路径。不执行打开操作。剪贴板内容: " .. currentContent)
            -- 更新 lastClipboardContent，因为这个内容已经被“识别”并决定不处理
            lastClipboardContent = currentContent 
            lastFocusedApp = currentAppName -- 更新最后焦点应用
            return -- 阻止打开链接
        end
    end

    -- 3. 如果当前应用是 Moonlight，则不进行后续的打开操作
    if currentAppName == "Moonlight" then
        log("当前应用是 Moonlight，不处理剪贴板。")
        -- 如果在 Moonlight 中，剪贴板内容变化了，需要更新 lastClipboardContent
        if currentContent ~= lastClipboardContent then
             lastClipboardContent = currentContent -- 更新，以便下次比较
        end
        lastFocusedApp = currentAppName
        return
    end

    -- 4. 如果剪贴板内容与上次内容相同（并且不是上面特殊处理的情况），则不处理
    if currentContent == lastClipboardContent then
        lastFocusedApp = currentAppName -- 更新最后焦点应用

    
    -- 更新上次剪贴板内容 (只有在确定要进行匹配检查时才更新)
    lastClipboardContent = currentContent
    
    -- 5. 检查是否是Windows网络路径或本地/Volumes路径并且是mp4或mkv文件
    local server, path = currentContent:match("^\\\\\\(192%.168%.2%.9)\\\\(.+%.mp4)$") or currentContent:match("^\\\\\\(192%.168%.2%.9)\\\\(.+%.mkv)$")
    local localPath = currentContent:match("^(/Volumes/.+%.mp4)$") or currentContent:match("^(/Volumes/.+%.mkv)$")
    
    if server and path then
        -- 构建新路径
        local newPath = "/Volumes/" .. path:gsub("\\", "/")
        
        -- 使用系统默认播放器打开视频
        hs.execute("open \"" .. newPath .. "\"")
        
        -- 清理剪贴板
        hs.pasteboard.clearContents()
        lastClipboardContent = "" -- 清理后，下次内容肯定不同（除非又复制了空）
        -- 记录日志
        log("正在使用系统默认播放器打开视频: " .. newPath)
        log("已清理剪贴板内容")
    elseif localPath then
        -- 直接打开本地/Volumes路径的视频
        hs.execute("open \"" .. localPath .. "\"")
        
        -- 清理剪贴板
        hs.pasteboard.clearContents()
        lastClipboardContent = ""
        -- 记录日志
        log("正在使用系统默认播放器打开本地视频: " .. localPath)
        log("已清理剪贴板内容")
    else
        log("剪贴板内容已更新，但不匹配视频路径: " .. currentContent)
    end

    -- 在函数的最后，更新 lastFocusedApp 为当前的应用
    lastFocusedApp = currentAppName
end

-- 添加文件结束标记

-- 创建一个定时器，定期检查剪贴板变化
-- 每0.5秒检查一次
local clipboardWatcher = hs.timer.new(0.5, handleClipboardChange)

-- 启动定时器
clipboardWatcher:start()

-- 添加一个热键来手动重启监听器
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "V", function()
    clipboardWatcher:stop()

    clipboardWatcher:start()
    log("剪贴板监听已重启")
    hs.notify.new({title="剪贴板监听", informativeText="监听器已重启"}):send()
end)

-- 确保脚本退出时清理资源
hs.shutdownCallback = function()
    clipboardWatcher:stop()
    log("剪贴板监听已停止")
end
end