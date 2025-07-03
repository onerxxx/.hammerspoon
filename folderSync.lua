-- 定义源文件夹和目标文件夹的路径
local sourceDir = "/Volumes/850Pro_256G/My html"
local targetDir = "/Volumes/Seagate_6T/备份/My html"

-- 定义同步函数
function syncFolders()
  -- 使用 rsync 命令来同步文件夹
  -- -a: 归档模式，保留权限等信息
  -- -v: 显示详细信息
  -- --delete: 删除目标文件夹中源文件夹没有的文件
  local command = string.format("rsync -av --delete '%s/' '%s/'", sourceDir, targetDir)
  
  -- 执行命令
  hs.execute(command)
  
  -- 可选：显示通知
  hs.notify.new({title="Folder Sync", informativeText="同步完成"}):send()
end

-- 创建一个定时器，每两个小时执行一次同步
syncTimer = hs.timer.new(7200, syncFolders)
syncTimer:start()

-- 可选：启动 Hammerspoon 时立即执行一次同步
syncFolders()

