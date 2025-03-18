-- 监听剪贴板并使用系统默认播放器打开网络视频文件

-- 保存上一次的剪贴板内容，避免重复处理
local lastClipboardContent = ""

-- 创建一个日志函数，方便调试
local function log(message)
    print(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message)
end

-- 初始化提示
log("剪贴板监听已启动，将自动检测网络视频文件路径并使用系统默认播放器打开")

-- 处理剪贴板内容的函数
local function handleClipboardChange()
    -- 获取当前剪贴板内容
    local currentContent = hs.pasteboard.getContents()
    
    -- 如果剪贴板为空或与上次内容相同，则不处理
    if not currentContent or currentContent == lastClipboardContent then
        return
    end
    
    -- 更新上次剪贴板内容
    lastClipboardContent = currentContent
    
    -- 检查是否是Windows网络路径并且是mp4文件
    local server, path = currentContent:match("^\\\\(192%.168%.2%.9)\\(.+%.mp4)$")
    
    if server and path then
        -- 构建新路径
        local newPath = "/Volumes/" .. path:gsub("\\", "/")
        
        -- 使用系统默认播放器打开视频
        hs.execute("open \"" .. newPath .. "\"")
        
        -- 清理剪贴板
        hs.pasteboard.clearContents()
        lastClipboardContent = ""
        currentContent = ""
        -- 记录日志
        log("正在使用系统默认播放器打开视频: " .. newPath)
        log("已清理剪贴板内容")
    end
end

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