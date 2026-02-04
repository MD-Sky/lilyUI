local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

function ns.CreateClickCastOptions()
    return {
        type = "group",
        name = "Click Cast",
        order = 47,
        childGroups = "tab",
        args = {
            spells = {
                type = "group",
                name = "Spells",
                order = 1,
                args = {
                    content = {
                        type = "clickCastingPage",
                        name = "Spells",
                        order = 1,
                        defaultTab = "spells",
                    },
                },
            },
            macros = {
                type = "group",
                name = "Macros",
                order = 2,
                args = {
                    content = {
                        type = "clickCastingPage",
                        name = "Macros",
                        order = 1,
                        defaultTab = "macros",
                    },
                },
            },
            items = {
                type = "group",
                name = "Items",
                order = 3,
                args = {
                    content = {
                        type = "clickCastingPage",
                        name = "Items",
                        order = 1,
                        defaultTab = "items",
                    },
                },
            },
            profiles = {
                type = "group",
                name = "Profiles",
                order = 4,
                args = {
                    content = {
                        type = "clickCastingPage",
                        name = "Profiles",
                        order = 1,
                        defaultTab = "profiles",
                    },
                },
            },
        },
    }
end
