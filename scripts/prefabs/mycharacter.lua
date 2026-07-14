local MakePlayerCharacter = require("prefabs/player_common")

local assets = {
    -- Custom character build animation (uncomment when compiled and placed in anim/)
    -- Asset("ANIM", "anim/mycharacter.zip"),
}

-- Custom starting inventory items
local start_inv = {
    "scav_bandage",
    "scav_antidote",
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
    inst.scav_broken_torso = net_bool(inst.GUID, "scav_broken_torso")

    inst.scav_bleeding_torso = net_bool(inst.GUID, "scav_bleeding_torso")
    inst.scav_bleeding_left_arm = net_bool(inst.GUID, "scav_bleeding_left_arm")
    inst.scav_bleeding_right_arm = net_bool(inst.GUID, "scav_bleeding_right_arm")
    inst.scav_bleeding_left_leg = net_bool(inst.GUID, "scav_bleeding_left_leg")
    inst.scav_bleeding_right_leg = net_bool(inst.GUID, "scav_bleeding_right_leg")

    inst.scav_poisoned = net_bool(inst.GUID, "scav_poisoned")
    inst.scav_overdose_cooldown = net_float(inst.GUID, "scav_overdose_cooldown")
    inst.scav_sanity_slow_walk = net_bool(inst.GUID, "scav_sanity_slow_walk")
    inst.scav_fatigue = net_float(inst.GUID, "scav_fatigue")
    inst.scav_sleeping = net_bool(inst.GUID, "scav_sleeping")
    inst.scav_head_injured = net_bool(inst.GUID, "scav_head_injured")
    inst.scav_heavy_bleeding = net_bool(inst.GUID, "scav_heavy_bleeding")

    inst.scav_level_strength = net_byte(inst.GUID, "scav_level_strength")
    inst.scav_level_intellect = net_byte(inst.GUID, "scav_level_intellect")
    inst.scav_level_endurance = net_byte(inst.GUID, "scav_level_endurance")

    inst.scav_level_strength:set(1)
    inst.scav_level_intellect:set(1)
    inst.scav_level_endurance:set(1)

    -- Prevent shadow monsters from aggroing (remove sanity_creatures tag immediately)
    inst:RemoveTag("sanity_creatures")
    inst:ListenForEvent("tagadded", function(inst, data)
        if data and data.tag == "sanity_creatures" then
            inst:RemoveTag("sanity_creatures")
        end
    end)

    inst.scav_trigger_lockpick = net_event(inst.GUID, "scav_trigger_lockpick")
    inst.scav_trigger_scratch = net_event(inst.GUID, "scav_trigger_scratch")

    inst:ListenForEvent("scav_trigger_lockpick", function(inst)
        local env = getfenv()
        if inst == env.ThePlayer then
            local chest = env.FindEntity(inst, 4, function(ent)
                return ent:HasTag("scav_chest") and ent.scav_locked and ent.scav_locked:value()
            end)
            if chest then
                local TheFrontEnd = env.TheFrontEnd
                if chest.scav_lock_type and chest.scav_lock_type:value() == 1 then
                    local ScavKeypadScreen = require("screens/scav_keypad_screen")
                    if not TheFrontEnd:GetActiveScreen() or TheFrontEnd:GetActiveScreen().name ~= "ScavKeypadScreen" then
                        TheFrontEnd:PushScreen(ScavKeypadScreen(inst, chest))
                    end
                else
                    local ScavLockpickScreen = require("screens/scav_lockpick_screen")
                    if not TheFrontEnd:GetActiveScreen() or TheFrontEnd:GetActiveScreen().name ~= "ScavLockpickScreen" then
                        TheFrontEnd:PushScreen(ScavLockpickScreen(inst, chest))
                    end
                end
            end
        end
    end)

    inst:ListenForEvent("scav_trigger_scratch", function(inst)
        local env = getfenv()
        if inst == env.ThePlayer then
            local TheFrontEnd = env.TheFrontEnd
            local ScavScratchScreen = require("screens/scav_scratch_screen")
            if not TheFrontEnd:GetActiveScreen() or TheFrontEnd:GetActiveScreen().name ~= "ScavScratchScreen" then
                TheFrontEnd:PushScreen(ScavScratchScreen(inst))
            end
        end
    end)

    if not getfenv().TheNet:IsDedicated() then
        inst:DoTaskInTime(1, function(inst)
            local env = getfenv()
            local _G = getfenv(0)
            if inst == env.ThePlayer then
                _G.TheInput:AddKeyDownHandler(_G.KEY_Z, function()
                    local TheFrontEnd = _G.TheFrontEnd
                    if TheFrontEnd and (TheFrontEnd:GetActiveScreen() == nil or TheFrontEnd:GetActiveScreen().name == "HUD") then
                        _G.SendModRPCToServer(_G.GetModRPC("MEGACALLLMOD", "TriggerSleep"))
                    end
                end)
            end
        end)
    end
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
    inst:AddComponent("scav_levels")

    -- Allow unarmed chopping, mining, and digging
    local _G = getfenv(0)
    inst:AddComponent("worker")
    inst.components.worker:SetAction(_G.ACTIONS.CHOP, 1)
    inst.components.worker:SetAction(_G.ACTIONS.MINE, 1)
    inst.components.worker:SetAction(_G.ACTIONS.DIG, 1)
    inst:AddComponent("workmultiplier")

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

    -- Spawn start chests (both types) and give medical items to player
    inst:DoTaskInTime(3, function(inst)
        if not inst.scav_spawned_start_chest then
            inst.scav_spawned_start_chest = true

            -- Give items for easy testing
            if inst.components.inventory then
                local function GiveItem(prefab, count)
                    for i = 1, count do
                        local item = SpawnPrefab(prefab)
                        if item then
                            inst.components.inventory:GiveItem(item)
                        end
                    end
                end
                GiveItem("scav_splint", 5)
                GiveItem("scav_bandage", 5)
                GiveItem("scav_antidote", 2)
            end

            local spawner = require("scav_chest_spawner")
            if spawner and spawner.SpawnChestNearPlayer then
                spawner.SpawnChestNearPlayer(inst, "scav_chest")
                inst:DoTaskInTime(0.5, function(inst)
                    spawner.SpawnChestNearPlayer(inst, "scav_keypad_chest")
                    print("[SCAV Spawner] Spawned start chests (both lockpick and keypad) near player!")
                end)
            end
        end
    end)

    -- Save/Load start chest spawn flag
    local old_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        data.scav_spawned_start_chest = inst.scav_spawned_start_chest
        if old_OnSave then
            return old_OnSave(inst, data)
        end
    end

    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if data then
            inst.scav_spawned_start_chest = data.scav_spawned_start_chest
        end
        if old_OnLoad then
            old_OnLoad(inst, data)
        end
    end
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
