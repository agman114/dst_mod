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
}

-- Prefab files to load
PrefabFiles = {
    "mycharacter",
    "scav_items",
    "scav_chest",
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

-- Register custom character
AddModCharacter("mycharacter", "MALE")

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
                end
                
                player.components.scav_health:HealLimb(limb_name, heal_amt, cure_bleed, cure_fracture, cure_poison)
            end
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
    GLOBAL.TheInput:AddKeyUpHandler(GLOBAL.KEY_V, function()
        local player = GLOBAL.ThePlayer
        if player and player:IsValid() and player.prefab == "mycharacter" then
            local TheFrontEnd = GLOBAL.TheFrontEnd
            local active_screen = TheFrontEnd:GetActiveScreen()
            
            if active_screen == player.HUD then
                local ScavMedicalScreen = require("screens/scav_medical_screen")
                TheFrontEnd:PushScreen(ScavMedicalScreen(player))
            elseif active_screen and active_screen.name == "ScavMedicalScreen" then
                active_screen:Close()
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
        
        -- 1. Intercept locked chests to trigger lockpicking UI
        if target and target:HasTag("scav_chest") and target.scav_locked and target.scav_locked:value() then
            if inst == ThePlayer then
                local ScavLockpickScreen = require("screens/scav_lockpick_screen")
                if not TheFrontEnd:GetActiveScreen() or TheFrontEnd:GetActiveScreen().name ~= "ScavLockpickScreen" then
                    TheFrontEnd:PushScreen(ScavLockpickScreen(inst, target))
                end
                return {} -- Stop action, do not run standard open container
            end
        end

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
