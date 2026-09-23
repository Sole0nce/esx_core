-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local registeredCallbacks = {}
local resource_name = GetCurrentResourceName() --TODO: Add cache
local IS_DEBUG <const> = GetConvar("xLib:debug", "false") == "true"

---@return integer
local function getValidationGrace()
    local grace = GetConvarInt("xLib:callbackValidationGrace", 15000)
    local timeout = tonumber(GetConvar("xLib:callbackTimeout", GetConvar("esx:callbackTimeout", "")))

    if timeout and timeout > 0 and timeout < math.huge and grace * 2 > timeout then
        return math.floor(timeout / 2)
    end

    return grace
end

local VALIDATION_GRACE_MS <const> = getValidationGrace()
local VALIDATION_WINDOW_MS <const> = GetConvarInt("xLib:callbackValidationWindow", 5000)
local VALIDATION_MAX_REQUESTS <const> = GetConvarInt("xLib:callbackValidationMaxRequests", 30)
local MAX_CALLBACK_NAME_LEN <const> = 200
local MAX_RESOURCE_NAME_LEN <const> = 100
local MAX_CALLBACK_KEY_LEN <const> = 300
local validationRequests = {}

local function consumeInvalidValidation()
    if not IsDuplicityVersion() or VALIDATION_MAX_REQUESTS <= 0 then
        return true
    end

    local key = tostring(source or 0)
    local now = GetGameTimer()
    local window = VALIDATION_WINDOW_MS > 0 and VALIDATION_WINDOW_MS or 5000
    local bucket = validationRequests[key]

    if not bucket or now - bucket.startedAt >= window then
        bucket = { startedAt = now, count = 0 }
        validationRequests[key] = bucket
    end

    bucket.count += 1

    return bucket.count <= VALIDATION_MAX_REQUESTS
end


AddEventHandler('onResourceStop', function(resourceName)
    if resource_name == resourceName then return end

    for callbackName, resource in pairs(registeredCallbacks) do
        if resource == resourceName then
            registeredCallbacks[callbackName] = nil
        end
    end
end)

---For internal use only.
---Sets a callback event as registered to a specific resource, preventing it from
---being overwritten. Any unknown callbacks will return an error to the caller.
---@param callbackName string
---@param isValid boolean
function xLib.setValidCallback(callbackName, isValid)
    local resourceName = GetInvokingResource() or resource_name
    local callbackResource = registeredCallbacks[callbackName]

    if not isValid then
        if callbackResource == resourceName then
            registeredCallbacks[callbackName] = nil
        end
        return
    end

    if callbackResource then
        if callbackResource == resourceName then return end

        if IS_DEBUG then
            local errMessage = ("^1resource '%s' attempted to overwrite callback '%s' owned by resource '%s'^0"):format(resourceName, callbackName, callbackResource)

            print(('^1SCRIPT ERROR: %s^0\n%s'):format(errMessage,
                Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString()) or ''))
        end

        return
    end

    if IS_DEBUG then
        print(("set valid callback '%s' for resource '%s'"):format(callbackName, resourceName))
    end

    registeredCallbacks[callbackName] = resourceName
end

function xLib.isCallbackValid(callbackName)
    return registeredCallbacks[callbackName] ~= nil
end

local cbEvent = '__xLib_cb_%s'

RegisterNetEvent('xLib:validateCallback', function(callbackName, invokingResource, key)
    if type(callbackName) ~= "string" or #callbackName > MAX_CALLBACK_NAME_LEN then return end
    if type(invokingResource) ~= "string" or #invokingResource > MAX_RESOURCE_NAME_LEN then return end
    if type(key) ~= "string" or #key > MAX_CALLBACK_KEY_LEN then return end

    if registeredCallbacks[callbackName] then return end
    if not consumeInvalidValidation() then return end

    local source = source

    local function rejectInvalidCallback()
        if registeredCallbacks[callbackName] then return end

        local event = cbEvent:format(invokingResource)

        if GetGameName() == 'fxserver' then
            return TriggerClientEvent(event, source, key, 'cb_invalid')
        end

        TriggerServerEvent(event, key, 'cb_invalid')
    end

    if VALIDATION_GRACE_MS > 0 then
        SetTimeout(VALIDATION_GRACE_MS, rejectInvalidCallback)
        return
    end

    rejectInvalidCallback()
end)

if IsDuplicityVersion() then
    AddEventHandler('playerDropped', function()
        validationRequests[tostring(source)] = nil
    end)
end
