-- DST Scav Prototype Mod Main Script

-- Import DST globals
local GLOBAL = GLOBAL
local STRINGS = GLOBAL.STRINGS
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local ACTIONS = GLOBAL.ACTIONS
local BufferedAction = GLOBAL.BufferedAction
local TheNet = GLOBAL.TheNet

-- Hook client-side Image widget to redirect missing UI assets to Wilson as placeholders
if not TheNet:IsDedicated() then
    local Image = require("widgets/image")
    local old_SetTexture = Image.SetTexture
    Image.SetTexture = function(self, atlas, tex, ...)
        if atlas == "bigportraits/mycharacter.xml" then
            atlas = "bigportraits/wilson.xml"
            tex = "wilson.tex"
        elseif atlas == "images/names/mycharacter.xml" then
            atlas = "images/names.xml"
            tex = "wilson.tex"
        elseif atlas == "images/selectheroes/select_mycharacter.xml" then
            atlas = "images/selectheroes.xml"
            tex = "wilson.tex"
        elseif atlas == "images/avatars/avatar_mycharacter.xml" then
            atlas = "images/avatars.xml"
            tex = "avatar_wilson.tex"
        elseif atlas == "images/avatars/avatar_ghost_mycharacter.xml" then
            atlas = "images/avatars.xml"
            tex = "avatar_ghost_wilson.tex"
        elseif atlas == "images/map_icons/mycharacter.xml" then
            atlas = "images/map_icons.xml"
            tex = "wilson.png"
        elseif atlas == "images/saveslot_portraits/mycharacter.xml" then
            atlas = "images/saveslot_portraits.xml"
            tex = "wilson.tex"
        end
        return old_SetTexture(self, atlas, tex, ...)
    end
end

-- Assets to load
Assets = {
    -- Custom item assets
    -- Asset("ANIM", "anim/scav_items.zip"),
    
    -- Custom UI assets
    Asset("ATLAS", "images/Body.xml"),
    Asset("IMAGE", "images/Body.tex"),
    Asset("ATLAS", "images/Head.xml"),
    Asset("IMAGE", "images/Head.tex"),
    Asset("ATLAS", "images/LHand.xml"),
    Asset("IMAGE", "images/LHand.tex"),
    Asset("ATLAS", "images/RHand.xml"),
    Asset("IMAGE", "images/RHand.tex"),
    Asset("ATLAS", "images/LLeg.xml"),
    Asset("IMAGE", "images/LLeg.tex"),
    Asset("ATLAS", "images/RLeg.xml"),
    Asset("IMAGE", "images/RLeg.tex"),
    Asset("ATLAS", "images/Circle-removebg-preview.xml"),
    Asset("IMAGE", "images/Circle-removebg-preview.tex"),
    Asset("ATLAS", "images/Bondage-removebg-preview.xml"),
    Asset("IMAGE", "images/Bondage-removebg-preview.tex"),
    Asset("ATLAS", "images/Arm-removebg-preview.xml"),
    Asset("IMAGE", "images/Arm-removebg-preview.tex"),
    Asset("ATLAS", "images/ArmFist-removebg-preview.xml"),
    Asset("IMAGE", "images/ArmFist-removebg-preview.tex"),
    Asset("ATLAS", "images/scav_bandage.xml"),
    Asset("IMAGE", "images/scav_bandage.tex"),
    Asset("ATLAS", "images/scav_syringe.xml"),
    Asset("IMAGE", "images/scav_syringe.tex"),
    Asset("ATLAS", "images/scav_body_target.xml"),
    Asset("IMAGE", "images/scav_body_target.tex"),
    Asset("ATLAS", "images/scav_lock_keyhole.xml"),
    Asset("IMAGE", "images/scav_lock_keyhole.tex"),
    Asset("ATLAS", "images/scav_lock_scale.xml"),
    Asset("IMAGE", "images/scav_lock_scale.tex"),
    Asset("ATLAS", "images/scav_pinpad.xml"),
    Asset("IMAGE", "images/scav_pinpad.tex"),
    Asset("ATLAS", "images/scav_blood_drop.xml"),
    Asset("IMAGE", "images/scav_blood_drop.tex"),
    Asset("ATLAS", "images/scav_bone_icon.xml"),
    Asset("IMAGE", "images/scav_bone_icon.tex"),
    Asset("ATLAS", "images/scav_bone_left.xml"),
    Asset("IMAGE", "images/scav_bone_left.tex"),
    Asset("ATLAS", "images/scav_bone_right.xml"),
    Asset("IMAGE", "images/scav_bone_right.tex"),
    Asset("ATLAS", "images/scav_bone_whole.xml"),
    Asset("IMAGE", "images/scav_bone_whole.tex"),
    Asset("ATLAS", "images/scav_scratch_marks.xml"),
    Asset("IMAGE", "images/scav_scratch_marks.tex"),
    Asset("ATLAS", "images/scav_claw_hand.xml"),
    Asset("IMAGE", "images/scav_claw_hand.tex"),
    Asset("ATLAS", "images/scav_scratch_bg.xml"),
    Asset("IMAGE", "images/scav_scratch_bg.tex"),
    Asset("ATLAS", "images/scav_arm_normal.xml"),
    Asset("IMAGE", "images/scav_arm_normal.tex"),
    Asset("ATLAS", "images/scav_fatigue_icon.xml"),
    Asset("IMAGE", "images/scav_fatigue_icon.tex"),
    Asset("ATLAS", "images/scav_head_blur.xml"),
    Asset("IMAGE", "images/scav_head_blur.tex"),
    Asset("ATLAS", "images/scav_levels_bg.xml"),
    Asset("IMAGE", "images/scav_levels_bg.tex"),
    Asset("ATLAS", "images/scav_levels_bar.xml"),
    Asset("IMAGE", "images/scav_levels_bar.tex"),
}

-- Prefab files to load
PrefabFiles = {
    "mycharacter",
    "scav_items",
    "scav_chest",
    "scav_keypad_chest",
}

-- Load speech strings
local speech = require("speech_mycharacter")
STRINGS.CHARACTERS.MYCHARACTER = speech

-- Select screen strings
STRINGS.CHARACTER_NAMES.mycharacter = "Выживший"
STRINGS.CHARACTER_TITLES.mycharacter = "Casualty Unknown"
STRINGS.CHARACTER_DESCRIPTIONS.mycharacter = "* Здоровье конечностей и лечение вручную\n* Не носит головные уборы и не лечится едой/мазями\n* Быстрый, бьет кулаками как копьем и добывает ресурсы руками\n* Взламывает случайные сундуки"
STRINGS.CHARACTER_QUOTES.mycharacter = "\"Я должен выжить любой ценой.\""

STRINGS.NAMES.MYCHARACTER = "Выживший"

STRINGS.NAMES.SCAV_BANDAGE = "Бинт"
STRINGS.NAMES.SCAV_ANTIDOTE = "Шприц"
STRINGS.NAMES.SCAV_SPLINT = "Шина"

STRINGS.CHARACTERS.GENERIC.DESCRIBE.SCAV_BANDAGE = "Обычный бинт для перевязки ран."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SCAV_ANTIDOTE = "Шприц с лечебным раствором."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SCAV_SPLINT = "Шина для фиксации сломанных костей."

AddModCharacter("mycharacter", "MALE")

if GLOBAL.rawget(GLOBAL, "RegisterInventoryItemAtlas") then
    GLOBAL.RegisterInventoryItemAtlas("images/scav_bandage.xml", "scav_bandage.tex")
    GLOBAL.RegisterInventoryItemAtlas("images/scav_syringe.xml", "scav_syringe.tex")
end

AddClassPostConstruct("widgets/statusdisplays", function(self)
    if self.owner and self.owner:HasTag("scav_unarmed_worker") then
        local ScavFatigueBadge = require("widgets/scav_fatigue_badge")
        self.scav_fatigue_badge = self:AddChild(ScavFatigueBadge(self.owner))
        self.scav_fatigue_badge:SetPosition(-70, -45)
    end
end)

--------------------------------------------------------------------------------
-- REGISTER MOD RPCs (Network Sync Client -> Server)
--------------------------------------------------------------------------------
AddModRPCHandler("MEGACALLLMOD", "ApplyTreatment", function(player, item, limb_name)
    if player and player:IsValid() and item and item:IsValid() and limb_name then
        -- Validate player has the item in inventory
        if player.components.inventory and player.components.inventory:Has(item.prefab, 1) then
            -- Consume 1 item from inventory
            player.components.inventory:ConsumeByName(item.prefab, 1)
            
            -- Apply healing values
            if player.components.scav_health then
                local heal_amt = 0
                local cure_bleed = false
                local cure_fracture = false
                local cure_poison = false
                
                if item.prefab == "scav_bandage" then
                    heal_amt = 15
                    cure_bleed = true
                elseif item.prefab == "scav_splint" then
                    heal_amt = 0
                    cure_fracture = true
                elseif item.prefab == "scav_antidote" then
                    heal_amt = 10
                    cure_poison = true
                    if player.components.sanity then
                        player.components.sanity:SetPercent(1.0)
                    end
                end
                
                player.components.scav_health:HealLimb(limb_name, heal_amt, cure_bleed, cure_fracture, cure_poison)
            end
        end
    end
end)

AddModRPCHandler("MEGACALLLMOD", "ApplyOverdose", function(player, limb_name)
    if player and player:IsValid() and player.components.scav_health and limb_name then
        player.components.scav_health:SetLimbBleeding(limb_name, true)
    end
end)

AddModRPCHandler("MEGACALLLMOD", "ApplySanityScratch", function(player)
    if player and player:IsValid() and player.components.scav_health then
        local arms = { "left_arm", "right_arm" }
        local chosen_arm = arms[math.random(#arms)]
        player.components.scav_health:SetLimbBleeding(chosen_arm, true)
        if player.SoundEmitter then
            player.SoundEmitter:PlaySound("dontstarve/characters/wilson/hurt")
        end
        if player.components.talker then
            player.components.talker:Say("Ааах! Я разодрал себе руку!")
        end
    end
end)

AddModRPCHandler("MEGACALLLMOD", "StartOverdoseCooldown", function(player)
    if player and player:IsValid() and player.components.scav_health then
        player.components.scav_health.overdose_cooldown = 300 -- 5 minutes
        player.components.scav_health:SyncToNetVars()
    end
end)

AddModRPCHandler("MEGACALLLMOD", "UpdateSyringe", function(player, item, injected_amt)
    if player and player:IsValid() and item and item:IsValid() then
        if player.components.inventory and player.components.inventory:Has(item.prefab, 1) then
            if item.scav_charge then
                local current = item.scav_charge:value()
                local new_charge = math.max(0, current - injected_amt)
                item.scav_charge:set(new_charge)
                if item.components.finiteuses then
                    item.components.finiteuses:SetUses(math.ceil(new_charge))
                end
                
                -- Restore sanity proportionally to the injected amount
                if player.components.sanity and injected_amt > 0 then
                    local sanity_gain = (injected_amt / 100) * player.components.sanity.max
                    player.components.sanity:DoDelta(sanity_gain)
                end

                -- Cure poison if they injected at least 25%
                if injected_amt >= 25.0 and player.components.scav_health then
                    player.components.scav_health.poisoned = false
                    player.components.scav_health:SyncToNetVars()
                end
                
                -- Consume the item if it has no charge left (e.g. <= 0.5)
                if new_charge <= 0.5 and item:IsValid() then
                    player.components.inventory:ConsumeByName(item.prefab, 1)
                end
            end
        end
    end
end)

AddModRPCHandler("MEGACALLLMOD", "TriggerSleep", function(player)
    if player and player:IsValid() and player.components.scav_health then
        if not player:HasTag("playerghost") and not player.components.health:IsDead() then
            player.components.scav_health:TryStartSleep()
        end
    end
end)

AddModRPCHandler("MEGACALLLMOD", "LockpickSuccess", function(player, chest)
    if player and player:IsValid() and chest and chest:IsValid() then
        if chest.scav_locked and chest.scav_locked:value() then
            chest.scav_locked:set(false)
            -- Open the container for the player immediately
            if chest.components.container then
                chest.components.container:Open(player)
            end
        end
    end
end)

AddModRPCHandler("MEGACALLLMOD", "LockpickFail", function(player, chest)
    if player and player:IsValid() and chest and chest:IsValid() then
        -- Inflict 15 damage from electric shock / spring trap
        if player.components.health then
            player.components.health:DoDelta(-15, false, "lockpick")
        end
        -- Randomize lock again on failure
        if chest.scav_lock_type then
            chest.scav_lock_type:set(math.random(0, 1))
        end
    end
end)

--------------------------------------------------------------------------------
-- REGISTER KEYBOARD LISTENER (Open/Close Medical screen on KEY_V)
--------------------------------------------------------------------------------
if not TheNet:IsDedicated() then
    local function IsMedicalScreenOpen()
        local TheFrontEnd = GLOBAL.TheFrontEnd
        if TheFrontEnd and TheFrontEnd.screen_stack then
            for _, screen in ipairs(TheFrontEnd.screen_stack) do
                if screen.name == "ScavMedicalScreen" then
                    return screen
                end
            end
        end
        return nil
    end

    GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_V, function()
        local player = GLOBAL.ThePlayer
        if player and player:IsValid() and player.prefab == "mycharacter" then
            local TheFrontEnd = GLOBAL.TheFrontEnd
            local active_screen = TheFrontEnd:GetActiveScreen()
            
            -- Prevent opening if chat or console is active
            if active_screen and (active_screen.name == "ChatInputScreen" or active_screen.name == "ConsoleScreen") then
                return
            end
            
            local open_screen = IsMedicalScreenOpen()
            if open_screen then
                open_screen:Close()
            elseif active_screen == player.HUD then
                local ScavMedicalScreen = require("screens/scav_medical_screen")
                TheFrontEnd:PushScreen(ScavMedicalScreen(player))
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- HOOK ACTIONS & TARGET CLICKS (Chest Lockpicking & Bare-handed Mining/Chopping)
--------------------------------------------------------------------------------
AddComponentPostInit("playeractionpicker", function(self)
    -- Hook left clicks to allow bare-handed chop/mine and intercept chest lockpicking
    local old_GetLeftClickActions = self.GetLeftClickActions
    self.GetLeftClickActions = function(self, position, target, ...)
        local inst = self.inst
        local ThePlayer = GLOBAL.ThePlayer
        local TheFrontEnd = GLOBAL.TheFrontEnd
        
        -- Call original logic
        local actions = old_GetLeftClickActions(self, position, target, ...)

        -- 2. Allow bare-handed mining and wood chopping
        if inst and inst:HasTag("scav_unarmed_worker") and target then
            local equip = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip == nil then
                if target:HasTag("choppable") then
                    local has_chop = false
                    for _, act in ipairs(actions) do
                        if act.action == ACTIONS.CHOP then has_chop = true break end
                    end
                    if not has_chop then
                        table.insert(actions, BufferedAction(inst, target, ACTIONS.CHOP))
                    end
                elseif target:HasTag("mineable") then
                    local has_mine = false
                    for _, act in ipairs(actions) do
                        if act.action == ACTIONS.MINE then has_mine = true break end
                    end
                    if not has_mine then
                        table.insert(actions, BufferedAction(inst, target, ACTIONS.MINE))
                    end
                end
            end
        end

        return actions
    end
end)

--------------------------------------------------------------------------------
-- DEBUFF HOOKS (Speech restriction when brain-damaged)
--------------------------------------------------------------------------------
local function HookTalker(inst)
    if inst.components.talker then
        local old_Say = inst.components.talker.Say
        inst.components.talker.Say = function(self, script, time, noanim, force, nobroadcast, colour)
            if inst:HasTag("brain_damaged") then
                return -- Brain damage blocks speak announcements
            end
            return old_Say(self, script, time, noanim, force, nobroadcast, colour)
        end
    end
end
AddPrefabPostInit("mycharacter", HookTalker)

--------------------------------------------------------------------------------
-- BLOCK STANDARD HEALING ITEMS (Spider glands, healing salves, etc.)
--------------------------------------------------------------------------------
AddComponentPostInit("healer", function(self)
    local old_Heal = self.Heal
    self.Heal = function(self, target, ...)
        if target and target:HasTag("scav_no_standard_heal") then
            if target.components.talker then
                target.components.talker:Say("Это обычное лечение мне не поможет.")
            end
            return false
        end
        return old_Heal(self, target, ...)
    end
end)

--------------------------------------------------------------------------------
-- CHEST SPAWNER WORLD INITIALIZATION
--------------------------------------------------------------------------------
AddPrefabPostInit("forest", function(world)
    if world.ismastersim then
        require("scav_chest_spawner")
    end
end)

AddPrefabPostInit("cave", function(world)
    if world.ismastersim then
        require("scav_chest_spawner")
    end
end)

-- Debug key listener to inflict damage and test the limb medical screen
if not TheNet:IsDedicated() then
    GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_J, function()
        local player = GLOBAL.ThePlayer
        if player and player.components.scav_health then
            player.components.scav_health:DistributeDamage(30)
            if player.components.talker then
                player.components.talker:Say("Ой! Я нанёс себе тестовую травму (клавиша J)!")
            end
        end
    end)
end

-- Hook RUMMAGE action to trigger lockpicking minigame on server
local old_RUMMAGE_fn = GLOBAL.ACTIONS.RUMMAGE.fn
GLOBAL.ACTIONS.RUMMAGE.fn = function(act, ...)
    local target = act.target
    local doer = act.doer
    if target and target:HasTag("scav_chest") and target.scav_locked and target.scav_locked:value() then
        if doer and doer:IsValid() then
            if doer:HasTag("scav_unarmed_worker") then
                -- Push net event to trigger client minigame UI on the doer player
                if doer.scav_trigger_lockpick then
                    doer.scav_trigger_lockpick:push()
                end
            else
                if doer.components.talker then
                    doer.components.talker:Say("Этот замок слишком сложный для меня...")
                end
            end
        end
        return true -- Handled/blocked standard container open slots
    end
    return old_RUMMAGE_fn(act, ...)
end

-- Global console command helper for debug
GLOBAL.c_setfatigue = function(val)
    local player = GLOBAL.ThePlayer
    if player and player.components.scav_health then
        player.components.scav_health.fatigue = math.max(0, math.min(100, val))
        player.components.scav_health:SyncToNetVars()
        player.components.scav_health:ApplyEffects()
        print("[SCAV Debug] Set fatigue to: " .. tostring(val))
    end
end

-- Hook Builder:RemoveIngredients for Intellect free crafting chance
local Builder = GLOBAL.require("components/builder")
if Builder then
    local old_RemoveIngredients = Builder.RemoveIngredients
    Builder.RemoveIngredients = function(self, ingredients, recname, discounted, ...)
        local free_craft_chance = 0
        if self.inst.components.scav_levels then
            free_craft_chance = self.inst.components.scav_levels:GetFreeCraftChance()
        end

        if free_craft_chance > 0 and GLOBAL.math.random() < free_craft_chance then
            -- Free craft!
            if self.inst.components.talker then
                self.inst.components.talker:Say("Скрафчено бесплатно благодаря интеллекту! (Шанс: " .. tostring(free_craft_chance * 100) .. "%)")
            end
            return
        end

        return old_RemoveIngredients(self, ingredients, recname, discounted, ...)
    end
end

-- Hook controls widget to add levels display and head stun blur overlay
AddClassPostConstruct("widgets/controls", function(self)
    if self.owner and self.owner:HasTag("scav_unarmed_worker") then
        local ScavHeadBlurOverlay = require("widgets/scav_head_blur_overlay")
        self.scav_head_blur_overlay = self:AddChild(ScavHeadBlurOverlay(self.owner))
    end
end)

-- Levels debug console commands
GLOBAL.c_setstrength = function(val)
    local player = GLOBAL.ThePlayer
    if player and player.components.scav_levels then
        player.components.scav_levels.strength_level = GLOBAL.math.max(1, GLOBAL.math.min(100, val))
        player.components.scav_levels.strength_kills = 0
        player.components.scav_levels:SyncToNetVars()
        player.components.scav_levels:ApplyBuffs()
        print("[SCAV Debug] Set strength level to: " .. tostring(val))
    end
end

GLOBAL.c_setintellect = function(val)
    local player = GLOBAL.ThePlayer
    if player and player.components.scav_levels then
        player.components.scav_levels.intellect_level = GLOBAL.math.max(1, GLOBAL.math.min(100, val))
        player.components.scav_levels:SyncToNetVars()
        player.components.scav_levels:ApplyBuffs()
        print("[SCAV Debug] Set intellect level to: " .. tostring(val))
    end
end

GLOBAL.c_setendurance = function(val)
    local player = GLOBAL.ThePlayer
    if player and player.components.scav_levels then
        player.components.scav_levels.endurance_level = GLOBAL.math.max(1, GLOBAL.math.min(100, val))
        player.components.scav_levels.endurance_steps = 0
        player.components.scav_levels:SyncToNetVars()
        player.components.scav_levels:ApplyBuffs()
        print("[SCAV Debug] Set endurance level to: " .. tostring(val))
    end
end

-- Hook playeractionpicker to allow unarmed work actions (left-click for chop/mine, right-click for dig)
AddClassPostConstruct("components/playeractionpicker", function(self)
    local old_GetLeftClickActions = self.GetLeftClickActions
    self.GetLeftClickActions = function(self, position, target, ...)
        local actions = old_GetLeftClickActions(self, position, target, ...)
        if self.inst:HasTag("scav_unarmed_worker") then
            local equipitem = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equipitem == nil and target ~= nil and target ~= self.inst then
                -- Check if target is workable
                if target:HasTag("CHOP_workable") or target:HasTag("MINE_workable") then
                    local work_act = target:HasTag("CHOP_workable") and ACTIONS.CHOP or ACTIONS.MINE
                    actions = actions or {}
                    -- Check if it's already in the action list
                    local has_act = false
                    for _, act in ipairs(actions) do
                        if act.action == work_act then
                            has_act = true
                            break
                        end
                    end
                    if not has_act then
                        table.insert(actions, 1, BufferedAction(self.inst, target, work_act))
                    end
                end
            end
        end
        return actions
    end

    local old_GetRightClickActions = self.GetRightClickActions
    self.GetRightClickActions = function(self, position, target, ...)
        local actions = old_GetRightClickActions(self, position, target, ...)
        if self.inst:HasTag("scav_unarmed_worker") then
            local equipitem = self.inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equipitem == nil and target ~= nil and target ~= self.inst then
                -- Check if target is workable
                if target:HasTag("DIG_workable") then
                    local work_act = ACTIONS.DIG
                    actions = actions or {}
                    local has_act = false
                    for _, act in ipairs(actions) do
                        if act.action == work_act then
                            has_act = true
                            break
                        end
                    end
                    if not has_act then
                        table.insert(actions, 1, BufferedAction(self.inst, target, work_act))
                    end
                end
            end
        end
        return actions
    end
end)
