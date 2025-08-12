-- 测试改进后的虚拟按键功能
print("=== 🧪 测试改进后的虚拟按键功能 ===")

-- 加载虚拟按键模块
local success, virtualKeys = pcall(function()
    return require("virtual_keys")
end)

if not success then
    print("❌ 无法加载虚拟按键模块: " .. tostring(virtualKeys))
    return
end

print("✅ 虚拟按键模块加载成功")

-- 测试基本功能
print("\n🔍 测试基本功能:")
print("- 运行状态: " .. (virtualKeys.isRunning() and "✅ 运行中" or "❌ 已停止"))

-- 测试新增的诊断功能
print("\n🔐 测试权限诊断:")
local permissionOK = virtualKeys.diagnosePemissions()
print("- 权限检查结果: " .. (permissionOK and "✅ 正常" or "❌ 有问题"))

-- 测试Moonlight检测
print("\n🎮 测试Moonlight检测:")
local moonlightDetected = virtualKeys.testMoonlightDetection()
print("- Moonlight检测结果: " .. (moonlightDetected and "✅ 检测到" or "❌ 未检测到"))

-- 显示快捷键帮助
print("\n📋 显示快捷键帮助:")
virtualKeys.showHelp()

print("\n=== 🎉 测试完成 ===")
print("现在你可以:")
print("1. 按 Cmd+Shift+D 测试Moonlight应用检测")
print("2. 按 Cmd+Shift+Ctrl+P 诊断系统权限")
print("3. 按 Cmd+Shift+Ctrl+T 在Moonlight中测试按键映射")
print("4. 按 Cmd+Shift+Ctrl+H 显示所有快捷键帮助")