-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function decodeSkin(value)
    if type(value) == "table" then
        return value
    end

    if type(value) ~= "string" or value == "" then
        return nil
    end

    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function applyBackpackWeight(playerId, identifier, skin)
    local esxConfig = ESX.GetConfig()

    if esxConfig.CustomInventory then
        return
    end

    local xPlayer = ESX.Player(playerId)

    if not xPlayer or xPlayer.getIdentifier() ~= identifier then
        return
    end

    local backpackModifier = type(skin) == "table" and Config.BackpackWeight[skin.bags_1] or nil

    xPlayer.setMaxWeight(esxConfig.MaxWeight + (backpackModifier or 0))
end

AddEventHandler("esx:playerLoaded", function(playerId)
    if type(source) == "number" or type(playerId) ~= "number" or ESX.GetConfig().CustomInventory then
        return
    end

    local xPlayer = ESX.Player(playerId)

    if not xPlayer then
        return
    end

    local identifier = xPlayer.getIdentifier()
    local storedSkin = MySQL.scalar.await("SELECT skin FROM users WHERE identifier = ?", { identifier })

    applyBackpackWeight(playerId, identifier, decodeSkin(storedSkin))
end)

RegisterNetEvent("esx_skin:save", function(skin)
    if not skin or type(skin) ~= "table" then
        return
    end

    local playerId = source
    local xPlayer = ESX.Player(playerId)

    if not xPlayer then
        return
    end

    local identifier = xPlayer.getIdentifier()
    local encodedSkin = json.encode(skin)

    MySQL.update("UPDATE users SET skin = @skin WHERE identifier = @identifier", {
        ["@skin"] = encodedSkin,
        ["@identifier"] = identifier,
    }, function(affectedRows)
        if affectedRows and affectedRows > 0 then
            applyBackpackWeight(playerId, identifier, decodeSkin(encodedSkin))
        end
    end)
end)

RegisterNetEvent("esx_skin:setWeight", function() end)

xLib.callback.registerCompat("esx_skin:getPlayerSkin", function(source, cb)
    local xPlayer = ESX.Player(source)

    if not xPlayer then
        return cb(nil, nil)
    end

    MySQL.query("SELECT skin FROM users WHERE identifier = @identifier", {
        ["@identifier"] = xPlayer.getIdentifier(),
    }, function(users)
        local user, skin = users and users[1], nil

        local jobSkin = {
            skin_male = xPlayer.getJob().skin_male,
            skin_female = xPlayer.getJob().skin_female,
        }

        skin = user and decodeSkin(user.skin) or nil

        cb(skin, jobSkin)
    end)
end)

ESX.RegisterCommand("skin", "admin", function(xPlayer, args)
    if not args.playerId then
        args.playerId = xPlayer
    end
    args.playerId.triggerEvent("esx_skin:openSaveableMenu")
end, false, { help = TranslateCap("skin"), arguments = { { name = "playerId", help = TranslateCap("skin"), type = "player" }} })
