-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function Core.PlayerSession.OnPlayerJoined(playerId)
    local identifier = Core.PlayerSession.GetPlayerIdentifier(playerId)

    if not identifier then
        return DropPlayer(playerId, "there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.")
    end

    if ESX.GetPlayerFromIdentifier(identifier) then
        return DropPlayer(
            playerId,
            ("there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s"):format(identifier)
        )
    end

    local result = MySQL.scalar.await("SELECT 1 FROM users WHERE identifier = ?", { identifier })

    if result then
        loadESXPlayer(identifier, playerId, false)
    else
        Core.PlayerSession.CreateESXPlayer(identifier, playerId)
    end
end

if Config.Multichar then
    AddEventHandler("esx:onPlayerJoined", function(src, char, data)
        Core.PlayerSession.WaitForJobs()

        if not ESX.Players[src] then
            local identifier = ("%s:%s"):format(char, ESX.GetIdentifier(src))
            if data then
                Core.PlayerSession.CreateESXPlayer(identifier, src, data)
            else
                loadESXPlayer(identifier, src, false)
            end
        end
    end)
else
    local joiningPlayers = {}

    RegisterNetEvent("esx:onPlayerJoined", function()
        local playerId = source

        if joiningPlayers[playerId] or ESX.Players[playerId] then
            return
        end

        joiningPlayers[playerId] = true
        Core.PlayerSession.WaitForJobs()

        local ok, err = true, nil
        if not ESX.Players[playerId] then
            ok, err = pcall(Core.PlayerSession.OnPlayerJoined, playerId)
        end

        joiningPlayers[playerId] = nil

        if not ok then
            error(err)
        end
    end)

    AddEventHandler("playerDropped", function()
        joiningPlayers[source] = nil
    end)
end

if not Config.Multichar then
    AddEventHandler("playerConnecting", function(_, _, deferrals)
        local playerId = source

        deferrals.defer()
        Wait(0)

        local identifier = Core.PlayerSession.GetPlayerIdentifier(playerId)

        -- luacheck: ignore
        if not SetEntityOrphanMode then
            return deferrals.done("[ESX] ESX Requires a minimum Artifact version of 10188, Please update your server.")
        end

        if not Core.PlayerSession.isEnhanced and (Core.PlayerSession.oneSyncState == "off" or Core.PlayerSession.oneSyncState == "legacy") then
            return deferrals.done(("[ESX] ESX Requires Onesync Infinity to work. This server currently has Onesync set to: %s"):format(Core.PlayerSession.oneSyncState))
        end

        if not Core.DatabaseConnected then
            return deferrals.done("[ESX] OxMySQL Was Unable To Connect to your database. Please make sure it is turned on and correctly configured in your server.cfg")
        end

        if not identifier and GetResourceState("esx_identity") ~= "started" then
            return deferrals.done("[ESX] There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.")
        end

        local xPlayer = identifier and ESX.GetPlayerFromIdentifier(identifier)

        if not xPlayer then
            return deferrals.done()
        end

        if GetPlayerPing(xPlayer.source --[[@as string]]) > 0 then
            return deferrals.done(
                ("[ESX] There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same account.\n\nYour identifier: %s"):format(identifier)
            )
        end

        deferrals.update("[ESX] Cleaning stale player entry...")
        Core.PlayerSession.OnPlayerDropped(xPlayer.source, "esx_stale_player_obj")
        deferrals.done()
    end)
end
