-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("VehicleProperties", nil, function(bagName, _, value)
    if type(value) ~= "table" or not bagName:find("^entity:") then
        return
    end

    bagName = bagName:gsub("entity:", "")
    local netId = tonumber(bagName)
    if not netId then
        error("Tried to set vehicle properties with invalid netId")
        return
    end

    local tries = 0

    while not NetworkDoesEntityExistWithNetworkId(netId) do
        Wait(200)
        tries += 1
        if tries > 20 then
            return error(("Invalid entity - ^5%s^7!"):format(netId))
        end
    end

    local vehicle = NetToVeh(netId)

    if NetworkGetEntityOwner(vehicle) ~= ESX.playerId then
        return
    end

    xLib.game.setVehicleProperties(vehicle, value)
end)

xLib.callback.registerCompat("esx:GetVehicleType", function(cb, model)
    cb(ESX.GetVehicleTypeClient(model))
end)
