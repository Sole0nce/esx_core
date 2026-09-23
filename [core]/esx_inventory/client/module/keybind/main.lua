-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Inventory = ESXInventory

xLib.addKeybind({
    name = "showinv",
    description = TranslateCap("keymap_showinventory"),
    defaultMapper = "keyboard",
    defaultKey = "F2",
    onPressed = function()
        if Inventory.isOpen then
            Inventory.close(false)
        else
            Inventory.open()
        end
    end,
})

for i = 1, Config.HotbarSlots do
    xLib.addKeybind({
        name = ("hotbar%s"):format(i),
        description = TranslateCap("keymap_hotbar", i),
        defaultMapper = "keyboard",
        defaultKey = "",
        onPressed = function()
            if Inventory.isOpen or not ESX.PlayerLoaded or ESX.PlayerData.dead then
                return
            end

            local targetSlot = i - 1

            for j = 1, #(ESX.PlayerData.inventory or {}) do
                local item = ESX.PlayerData.inventory[j]

                if item.count > 0 and item.usable and Inventory.getSlot(Inventory.itemKey("item_standard", item.name)) == targetSlot then
                    TriggerServerEvent("esx:useItem", item.name)
                    return
                end
            end
        end,
    })
end
