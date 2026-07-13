local ScavHealth = Class(function(self, inst)
    self.inst = inst
    
    -- Local representation on the server (will sync to net_vars)
    self.limbs = {
        head = { health = 100, max = 100, broken = false, bleeding = false },
        torso = { health = 100, max = 100, broken = false, bleeding = false },
        left_arm = { health = 100, max = 100, broken = false, bleeding = false },
        right_arm = { health = 100, max = 100, broken = false, bleeding = false },
        left_leg = { health = 100, max = 100, broken = false, bleeding = false },
        right_leg = { health = 100, max = 100, broken = false, bleeding = false },
    }
    self.poisoned = false
    self.overdose_cooldown = 0
    self.fatigue = 0
    self.sleeping = false
    self.sanity_slow_walk = false
    self.sanity_scratch_active = false

    -- Hook actions to add fatigue (digging, mining, chopping adds 0.2 fatigue)
    self.inst:ListenForEvent("actioncomplete", function(inst, data)
        if data and data.action then
            local act_id = data.action.id
            if act_id == "CHOP" or act_id == "MINE" or act_id == "DIG" then
                self.fatigue = math.min(100, (self.fatigue or 0) + 0.2)
                self:SyncToNetVars()
                self:ApplyEffects()
            end
        end
    end)

    -- Hook attacks to add fatigue (attacking adds 0.1 fatigue)
    self.inst:ListenForEvent("onattackother", function(inst, data)
        self.fatigue = math.min(100, (self.fatigue or 0) + 0.1)
        self:SyncToNetVars()
        self:ApplyEffects()
    end)

    -- Hook into standard health
    self.inst:ListenForEvent("healthdelta", function(inst, data)
        if data and data.amount < 0 then
            self:DistributeDamage(math.abs(data.amount))
        end
    end)

    -- Venomous creatures can poison the player during combat and attacks can cause bleeding
    self.inst:ListenForEvent("attacked", function(inst, data)
        self.fatigue = math.min(100, (self.fatigue or 0) + 0.2)
        self:SyncToNetVars()
        self:ApplyEffects()
        
        -- 20% chance that any attack causes bleeding on a random limb (excluding head)
        if math.random() < 0.20 then
            local bleed_limbs = { "torso", "left_arm", "right_arm", "left_leg", "right_leg" }
            local chosen_limb = bleed_limbs[math.random(#bleed_limbs)]
            if self.limbs[chosen_limb] then
                self.limbs[chosen_limb].bleeding = true
                self:SyncToNetVars()
                if inst.components.talker then
                    inst.components.talker:Say("Черт, у меня пошла кровь!")
                end
            end
        end

        if data and data.attacker then
            local attacker_prefab = data.attacker.prefab
            if attacker_prefab == "spider_warrior" or attacker_prefab == "bee" or attacker_prefab == "killerbee" then
                if not self.poisoned and math.random() < 0.25 then
                    self.poisoned = true
                    self:SyncToNetVars()
                    if inst.components.talker then
                        inst.components.talker:Say("О нет! Меня отравили!")
                    end
                end
            end
        end
    end)

    self.inst:ListenForEvent("sanitydelta", function(inst, data)
        self:ApplyEffects()
    end)

    self.inst:ListenForEvent("death", function(inst)
        self.overdose_cooldown = 0
        self.sanity_slow_walk = false
        self.sanity_scratch_active = false
        self.fatigue = 0
        self.sleeping = false
        self.groggy_timer = 0
        self:SyncToNetVars()
    end)

    self.inst:ListenForEvent("respawnfromghost", function(inst)
        self.overdose_cooldown = 0
        self.sanity_slow_walk = false
        self.sanity_scratch_active = false
        self.fatigue = 0
        self.sleeping = false
        self.groggy_timer = 0
        self:SyncToNetVars()
    end)

    self.inst:StartUpdatingComponent(self)
end)

-- Sync server state to the client network variables
function ScavHealth:SyncToNetVars()
    local inst = self.inst
    if inst.scav_limb_head then inst.scav_limb_head:set(math.floor(self.limbs.head.health)) end
    if inst.scav_limb_torso then inst.scav_limb_torso:set(math.floor(self.limbs.torso.health)) end
    if inst.scav_limb_left_arm then inst.scav_limb_left_arm:set(math.floor(self.limbs.left_arm.health)) end
    if inst.scav_limb_right_arm then inst.scav_limb_right_arm:set(math.floor(self.limbs.right_arm.health)) end
    if inst.scav_limb_left_leg then inst.scav_limb_left_leg:set(math.floor(self.limbs.left_leg.health)) end
    if inst.scav_limb_right_leg then inst.scav_limb_right_leg:set(math.floor(self.limbs.right_leg.health)) end

    if inst.scav_broken_left_arm then inst.scav_broken_left_arm:set(self.limbs.left_arm.broken) end
    if inst.scav_broken_right_arm then inst.scav_broken_right_arm:set(self.limbs.right_arm.broken) end
    if inst.scav_broken_left_leg then inst.scav_broken_left_leg:set(self.limbs.left_leg.broken) end
    if inst.scav_broken_right_leg then inst.scav_broken_right_leg:set(self.limbs.right_leg.broken) end
    if inst.scav_broken_torso then inst.scav_broken_torso:set(self.limbs.torso.broken) end

    if inst.scav_bleeding_torso then inst.scav_bleeding_torso:set(self.limbs.torso.bleeding) end
    if inst.scav_bleeding_left_arm then inst.scav_bleeding_left_arm:set(self.limbs.left_arm.bleeding) end
    if inst.scav_bleeding_right_arm then inst.scav_bleeding_right_arm:set(self.limbs.right_arm.bleeding) end
    if inst.scav_bleeding_left_leg then inst.scav_bleeding_left_leg:set(self.limbs.left_leg.bleeding) end
    if inst.scav_bleeding_right_leg then inst.scav_bleeding_right_leg:set(self.limbs.right_leg.bleeding) end

    if inst.scav_poisoned then inst.scav_poisoned:set(self.poisoned) end
    if inst.scav_overdose_cooldown then inst.scav_overdose_cooldown:set(self.overdose_cooldown or 0) end
    if inst.scav_sanity_slow_walk then inst.scav_sanity_slow_walk:set(self.sanity_slow_walk or false) end
    if inst.scav_fatigue then inst.scav_fatigue:set(self.fatigue or 0) end
    if inst.scav_sleeping then inst.scav_sleeping:set(self.sleeping or false) end
end

-- Distribute incoming damage to limbs randomly
function ScavHealth:DistributeDamage(amount)
    local limb_names = { "head", "torso", "left_arm", "right_arm", "left_leg", "right_leg" }
    
    -- Pick a random limb to take the brunt of the hit
    local primary_limb = limb_names[math.random(#limb_names)]
    local limb = self.limbs[primary_limb]

    limb.health = math.max(0, limb.health - amount)

    -- High damage can cause fractures or bleeding
    if amount >= 15 then
        if primary_limb == "torso" then
            limb.broken = true
            limb.bleeding = true
        elseif primary_limb == "head" then
            -- Head injury
            if limb.health < 30 then
                self.inst:AddTag("brain_damaged")
            end
        elseif primary_limb == "left_arm" or primary_limb == "right_arm" then
            limb.broken = true
            limb.bleeding = math.random() > 0.5
        elseif primary_limb == "left_leg" or primary_limb == "right_leg" then
            limb.broken = true
            limb.bleeding = math.random() > 0.5
        end
    end

    self:SyncToNetVars()
    self:ApplyEffects()
end

-- Apply speed and capability modifiers based on limb health
function ScavHealth:ApplyEffects()
    local inst = self.inst
    
    -- 1. Speech block
    if self.limbs.head.health < 30 or inst:HasTag("brain_damaged") then
        if not inst:HasTag("brain_damaged") then
            inst:AddTag("brain_damaged")
        end
    else
        inst:RemoveTag("brain_damaged")
    end

    -- 2. Movement speed slowness (legs, low sanity, and fatigue)
    local speed_mult = 1.0
    if self.limbs.left_leg.broken or self.limbs.right_leg.broken then
        speed_mult = 0.5
    end
    
    if inst.components.sanity then
        local sanity_val = inst.components.sanity.current
        if sanity_val <= 0 then
            self.sanity_slow_walk = true
        elseif sanity_val > 0 then
            self.sanity_slow_walk = false
        end
    end

    local anim_speed = 1.0
    
    -- Check fatigue states
    if self.fatigue >= 100 and not self.sleeping then
        -- Groggy/extremely tired state (50% speed and 50% action speed)
        speed_mult = speed_mult * 0.5
        anim_speed = 0.5
    elseif self.fatigue <= 0 and not self.sleeping then
        -- Well-rested state (10% speed boost and 10% action speed boost)
        speed_mult = speed_mult * 1.1
        anim_speed = 1.1
    elseif self.sanity_slow_walk and not self.sleeping then
        -- Insane slow walk (60% speed and 75% action speed)
        speed_mult = speed_mult * 0.6
        anim_speed = 0.75
    end

    if inst.AnimState then
        inst.AnimState:SetDeltaTimeMultiplier(anim_speed)
    end

    -- Retrieve leveling stats
    local strength_level = 1
    local endurance_level = 1
    if inst.components.scav_levels then
        strength_level = inst.components.scav_levels.strength_level or 1
        endurance_level = inst.components.scav_levels.endurance_level or 1
    end

    local endurance_speed_mult = 1.0 + endurance_level * 0.0015
    speed_mult = speed_mult * endurance_speed_mult
    
    if inst.components.locomotor then
        inst.components.locomotor.runspeed = 6.6 * speed_mult
    end

    -- Hunger burn rate
    if inst.components.hunger then
        if self.sleeping then
            -- Set dynamically in OnUpdate depending on location
        elseif self.fatigue <= 0 then
            -- Well-rested hunger (1.15x burn rate)
            inst.components.hunger.burnrate = 1.15
        else
            inst.components.hunger.burnrate = 1.0
        end
    end

    -- 3. Arm injuries and Strength damage/work multipliers
    local strength_damage_mult = 1.0 + strength_level * 0.0025
    if self.limbs.left_arm.broken or self.limbs.right_arm.broken then
        -- Decreased attack speed/multiplier
        if inst.components.combat then
            inst.components.combat.damagemultiplier = 0.75 * strength_damage_mult
        end
    else
        if inst.components.combat then
            inst.components.combat.damagemultiplier = 1.0 * strength_damage_mult
        end
    end

    -- Apply Strength resource gathering speed (work multiplier)
    local strength_work_mult = 1.0 + strength_level * 0.0025
    if inst.components.workmultiplier then
        inst.components.workmultiplier:AddMultiplier(_G.ACTIONS.CHOP, strength_work_mult, "scav_strength")
        inst.components.workmultiplier:AddMultiplier(_G.ACTIONS.MINE, strength_work_mult, "scav_strength")
        inst.components.workmultiplier:AddMultiplier(_G.ACTIONS.DIG, strength_work_mult, "scav_strength")
    end
end

-- Periodically apply bleeding, poisoning, and handle arm drop weapon chance
local update_timer = 0
function ScavHealth:OnUpdate(dt)
    update_timer = update_timer + dt
    if update_timer < 1.0 then return end
    update_timer = 0

    local inst = self.inst

    local total_bleeding_damage = 0
    for name, limb in pairs(self.limbs) do
        if limb.bleeding then
            total_bleeding_damage = total_bleeding_damage + 1 -- 1 dmg per bleeding limb
            
            -- Bleeding slowly lowers limb health too
            limb.health = math.max(0, limb.health - 0.5)
        end
    end

    -- Apply poison damage
    if self.poisoned then
        total_bleeding_damage = total_bleeding_damage + 2
        -- Poison damages all limbs slowly
        for name, limb in pairs(self.limbs) do
            limb.health = math.max(10, limb.health - 0.2)
        end
    end

    -- Torso broken damage when moving
    local is_moving = false
    if self.inst.sg and self.inst.sg:HasStateTag("moving") then
        is_moving = true
    elseif self.inst.Physics then
        local vx, vy, vz = self.inst.Physics:GetVelocity()
        if (vx * vx + vz * vz) > 0.01 then
            is_moving = true
        end
    end

    if self.limbs.torso.broken and is_moving then
        if self.inst.components.health and not self.inst.components.health:IsDead() then
            self.inst.components.health:DoDelta(-3, false, "torso_fracture_movement")
            if math.random() < 0.25 then
                if self.inst.components.talker then
                    self.inst.components.talker:Say("Ааах! Сломанные ребра режут изнутри!")
                end
                if self.inst.SoundEmitter then
                    self.inst.SoundEmitter:PlaySound("dontstarve/characters/wilson/hurt")
                end
            end
        end
    end

    -- If we have damage to apply
    if total_bleeding_damage > 0 and self.inst.components.health and not self.inst.components.health:IsDead() then
        -- Bypass the delta hook using a flag to avoid infinite loops
        self.inst.components.health:DoDelta(-total_bleeding_damage, false, "bleeding_poison")
    end

    -- Broken arms chance to drop active item every few seconds (35% chance every 4 seconds)
    self.arm_slip_timer = (self.arm_slip_timer or 0) + 1.0
    if self.arm_slip_timer >= 4.0 then
        self.arm_slip_timer = 0
        if (self.limbs.left_arm.broken or self.limbs.right_arm.broken) and math.random() < 0.35 then
            if self.inst.components.inventory then
                local active_item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if active_item then
                    self.inst.components.inventory:DropItem(active_item, true, true)
                    if self.inst.components.talker then
                        self.inst.components.talker:Say("Ой! Руки онемели, предмет выскользнул!")
                    end
                end
            end
        end
    end

    -- Sanity-based triggers for the self-scratching minigame
    if self.inst.components.sanity then
        local sanity_val = self.inst.components.sanity.current
        
        -- If sanity hits 0, start the scratching period
        if sanity_val <= 0 then
            if not self.sanity_scratch_active then
                self.sanity_scratch_active = true
                -- Trigger first minigame after 2 seconds on initial drop to 0
                self.sanity_scratch_timer = 18.0
            end
        elseif sanity_val >= 10 then
            self.sanity_scratch_active = false
        end

        if self.sanity_scratch_active then
            self.sanity_scratch_timer = (self.sanity_scratch_timer or 0) + 1.0
            if self.sanity_scratch_timer >= 20.0 then
                self.sanity_scratch_timer = 0
                
                -- Trigger client self-scratch screen!
                if self.inst.scav_trigger_scratch then
                    self.inst.scav_trigger_scratch:push()
                end
            end
        else
            self.sanity_scratch_timer = 0
        end
    end

    -- Fatigue/Sleep update ticks
    if self.sleeping then
        -- Check if player is still in knockout or wakeup state
        local state_name = inst.sg and inst.sg.currentstate and inst.sg.currentstate.name
        if state_name ~= "knockout" and state_name ~= "wakeup" then
            -- Player woke up (interrupted by movement or attack)
            self.sleeping = false
            if inst.components.hunger then
                inst.components.hunger.burnrate = 1.0
            end
        else
            -- Keep timeout high during active sleep
            if state_name == "knockout" then
                inst.sg:SetTimeout(3600)
            end
            
            -- Decrease fatigue during sleep (2.0 per second)
            self.fatigue = math.max(0, (self.fatigue or 0) - 2.0)
            
            -- Detect location to apply sleep quality bonuses and override animations
            local FindEntity = _G.FindEntity
            local is_near_firepit = FindEntity(inst, 4, function(ent) return ent.prefab == "firepit" end) ~= nil
            local is_near_campfire = not is_near_firepit and FindEntity(inst, 4, function(ent) return ent.prefab == "campfire" or ent:HasTag("fire") end) ~= nil
            
            if is_near_firepit then
                -- Stone fire pit: reduced hunger (0.5x), +2 HP/10s (+0.2/s), +3 Sanity/4s (+0.75/s)
                if inst.components.hunger then inst.components.hunger.burnrate = 0.5 end
                if inst.components.health then inst.components.health:DoDelta(0.2, true) end
                if inst.components.sanity then inst.components.sanity:DoDelta(0.75) end
                
                -- Play furry bedroll animation override if in sleep loop
                if state_name == "knockout" and inst.AnimState and inst.AnimState:IsCurrentAnimation("sleep_loop") then
                    inst.AnimState:PlayAnimation("bedroll_sleep_loop", true)
                end
            elseif is_near_campfire then
                -- Campfire: normal hunger (1.0x), +1 HP/10s (+0.1/s), +3 Sanity/5s (+0.6/s)
                if inst.components.hunger then inst.components.hunger.burnrate = 1.0 end
                if inst.components.health then inst.components.health:DoDelta(0.1, true) end
                if inst.components.sanity then inst.components.sanity:DoDelta(0.6) end
                
                -- Play normal bedroll animation override if in sleep loop
                if state_name == "knockout" and inst.AnimState and inst.AnimState:IsCurrentAnimation("sleep_loop") then
                    inst.AnimState:PlayAnimation("bedroll_sleep_loop", true)
                end
            else
                -- Wilderness: doubled hunger (2.0x), no health regen, +2 Sanity/5s (+0.4/s)
                if inst.components.hunger then inst.components.hunger.burnrate = 2.0 end
                if inst.components.sanity then inst.components.sanity:DoDelta(0.4) end
            end

            -- Wake up automatically at 0 fatigue
            if self.fatigue <= 0 then
                self.sleeping = false
                if inst.components.hunger then inst.components.hunger.burnrate = 1.0 end
                inst.sg:GoToState("wakeup")
                if inst.components.talker then
                    inst.components.talker:Say("Я отлично выспался!")
                end
            end
        end
    else
        -- Regular fatigue accumulation (from 0 to 100 in 480 seconds)
        self.fatigue = math.min(100, (self.fatigue or 0) + (100 / 480))
        
        -- Automatic collapse at 100 fatigue
        if self.fatigue >= 100 then
            self.groggy_timer = (self.groggy_timer or 0) + 1.0
            if self.groggy_timer == 1.0 then
                if inst.components.talker then
                    inst.components.talker:Say("Ооох... Я сейчас упаду от усталости...")
                end
            elseif self.groggy_timer >= 3.0 then
                self:StartSleeping(true)
            end
        else
            self.groggy_timer = 0
        end
    end

    if self.overdose_cooldown and self.overdose_cooldown > 0 then
        self.overdose_cooldown = math.max(0, self.overdose_cooldown - 1.0)
    end

    self:SyncToNetVars()
    self:ApplyEffects()
end

-- Attempt to start sleeping manually via keypress
function ScavHealth:TryStartSleep()
    if self.sleeping then return end
    if (self.fatigue or 0) >= 50 then
        self:StartSleeping(false)
    elseif self.inst.components.talker then
        self.inst.components.talker:Say("Я еще не устал чтобы спать (нужно 50%+).")
    end
end

-- Go to sleep state depending on local environment
function ScavHealth:StartSleeping(forced)
    local inst = self.inst
    if self.sleeping then return end

    self.sleeping = true
    self.groggy_timer = 0
    
    inst.sg:GoToState("knockout")
    inst.sg:SetTimeout(3600)
end

-- Set limb bleeding state
function ScavHealth:SetLimbBleeding(limb_name, is_bleeding)
    local limb = self.limbs[limb_name]
    if limb then
        limb.bleeding = is_bleeding
        self:SyncToNetVars()
        self:ApplyEffects()
    end
end

-- Heal a specific limb
function ScavHealth:HealLimb(limb_name, heal_amount, cure_bleeding, cure_fracture, cure_poison)
    local limb = self.limbs[limb_name]
    if not limb then return end

    limb.health = math.min(limb.max, limb.health + heal_amount)
    
    if cure_bleeding then
        limb.bleeding = false
    end
    
    if cure_fracture then
        limb.broken = false
    end

    if cure_poison then
        self.poisoned = false
    end

    -- Heal overall character health
    if self.inst.components.health then
        self.inst.components.health:DoDelta(heal_amount * 0.5, true, "treatment")
    end

    self:SyncToNetVars()
    self:ApplyEffects()
end

-- Save/Load data support
function ScavHealth:OnSave()
    return {
        limbs = self.limbs,
        poisoned = self.poisoned,
        fatigue = self.fatigue,
        sleeping = self.sleeping,
    }
end

function ScavHealth:OnLoad(data)
    if data then
        if data.limbs then
            self.limbs = data.limbs
        end
        self.poisoned = data.poisoned or false
        self.fatigue = data.fatigue or 0
        self.sleeping = data.sleeping or false
        self:SyncToNetVars()
        self:ApplyEffects()
    end
end

return ScavHealth
