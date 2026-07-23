local assets = {
    Asset("ANIM", "anim/mycharacter.zip"),
}

local skins = {
    normal_skin = "mycharacter",
    ghost_skin = "ghost_wilson_build",
}

return CreatePrefabSkin("mycharacter_none", {
    base_build = "mycharacter",
    skins = skins,
    assets = assets,
})
