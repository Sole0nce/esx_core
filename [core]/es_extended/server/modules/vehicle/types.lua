-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local KVP_KEY <const> = "esx_vehicleTypes"
local KVP_VERSION <const> = 2
local CONFIRMATIONS_REQUIRED <const> = 2

local validTypes <const> = {
    automobile = true,
    bike = true,
    boat = true,
    heli = true,
    plane = true,
    submarine = true,
    trailer = true,
    train = true,
}

local storedTypes = {}
local reports = {}
local askedPlayers = {}
local persistQueued = false

local function persistVehicleTypes()
    if persistQueued then
        return
    end

    persistQueued = true

    SetTimeout(1000, function()
        persistQueued = false

        if not next(storedTypes) then
            return DeleteResourceKvp(KVP_KEY)
        end

        SetResourceKvp(KVP_KEY, json.encode({ version = KVP_VERSION, types = storedTypes }))
    end)
end

local function getReporterKey(playerId)
    return GetPlayerIdentifierByType(tostring(playerId), "license") or ("source:%s"):format(playerId)
end

local function countVotes(modelReports, vehicleType)
    local votes = 0

    for _, reportedType in pairs(modelReports) do
        if reportedType == vehicleType then
            votes = votes + 1
        end
    end

    return votes
end

local function askPlayer(model, playerId, cb)
    local asked = askedPlayers[model] or {}
    askedPlayers[model] = asked
    asked[getReporterKey(playerId)] = true

    xLib.callback("esx:GetVehicleType", playerId, function(vehicleType)
        Core.CacheVehicleType(model, vehicleType, playerId)

        if cb then
            cb(validTypes[vehicleType] and vehicleType or false)
        end
    end, model)
end

local function requestConfirmation(model)
    local asked = askedPlayers[model] or {}

    for playerId in pairs(ESX.Players) do
        if not asked[getReporterKey(playerId)] then
            return askPlayer(model, playerId)
        end
    end
end

---@param model string|number
---@param vehicleType string|false|nil
---@param playerId? number
---@return nil
function Core.CacheVehicleType(model, vehicleType, playerId)
    model = type(model) == "string" and joaat(model) or model

    if type(model) ~= "number" then
        return
    end

    if not validTypes[vehicleType] then
        if playerId and reports[model] then
            requestConfirmation(model)
        end

        return
    end

    local key = tostring(model)

    if storedTypes[key] then
        return
    end

    local modelReports = reports[model] or {}
    reports[model] = modelReports

    if playerId then
        modelReports[getReporterKey(playerId)] = vehicleType
    end

    local votes = countVotes(modelReports, vehicleType)

    if votes >= CONFIRMATIONS_REQUIRED then
        storedTypes[key] = vehicleType
        reports[model] = nil
        askedPlayers[model] = nil
        Core.vehicleTypesByModel[model] = vehicleType

        return persistVehicleTypes()
    end

    local current = Core.vehicleTypesByModel[model]

    if not current or votes > countVotes(modelReports, current) then
        Core.vehicleTypesByModel[model] = vehicleType
    end

    if playerId then
        requestConfirmation(model)
    end
end

local function restoreVehicleTypes()
    local stored = GetResourceKvpString(KVP_KEY)

    if not stored then
        return
    end

    local ok, decoded = pcall(json.decode, stored)

    if not ok or type(decoded) ~= "table" or decoded.version ~= KVP_VERSION or type(decoded.types) ~= "table" then
        return DeleteResourceKvp(KVP_KEY)
    end

    for model, vehicleType in pairs(decoded.types) do
        model = tonumber(model)

        if model and validTypes[vehicleType] then
            Core.vehicleTypesByModel[model] = vehicleType
            storedTypes[tostring(model)] = vehicleType
        end
    end
end

---@param model string|number
---@param player? number
---@param cb function?
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function ESX.GetVehicleType(model, player, cb)
    if ESX.IsFunctionReference(player) and cb == nil then
        cb = player
        player = nil
    elseif cb == false then
        cb = nil
    elseif cb and not ESX.IsFunctionReference(cb) then
        cb = nil
    end

    local promise = not cb and promise.new()
    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end

        return result
    end

    model = type(model) == "string" and joaat(model) or model

    if Core.vehicleTypesByModel[model] then
        if player and reports[model] then
            local asked = askedPlayers[model]

            if not (asked and asked[getReporterKey(player)]) then
                askPlayer(model, player)
            end
        end

        return resolve(Core.vehicleTypesByModel[model])
    end

    if not player then
        return resolve(nil)
    end

    askPlayer(model, player, resolve)

    if promise then
        return Citizen.Await(promise)
    end
end

RegisterCommand("clearvehicletypes", function(src)
    if src ~= 0 then
        print("^1[ERROR]^7 This command can only be run from the server console.")
        return
    end

    storedTypes = {}
    reports = {}
    askedPlayers = {}
    Core.vehicleTypesByModel = {}
    DeleteResourceKvp(KVP_KEY)

    print("^2[SUCCESS]^7 Cleared the vehicle type cache.")
end, true)

restoreVehicleTypes()
