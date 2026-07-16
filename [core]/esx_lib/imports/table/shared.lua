---@class tablelib
xLib.table = table

---@param tbl table
---@return boolean
function xLib.table.isArray(tbl)
    xLib.verify(tbl, "table", true)

    local count, maxIndex = 0, 0

    for k, _ in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            return false
        end

        count, maxIndex = count + 1, math.max(maxIndex, k)

        if count > maxIndex then
            return false
        end
    end

    return true
end

---@param tbl table
---@param item any
---@return any
function xLib.table.searchForKey(tbl, item)
    xLib.verify(tbl, "table", true)

    for k, v in pairs(tbl) do
        if v == item then
            return k
        end
    end

    return nil
end

---@param tbl table
---@param item any
---@return boolean
function xLib.table.contains(tbl, item)
    return xLib.table.searchForKey(tbl, item) ~= nil
end

---@param tbl table
---@param filter fun(value:any, key:any):boolean
---@return table
function xLib.table.filter(tbl, filter)
    xLib.verify(tbl, "table", true)
    xLib.verify(filter, "function", true)

    local result = {}

    for k, v in pairs(tbl) do
        if filter(v, k) then
            result[k] = v
        end
    end

    return result
end

---@param tbl table
---@param copies? table
---@return table
function xLib.table.deepcopy(tbl, copies)
    xLib.verify(tbl, "table", true)

    copies = copies or {}

    if copies[tbl] then
        return copies[tbl]
    end

    local copy = {}
    copies[tbl] = copy

    for k, v in pairs(tbl) do
        copy[k] = type(v) == "table" and xLib.table.deepcopy(v, copies) or v

        if type(v) == "table" and getmetatable(v) then
            setmetatable(copy[k], getmetatable(v))
        end
    end

    return copy
end

--- https://github.com/overextended/ox_lib/blob/master/imports/table/shared.lua
---@param t1 table
---@param t2 table
---@param addDuplicateNumbers boolean
---@return table
function xLib.table.merge(t1, t2, addDuplicateNumbers)
    xLib.verify(t1, "table", true)
    xLib.verify(t2, "table", true)
    xLib.verify(addDuplicateNumbers, "boolean", true)

    addDuplicateNumbers = addDuplicateNumbers == nil or addDuplicateNumbers
    for k, v2 in pairs(t2) do
        local v1 = t1[k]
        local type1 = type(v1)
        local type2 = type(v2)

        if type1 == 'table' and type2 == 'table' then
            xLib.table.merge(v1, v2, addDuplicateNumbers)
        elseif addDuplicateNumbers and (type1 == 'number' and type2 == 'number') then
            t1[k] = v1 + v2
        else
            t1[k] = v2
        end
    end

    return t1
end

function xLib.table.dump(tbl)
    if xLib.verify(tbl, 'table') then
        local s = '{ '
        for k,v in pairs(tbl) do
           if type(k) ~= 'number' then k = '"'..k..'"' end
           s = s .. '['..k..'] = ' .. tbl(v) .. ','
        end
        return s .. '} '
     else
        return tostring(tbl)
     end
end

return xLib.table
