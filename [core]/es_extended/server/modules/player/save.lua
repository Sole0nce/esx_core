-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local SAVE_QUERY <const> = "UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ? WHERE `identifier` = ?"
local SAVE_BATCH_SIZE <const> = 25
local SAVE_BATCH_INTERVAL <const> = 50

local function updateHealthAndArmorInMetadata(xPlayer)
    local ped = GetPlayerPed(xPlayer.source)
    xPlayer.setMeta("health", GetEntityHealth(ped))
    xPlayer.setMeta("armor", GetPedArmour(ped))
    xPlayer.setMeta("lastPlaytime", xPlayer.getPlayTime())
end

---@param xPlayer table
---@return table
local function buildSaveParameters(xPlayer)
    return {
        json.encode(xPlayer.getAccounts(true)),
        xPlayer.job.name,
        xPlayer.job.grade,
        xPlayer.group,
        json.encode(xPlayer.getCoords(false, true)),
        json.encode(xPlayer.getInventory(true)),
        json.encode(xPlayer.getLoadout(true)),
        json.encode(xPlayer.getMeta()),
        xPlayer.identifier,
    }
end

---@param xPlayer table
---@param cb? function
---@return nil
function Core.SavePlayer(xPlayer, cb)
    if not xPlayer.spawned then
        return cb and cb()
    end

    updateHealthAndArmorInMetadata(xPlayer)

    MySQL.prepare(
        SAVE_QUERY,
        buildSaveParameters(xPlayer),
        function(affectedRows)
            if affectedRows == 1 then
                print(('[^2INFO^7] Saved player ^5"%s^7"'):format(xPlayer.name))
                TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)
            end

            if cb then
                cb()
            end
        end
    )
end

---@param cb? function
---@return nil
function Core.SavePlayers(cb)
    local xPlayers <const> = ESX.Players or {}
    local players = {}

    for _, xPlayer in pairs(xPlayers) do
        if xPlayer.spawned then
            players[#players + 1] = xPlayer
        end
    end

    if #players == 0 then
        return cb and cb()
    end

    local startTime <const> = GetGameTimer()
    local savedCount = 0
    local totalCount = #players
    local done = false

    local function saveBatch(index)
        if done then
            return
        end

        local last = math.min(index + SAVE_BATCH_SIZE - 1, totalCount)
        local parameters = {}

        for i = index, last do
            local xPlayer = players[i]

            if ESX.Players[xPlayer.source] == xPlayer then
                updateHealthAndArmorInMetadata(xPlayer)
                parameters[#parameters + 1] = buildSaveParameters(xPlayer)
            end
        end

        local function onBatchSaved()
            savedCount = savedCount + #parameters

            if last < totalCount then
                SetTimeout(SAVE_BATCH_INTERVAL, function()
                    saveBatch(last + 1)
                end)
            else
                done = true

                if type(cb) == "function" then
                    return cb()
                end

                print(("[^2INFO^7] Saved ^5%s^7 %s over ^5%s^7 ms"):format(savedCount, savedCount > 1 and "players" or "player", GetGameTimer() - startTime))
            end
        end

        if #parameters == 0 then
            return onBatchSaved()
        end

        MySQL.prepare(SAVE_QUERY, parameters, onBatchSaved)
    end

    saveBatch(1)
end
