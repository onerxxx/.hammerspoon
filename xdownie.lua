-- 监听剪贴板并使用Downie 4下载Twitter、微博和抖音视频链接

-- 定义链接前缀
local twitterPrefix = "https://x.com/i/status/"
local weiboPrefix = "https://video.weibo.com/"
local douyinPrefix = "https://v.douyin.com/"
local sinaShortPrefix = "http://t.cn/"

-- 创建一个日志函数，方便调试
local function log(message)
    print(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message)
end

-- 初始化提示
log("剪贴板监听已启动，将自动检测Twitter、微博、抖音视频和新浪短链接并使用Downie 4下载")

-- 保存上一次的剪贴板内容，避免重复处理
local lastClipboardContent = ""

-- 从文本中提取链接的函数
local function extractLink(text, prefix)
    -- 使用模式匹配查找以指定前缀开头的链接
    -- 匹配前缀后跟随非空白字符，直到遇到空白字符或字符串结束
    local pattern = prefix .. "[^%s]+"
    return string.match(text, pattern)
end

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
    
    -- 尝试从剪贴板内容中提取各种链接
    local twitterLink = extractLink(currentContent, twitterPrefix)
    local weiboLink = extractLink(currentContent, weiboPrefix)
    local douyinLink = extractLink(currentContent, douyinPrefix)
    local sinaShortLink = extractLink(currentContent, sinaShortPrefix)
    
    -- 确定要处理的链接和类型
    local linkToProcess = nil
    local linkType = nil
    
    if twitterLink then
        linkToProcess = twitterLink
        linkType = "Twitter"
    elseif weiboLink then
        linkToProcess = weiboLink
        linkType = "微博视频"
    elseif douyinLink then
        linkToProcess = douyinLink
        linkType = "抖音视频"
    elseif sinaShortLink then
        linkToProcess = sinaShortLink
        linkType = "新浪短链接"
    end
    
    -- 如果找到了支持的链接，则处理它
    if linkToProcess then
        log("检测到" .. linkType .. "链接: " .. linkToProcess)
        
        -- 使用Downie 4下载链接
        local task = hs.task.new("/usr/bin/open", nil, {"-a", "Downie 4", linkToProcess})
        local success = task:start()
        
        if success then
            log("已发送到Downie 4进行下载")
            -- 显示通知
            hs.notify.new({title=linkType .. "链接已发送到Downie 4", informativeText=linkToProcess}):send()
        else
            log("发送到Downie失败")
            hs.notify.new({title="错误", informativeText="无法发送链接到Downie 4"}):send()
        end
    end
end

-- 创建一个定时器，定期检查剪贴板变化
-- 每0.5秒检查一次
local clipboardWatcher = hs.timer.new(0.5, handleClipboardChange)

-- 启动定时器
clipboardWatcher:start()

-- 添加一个热键来手动重启监听器
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    clipboardWatcher:stop()
    lastClipboardContent = ""
    clipboardWatcher:start()
    log("剪贴板监听已重启")
    hs.notify.new({title="剪贴板监听", informativeText="监听器已重启"}):send()
end)

-- 确保脚本退出时清理资源
hs.shutdownCallback = function()
    clipboardWatcher:stop()
    log("剪贴板监听已停止")
end