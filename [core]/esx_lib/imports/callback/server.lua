-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local pendingCallbacks = {}
local registeredCallbackNames = {}
local compatCallbacks = {}
local cbEvent = '__xLib_cb_%s'
local DEFAULT_AWAIT_TIMEOUT <const> = 300000
local resource_name = GetCurrentResourceName() --TODO: Add cache

---@return integer|nil
local function getConfiguredTimeout()
    local value = tonumber(GetConvar('xLib:callbackTimeout', GetConvar('esx:callbackTimeout', '')))

    if value and value < math.huge then
        return math.max(math.floor(value), 0)
    end
end

local configuredTimeout = getConfiguredTimeout()
local awaitTimeout = configuredTimeout or DEFAULT_AWAIT_TIMEOUT

if configuredTimeout then
    SetConvarReplicated('esx:callbackTimeout', tostring(configuredTimeout))
    SetConvarReplicated('xLib:callbackTimeout', tostring(configuredTimeout))
end

local function createCallbackKey(event, playerId)
    local key

    repeat
        key = ('%s:%s:%s:%s'):format(event, playerId, GetGameTimer(), xLib.string.randomHex(32))
    until not pendingCallbacks[key]

    return key
end

local function expirePendingCallback(key, err)
    local pending = pendingCallbacks[key]

    if not pending then
        return
    end

    pendingCallbacks[key] = nil
    pending.expire(err)
end

local function clearPendingForSource(playerId)
    playerId = tostring(playerId)

    for key, pending in pairs(pendingCallbacks) do
        if pending.source == playerId then
            expirePendingCallback(key, ("callback event '%s' was cancelled because player %s disconnected"):format(key, playerId))
        end
    end
end

local function publishValidCallback(name)
    local ok = pcall(function()
        xLib.setValidCallback(name, true)
    end)

    if not ok then
        SetTimeout(1000, function()
            if registeredCallbackNames[name] then
                publishValidCallback(name)
            end
        end)
    end
end

local function republishValidCallbacks()
    for name in pairs(registeredCallbackNames) do
        publishValidCallback(name)
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource == 'esx_lib' then
        SetTimeout(0, republishValidCallbacks)
    end
end)

-- Compat callbacks (via ESX.Register*) belong to another resource while their
-- handlers live here, so they must be removed manually when that resource stops.
AddEventHandler('onResourceStop', function(resource)
    for name, registration in pairs(compatCallbacks) do
        if registration.owner == resource then
            RemoveEventHandler(registration.handler)

            compatCallbacks[name] = nil
            registeredCallbackNames[name] = nil

            if GetResourceState('esx_lib') == 'started' then
                xLib.setValidCallback(name, false)
            end
        end
    end
end)

RegisterNetEvent(cbEvent:format(resource_name), function(key, ...)
    local pending = pendingCallbacks[key]

    if not pending then return end

    if pending.source ~= tostring(source) then
        return
    end

    pendingCallbacks[key] = nil

    pending.cb(...)
end)

AddEventHandler('playerDropped', function()
    clearPendingForSource(source)
end)

---@param _ any
---@param event string
---@param playerId number
---@param cb function|false
---@param ... any
---@return ...
local function triggerClientCallback(_, event, playerId, cb, ...)
    xLib.verify(playerId, 'playerId', true)

    local key = createCallbackKey(event, playerId)

    ---@type promise | false
    local promise = not cb and promise.new()

    pendingCallbacks[key] = {
        source = tostring(playerId),
        cb = function(response, ...)
            if response == 'cb_invalid' then
                response = ("callback '%s' does not exist"):format(event)

                return promise and promise:reject(response) or error(response)
            end

            response = { response, ... }

            if promise then
                return promise:resolve(response)
            end

            if cb then
                cb(table.unpack(response))
            end
        end,
        expire = function(err)
            if promise then
                promise:reject(err)
            elseif cb then
                warn(err)
            end
        end
    }

    local timeout = promise and awaitTimeout or configuredTimeout

    if timeout and timeout > 0 then
        SetTimeout(timeout, function()
            expirePendingCallback(key, ("callback event '%s' timed out"):format(key))
        end)
    end

    TriggerClientEvent('xLib:validateCallback', playerId, event, resource_name, key)
    TriggerClientEvent(cbEvent:format(event), playerId, resource_name, key, ...)

    if promise then
        return table.unpack(Citizen.Await(promise))
    end
end

---@overload fun(event: string, playerId: number, cb: function, ...)
xLib.callback = setmetatable({}, {
    __call = function(_, event, playerId, cb, ...)
        if not cb then
            warn(("callback event '%s' does not have a function to callback to and will instead await\nuse xLib.callback.await or a regular event to remove this warning")
                :format(event))
        else
            local cbType = type(cb)

            if cbType == 'table' and getmetatable(cb)?.__call then
                cbType = 'function'
            end

            xLib.verify(cb, 'function', true)
        end

        return triggerClientCallback(_, event, playerId, cb, ...)
    end
})

---@param event string
---@param playerId number
--- Sends an event to a client and halts the current thread until a response is returned.
---@diagnostic disable-next-line: duplicate-set-field
function xLib.callback.await(event, playerId, ...)
    return triggerClientCallback(nil, event, playerId, false, ...)
end

local function callbackResponse(success, result, ...)
    if not success then
        if result then
            return print(('^1SCRIPT ERROR: %s^0\n%s'):format(result,
                Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString()) or ''))
        end

        return false
    end

    return result, ...
end

local pcall = pcall

---@param name string
---@param cb function
---Registers an event handler and callback function to respond to client requests.
---The handler is owned by the importing resource's runtime, so FiveM removes
---it automatically when that resource stops.
---@diagnostic disable-next-line: duplicate-set-field
function xLib.callback.register(name, cb)
    local event = cbEvent:format(name)

    registeredCallbackNames[name] = true
    publishValidCallback(name)

    RegisterNetEvent(event, function(resource, key, ...)
        TriggerClientEvent(cbEvent:format(resource), source, key, callbackResponse(pcall(cb, source, ...)))
    end)
end

---@param name string
---@param cb function
---@param owner? string Resource whose lifetime owns the callback.
---Registers a callback using the old ESX server callback signature: function(source, cb, ...).
---The handler is created here so it can be removed when the owner resource stops.
function xLib.callback.registerCompat(name, cb, owner)
    local event = cbEvent:format(name)

    local function compatCb(source, ...)
        local response = promise.new()
        local responded = false

        local function reply(...)
            local values = { ... }

            if not responded then
                responded = true
                response:resolve(values)
            end

            return table.unpack(values)
        end

        if configuredTimeout and configuredTimeout > 0 then
            SetTimeout(configuredTimeout, function()
                if not responded then
                    responded = true
                    response:reject(("compat callback '%s' timed out"):format(name))
                end
            end)
        end

        cb(source, reply, ...)

        return table.unpack(Citizen.Await(response))
    end

    local previous = compatCallbacks[name]
    if previous then
        RemoveEventHandler(previous.handler)
    end

    RegisterNetEvent(event)
    local handler = AddEventHandler(event, function(resource, key, ...)
        TriggerClientEvent(cbEvent:format(resource), source, key, callbackResponse(pcall(compatCb, source, ...)))
    end)

    registeredCallbackNames[name] = true
    compatCallbacks[name] = {
        owner = owner or resource_name,
        handler = handler
    }
    publishValidCallback(name)
end

return xLib.callback
