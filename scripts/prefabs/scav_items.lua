local assets = {}
local prefabs = {}

-- Helper to make standard inventory items
local function MakeItem(name, bank, build, anim, fn_custom)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)

        inst:AddTag("scav_medical")

        if fn_custom then
            fn_custom(inst)
        end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        if name == "scav_bandage" then
            inst.components.inventoryitem.atlasname = "images/scav_bandage.xml"
            inst.components.inventoryitem:ChangeImageName("scav_bandage")
        end
        
        if name ~= "scav_antidote" then
            inst:AddComponent("stackable")
            inst.components.stackable.maxsize = 10
        end

        -- We use a custom useable component to trigger UI on the client
        inst:AddComponent("useableitem")
        inst.components.useableitem:SetOnUseFn(function(inst) return true end)

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local function bandage_custom(inst)
    inst.scav_medical_type = "bandage"
end

local function antidote_custom(inst)
    inst.scav_medical_type = "antidote"
    inst.scav_charge = net_float(inst.GUID, "scav_charge", "scav_chargedirty")
    if TheWorld.ismastersim then
        inst.scav_charge:set(100.0)
    end
end

local function splint_custom(inst)
    inst.scav_medical_type = "splint"
end

-- Use standard globally-loaded game assets as placeholders to prevent crashes
return MakeItem("scav_bandage", "bandage", "bandage", "idle", bandage_custom),
       MakeItem("scav_antidote", "spidergland", "spidergland", "idle", antidote_custom),
       MakeItem("scav_splint", "twigs", "twigs", "idle", splint_custom)
