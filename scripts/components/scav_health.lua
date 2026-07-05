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

    -- Hook into standard health
    self.inst:ListenForEvent("healthdelta", function(inst, data)
        if data and data.amount < 0 then
            self:DistributeDamage(math.abs(data.amount))
        end
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

    if inst.scav_bleeding_torso then inst.scav_bleeding_torso:set(self.limbs.torso.bleeding) end
    if inst.scav_bleeding_left_arm then inst.scav_bleeding_left_arm:set(self.limbs.left_arm.bleeding) end
    if inst.scav_bleeding_right_arm then inst.scav_bleeding_right_arm:set(self.limbs.right_arm.bleeding) end
    if inst.scav_bleeding_left_leg then inst.scav_bleeding_left_leg:set(self.limbs.left_leg.bleeding) end
    if inst.scav_bleeding_right_leg then inst.scav_bleeding_right_leg:set(self.limbs.right_leg.bleeding) end

    if inst.scav_poisoned then inst.scav_poisoned:set(self.poisoned) end
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

    -- 2. Movement speed slowness (legs)
    local speed_mult = 1.0
    if self.limbs.left_leg.broken then speed_mult = speed_mult - 0.3 end
    if self.limbs.right_leg.broken then speed_mult = speed_mult - 0.3 end
    
    -- Both legs broken -> crawl speed
    if self.limbs.left_leg.broken and self.limbs.right_leg.broken then
        speed_mult = 0.3
    end
    
    if inst.components.locomotor then
        inst.components.locomotor.runspeed = 6.6 * speed_mult
    end

    -- 3. Arm injuries (combat penalty or drop weapon)
    if self.limbs.left_arm.broken or self.limbs.right_arm.broken then
        -- Decreased attack speed/multiplier
        if inst.components.combat then
            inst.components.combat.damagemultiplier = 0.65
        end
    else
        if inst.components.combat then
            inst.components.combat.damagemultiplier = 1.0
        end
    end
end

-- Periodically apply bleeding, poisoning, and handle arm drop weapon chance
local update_timer = 0
function ScavHealth:OnUpdate(dt)
    update_timer = update_timer + dt
    if update_timer < 1.0 then return end
    update_timer = 0

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

    -- If we have damage to apply
    if total_bleeding_damage > 0 and self.inst.components.health and not self.inst.components.health:IsDead() then
        -- Bypass the delta hook using a flag to avoid infinite loops
        self.inst.components.health:DoDelta(-total_bleeding_damage, false, "bleeding_poison")
    end

    -- Broken arms chance to drop active item during attacks/actions (simulate occasionally)
    if (self.limbs.left_arm.broken or self.limbs.right_arm.broken) and math.random() < 0.05 then
        if self.inst.components.inventory then
            local active_item = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if active_item then
                self.inst.components.inventory:DropItem(active_item, true, true)
                if self.inst.components.talker then
                    self.inst.components.talker:Say("Ау! Руки не держат!")
                end
            end
        end
    end

    self:SyncToNetVars()
    self:ApplyEffects()
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
        poisoned = self.poisoned
    }
end

function ScavHealth:OnLoad(data)
    if data then
        if data.limbs then
            self.limbs = data.limbs
        end
        self.poisoned = data.poisoned or false
        self:SyncToNetVars()
        self:ApplyEffects()
    end
end

return ScavHealth
