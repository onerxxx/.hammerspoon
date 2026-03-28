local M = {}

local callbacks = {}
local callbackIndex = {}
local previousShutdownCallback = nil

local function runCallbacks()
    for _, entry in ipairs(callbacks) do
        local ok, err = pcall(entry.fn)
        if not ok then
            print(string.format("shutdown callback failed [%s]: %s", entry.name, err))
        end
    end

    if previousShutdownCallback and previousShutdownCallback ~= runCallbacks then
        local ok, err = pcall(previousShutdownCallback)
        if not ok then
            print(string.format("previous shutdown callback failed: %s", err))
        end
    end
end

local function ensureInstalled()
    if hs.shutdownCallback ~= runCallbacks then
        if hs.shutdownCallback and hs.shutdownCallback ~= runCallbacks then
            previousShutdownCallback = hs.shutdownCallback
        end
        hs.shutdownCallback = runCallbacks
    end
end

function M.register(name, fn)
    if type(fn) ~= "function" then
        error("shutdown callback must be a function")
    end

    local entry = { name = name, fn = fn }
    local index = callbackIndex[name]

    if index then
        callbacks[index] = entry
    else
        table.insert(callbacks, entry)
        callbackIndex[name] = #callbacks
    end

    ensureInstalled()
    return fn
end

return M
