local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

function ns.CreatePartyFrameOptions()
    if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.BuildLilyUIOptions then
        return LilyUI.PartyFrames:BuildLilyUIOptions("party", "Party Frames", 45)
    end

    return {
        type = "group",
        name = "Party Frames",
        order = 45,
        args = {
            fallback = {
                type = "description",
                name = "Party frame options are not available yet.",
                order = 1,
            },
        },
    }
end
