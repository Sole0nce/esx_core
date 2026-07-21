Locales = {}

--- English fallback for missing keys. locale.lua runs in every resource VM, so
--- a resource may opt out through its own Config.LocaleFallback; otherwise the
--- shared "esx:localeFallback" convar decides (enabled by default).
local function localeFallbackEnabled()
    if Config.LocaleFallback ~= nil then
        return Config.LocaleFallback
    end

    return GetConvar("esx:localeFallback", "true") ~= "false"
end

--- Lazily load and cache a locale file, false if it cannot be read
local function loadLocale(locale)
    if Locales[locale] == nil then
        local success, result = pcall(function()
            return assert(load(LoadResourceFile(GetCurrentResourceName(), ("locales/%s.lua"):format(locale))))()
        end)

        Locales[locale] = success and result or false
    end

    return Locales[locale]
end

function Translate(str, ...) -- Translate string
    if not str then
        error(("Resource ^5%s^1 You did not specify a parameter for the Translate function or the value is nil!"):format(GetInvokingResource() or GetCurrentResourceName()))
    end

    local translations = loadLocale(Config.Locale)
    if not translations then
        if Config.Locale == "en" then
            return "Locale [en] does not exist"
        end

        -- Fall back to English translation if the current locale is not found
        Config.Locale = "en"
        return Translate(str, ...)
    end

    if translations[str] then
        return translations[str]:format(...)
    end

    -- The locale exists but is missing this key: borrow the English string
    -- rather than surfacing a placeholder.
    if Config.Locale ~= "en" and localeFallbackEnabled() then
        local english = loadLocale("en")
        if english and english[str] then
            return english[str]:format(...)
        end
    end

    return ("Translation [%s][%s] does not exist"):format(Config.Locale, str)
end

function TranslateCap(str, ...) -- Translate string first char uppercase
    return _(str, ...):gsub("^%l", string.upper)
end

_ = Translate
-- luacheck: ignore _U
_U = TranslateCap