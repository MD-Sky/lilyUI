local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

function ns.CreateRaidFrameOptions()
    if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.BuildLilyUIOptions then
        return LilyUI.PartyFrames:BuildLilyUIOptions("raid", "Raid Frames", 46)
    end

    return {
        type = "group",
        name = "Raid Frames",
        order = 46,
        args = {
            fallback = {
                type = "description",
                name = "Raid frame options are not available yet.",
                order = 1,
            },
        },
    }
end
