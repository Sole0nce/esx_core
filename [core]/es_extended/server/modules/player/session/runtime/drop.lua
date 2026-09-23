-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function Core.PlayerSession.OnPlayerDropped(playerId, reason, cb)
    local p = not cb and promise:new()
    local function resolve()
        if cb then
            return cb()
        elseif p then
            return p:resolve()
        end
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        return resolve()
    end

    TriggerEvent("esx:playerDropped", playerId, reason)
    Core.PlayerSession.DecrementJobCount(xPlayer.getJob().name)

    Core.SavePlayer(xPlayer, function()
        GlobalState["playerCount"] = math.max((GlobalState["playerCount"] or 1) - 1, 0)
        ESX.Players[playerId] = nil
        Core.playersByIdentifier[xPlayer.identifier] = nil

        resolve()
    end)

    if p then
        return Citizen.Await(p)
    end
end

AddEventHandler("esx:onPlayerDropped", Core.PlayerSession.OnPlayerDropped)
