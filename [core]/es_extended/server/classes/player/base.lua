-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Core.PlayerClass = Core.PlayerClass or {}

function Core.PlayerClass.AttachBase(self)
    function self.triggerEvent(eventName, ...)
        assert(type(eventName) == "string", "eventName should be string!")
        TriggerClientEvent(eventName, self.source, ...)
    end

    function self.togglePaycheck(toggle)
        self.paycheckEnabled = toggle
    end

    function self.isPaycheckEnabled()
        return self.paycheckEnabled
    end

    function self.isAdmin()
        return Core.IsPlayerAdmin(self.source)
    end

    function self.setCoords(coordinates)
        local ped <const> = GetPlayerPed(self.source)

        SetEntityCoords(ped, coordinates.x, coordinates.y, coordinates.z, false, false, false, false)
        SetEntityHeading(ped, coordinates.w or coordinates.heading or 0.0)
    end

    function self.getCoords(vector, heading)
        local ped <const> = GetPlayerPed(self.source)
        local entityCoords <const> = GetEntityCoords(ped)
        local entityHeading <const> = GetEntityHeading(ped)

        local coordinates = { x = entityCoords.x, y = entityCoords.y, z = entityCoords.z }

        if vector then
            coordinates = (heading and vector4(entityCoords.x, entityCoords.y, entityCoords.z, entityHeading) or entityCoords)
        else
            if heading then
                coordinates.heading = entityHeading
            end
        end

        return coordinates
    end

    function self.kick(reason)
        DropPlayer(self.source --[[@as string]], reason)
    end

    function self.getPlayTime()
        -- luacheck: ignore
        return self.lastPlaytime + GetPlayerTimeOnline(self.source --[[@as string]])
    end


    function self.getIdentifier()
        return self.identifier
    end

    function self.getSSN()
        return self.ssn
    end

    function self.setGroup(newGroup)
        local lastGroup = self.group

        ExecuteCommand(("remove_principal identifier.%s group.%s"):format(self.license, self.group))

        self.group = newGroup

        TriggerEvent("esx:setGroup", self.source, self.group, lastGroup)
        self.triggerEvent("esx:setGroup", self.group, lastGroup)
        Player(self.source).state:set("group", self.group, true)

        ExecuteCommand(("add_principal identifier.%s group.%s"):format(self.license, self.group))
    end

    function self.getGroup()
        return self.group
    end

    function self.set(k, v)
        self.variables[k] = v

        self.triggerEvent('esx:updatePlayerData', 'variables', self.variables)
    end

    function self.get(k)
        return self.variables[k]
    end


    function self.getName()
        return self.name
    end

    function self.setName(newName)
        self.name = newName
        Player(self.source).state:set("name", self.name, true)
    end


    function self.getSource()
        return self.source
    end
    self.getPlayerId = self.getSource

    function self.executeCommand(command)
        if type(command) ~= "string" then
            error("xPlayer.executeCommand must be of type string!")
            return
        end

        self.triggerEvent("esx:executeCommand", command)
    end

end
