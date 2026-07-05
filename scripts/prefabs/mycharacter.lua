local MakePlayerCharacter = require("prefabs/player_common")

local assets = {
    -- Custom character build animation (uncomment when compiled and placed in anim/)
    -- Asset("ANIM", "anim/mycharacter.zip"),
}

-- Custom starting inventory items
local start_inv = {
    "scav_bandage",
    "scav_bandage",
    "scav_splint",
}

-- This is called both on client and server
local function common_postinit(inst)
    -- Minimap icon (using Wilson as placeholder)
    inst.MiniMapEntity:SetIcon("wilson.png")

    -- Tag for bare-handed mining/chopping action picker hook
    inst:AddTag("scav_unarmed_worker")
    
    -- Tag to identify player for standard healing block hook
    inst:AddTag("scav_no_standard_heal")

    -- Sync variables (net_vars) for limb health and debuffs
    inst.scav_limb_head = net_byte(inst.GUID, "scav_limb_head")
    inst.scav_limb_torso = net_byte(inst.GUID, "scav_limb_torso")
    inst.scav_limb_left_arm = net_byte(inst.GUID, "scav_limb_left_arm")
    inst.scav_limb_right_arm = net_byte(inst.GUID, "scav_limb_right_arm")
    inst.scav_limb_left_leg = net_byte(inst.GUID, "scav_limb_left_leg")
    inst.scav_limb_right_leg = net_byte(inst.GUID, "scav_limb_right_leg")

    inst.scav_limb_head:set(100)
    inst.scav_limb_torso:set(100)
    inst.scav_limb_left_arm:set(100)
    inst.scav_limb_right_arm:set(100)
    inst.scav_limb_left_leg:set(100)
    inst.scav_limb_right_leg:set(100)

    inst.scav_broken_left_arm = net_bool(inst.GUID, "scav_broken_left_arm")
    inst.scav_broken_right_arm = net_bool(inst.GUID, "scav_broken_right_arm")
    inst.scav_broken_left_leg = net_bool(inst.GUID, "scav_broken_left_leg")
    inst.scav_broken_right_leg = net_bool(inst.GUID, "scav_broken_right_leg")

    inst.scav_bleeding_torso = net_bool(inst.GUID, "scav_bleeding_torso")
    inst.scav_bleeding_left_arm = net_bool(inst.GUID, "scav_bleeding_left_arm")
    inst.scav_bleeding_right_arm = net_bool(inst.GUID, "scav_bleeding_right_arm")
    inst.scav_bleeding_left_leg = net_bool(inst.GUID, "scav_bleeding_left_leg")
    inst.scav_bleeding_right_leg = net_bool(inst.GUID, "scav_bleeding_right_leg")

    inst.scav_poisoned = net_bool(inst.GUID, "scav_poisoned")
end

-- This is called only on the server
local function master_postinit(inst)
    inst.starting_inventory = start_inv
    
    -- Character stats (100 HP max)
    inst.components.health:SetMaxHealth(100)
    inst.components.hunger:SetMax(150)
    inst.components.sanity:SetMax(150)
    
    -- Set default hand damage to 34 (equivalent to a spear)
    inst.components.combat:SetDefaultDamage(34)
    
    -- Fast base movement speed (6.6 instead of 6.0)
    inst.components.locomotor.runspeed = 6.6

    -- Set model scale to 0.85 (slightly smaller than standard character)
    inst.Transform:SetScale(0.85, 0.85, 0.85)

    -- Attach the custom limb health tracker component
    inst:AddComponent("scav_health")

    -- 1. Block all headwear (Hats)
    local old_CanEquip = inst.components.inventory.CanEquip
    inst.components.inventory.CanEquip = function(self, item, slot, ...)
        if slot == EQUIPSLOTS.HEAD or (item.components.equippable and item.components.equippable.equipslot == EQUIPSLOTS.HEAD) then
            if inst.components.talker then
                inst.components.talker:Say("Я не ношу шляпы!")
            end
            return false
        end
        return old_CanEquip(self, item, slot, ...)
    end

    local old_Equip = inst.components.inventory.Equip
    inst.components.inventory.Equip = function(self, item, old_owner, ...)
        if item.components.equippable and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
            if inst.components.talker then
                inst.components.talker:Say("Я не ношу шляпы!")
            end
            return false
        end
        return old_Equip(self, item, old_owner, ...)
    end

    -- 2. Block all standard healing (Only custom treatment heals)
    local old_DoDelta = inst.components.health.DoDelta
    inst.components.health.DoDelta = function(self, amount, overtime, cause, ...)
        if amount > 0 and cause ~= "treatment" then
            return 0 -- Negate any positive health change unless labeled as "treatment"
        end
        return old_DoDelta(self, amount, overtime, cause, ...)
    end

    -- 3. Bare-handed mining and wood chopping action listener
    -- Spawns temporary invisible fists tool when starting CHOP or MINE unarmed
    inst:ListenForEvent("actioncommence", function(inst, data)
        if data and data.action then
            local act = data.action
            if (act == ACTIONS.CHOP or act == ACTIONS.MINE) then
                local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if equip == nil then
                    local fist = SpawnPrefab("scav_fists_tool")
                    if fist then
                        inst.components.inventory:Equip(fist)
                        inst._scav_temp_fist = fist
                    end
                end
            end
        end
    end)

    local function RemoveTempFist(inst)
        if inst._scav_temp_fist then
            local fist = inst._scav_temp_fist
            inst._scav_temp_fist = nil
            if fist:IsValid() then
                fist:Remove()
            end
        end
    end

    inst:ListenForEvent("actioncomplete", RemoveTempFist)
    inst:ListenForEvent("actionfailed", RemoveTempFist)
end

-- Hidden fist helper prefab
local function fist_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    
    inst:AddTag("nopreview")
    
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(34)
    
    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.CHOP, 1.0)
    inst.components.tool:SetAction(ACTIONS.MINE, 1.0)
    
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.keepondrop = true
    
    return inst
end

-- Define both prefab exports in one file
return MakePlayerCharacter("mycharacter", prefabs, assets, common_postinit, master_postinit, start_inv),
       Prefab("scav_fists_tool", fist_fn, {}, {})
