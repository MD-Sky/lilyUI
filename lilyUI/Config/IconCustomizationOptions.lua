local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

local function CreateIconCustomizationOptions()
    return {
        type = "group",
        name = "Icon Customization",
        order = 5,
        args = {
            header = {
                type = "header",
                name = "Icon Customization",
                order = 1,
            },
            description = {
                type = "description",
                name = "Customize individual spell icons from your cooldown viewers. Click to select • Blue border = Customized",
                order = 2,
            },
            iconCustomizationUI = {
                type = "iconCustomization",
                name = "Icon Customization",
                order = 3,
            },
        },
    }
end

ns.CreateIconCustomizationOptions = CreateIconCustomizationOptions
