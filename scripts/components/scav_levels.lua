local ScavLevels = Class(function(self, inst)
    self.inst = inst
    
    self.strength_level = 1
    self.strength_kills = 0

    self.intellect_level = 1
    self.built_prefabs = {}

    self.endurance_level = 1
    self.endurance_steps = 0

    -- Hook killed event for Strength XP
    self.inst:ListenForEvent("killed", function(inst, data)
        if data and data.victim then
            self:AddKills(1)
        end
    end)

    -- Hook prototyping / building for Intelligence XP
    local function on_new_recipe_learned(inst, data)
        local recname = nil
        if data then
            if type(data) == "table" then
                recname = data.recipe or data.name
            elseif type(data) == "string" then
                recname = data
            end
        end
        if recname then
            self:AddBuiltPrefab(recname)
        end
    end
    self.inst:ListenForEvent("recipeprototyped", on_new_recipe_learned)
    self.inst:ListenForEvent("learnrecipe", on_new_recipe_learned)
    self.inst:ListenForEvent("builditem", on_new_recipe_learned)

    -- Hook actions complete for Endurance XP
    self.inst:ListenForEvent("actioncomplete", function(inst, data)
        if data and data.action then
            local act_id = data.action.id
            if act_id == "CHOP" or act_id == "MINE" or act_id == "DIG" then
                self:AddSteps(15) -- Gathering resources adds 15 steps worth of Endurance XP
            end
        end
    end)

    self.inst:StartUpdatingComponent(self)
end)

function ScavLevels:OnUpdate(dt)
    local inst = self.inst
    -- Gaining Endurance XP from walking/running (adds 3 steps per second)
    if inst.sg and inst.sg:HasStateTag("moving") then
        self:AddSteps(3)
    end
end

function ScavLevels:AddKills(amount)
    if self.strength_level >= 100 then return end
    self.strength_kills = (self.strength_kills or 0) + amount
    
    local kills_needed = 50 + 25 * self.strength_level
    while self.strength_kills >= kills_needed and self.strength_level < 100 do
        self.strength_kills = self.strength_kills - kills_needed
        self.strength_level = self.strength_level + 1
        if self.inst.components.talker then
            self.inst.components.talker:Say("Сила увеличилась до уровня " .. tostring(self.strength_level) .. "!")
        end
        kills_needed = 50 + 25 * self.strength_level
    end
    self:SyncToNetVars()
    self:ApplyBuffs()
end

function ScavLevels:AddBuiltPrefab(recipe_name)
    if self.intellect_level >= 100 then return end
    if not self.built_prefabs[recipe_name] then
        self.built_prefabs[recipe_name] = true
        self.intellect_level = self.intellect_level + 1
        if self.inst.components.talker then
            self.inst.components.talker:Say("Интеллект увеличился до уровня " .. tostring(self.intellect_level) .. "!")
        end
        self:SyncToNetVars()
        self:ApplyBuffs()
    end
end

function ScavLevels:AddSteps(amount)
    if self.endurance_level >= 100 then return end
    self.endurance_steps = (self.endurance_steps or 0) + amount
    
    local steps_needed = 500 + 100 * self.endurance_level
    while self.endurance_steps >= steps_needed and self.endurance_level < 100 do
        self.endurance_steps = self.endurance_steps - steps_needed
        self.endurance_level = self.endurance_level + 1
        if self.inst.components.talker then
            self.inst.components.talker:Say("Выносливость увеличилась до уровня " .. tostring(self.endurance_level) .. "!")
        end
        steps_needed = 500 + 100 * self.endurance_level
    end
    self:SyncToNetVars()
    self:ApplyBuffs()
end

function ScavLevels:GetFreeCraftChance()
    return (self.intellect_level or 1) * 0.005
end

function ScavLevels:SyncToNetVars()
    local inst = self.inst
    if inst.scav_level_strength then inst.scav_level_strength:set(self.strength_level or 1) end
    if inst.scav_level_intellect then inst.scav_level_intellect:set(self.intellect_level or 1) end
    if inst.scav_level_endurance then inst.scav_level_endurance:set(self.endurance_level or 1) end
end

function ScavLevels:ApplyBuffs()
    -- Apply the level speed/damage modifiers dynamically
    if self.inst.components.scav_health then
        self.inst.components.scav_health:ApplyEffects()
    end
end

function ScavLevels:OnSave()
    return {
        strength_level = self.strength_level,
        strength_kills = self.strength_kills,
        intellect_level = self.intellect_level,
        built_prefabs = self.built_prefabs,
        endurance_level = self.endurance_level,
        endurance_steps = self.endurance_steps,
    }
end

function ScavLevels:OnLoad(data)
    if data then
        self.strength_level = data.strength_level or 1
        self.strength_kills = data.strength_kills or 0
        self.intellect_level = data.intellect_level or 1
        self.built_prefabs = data.built_prefabs or {}
        self.endurance_level = data.endurance_level or 1
        self.endurance_steps = data.endurance_steps or 0
        self:SyncToNetVars()
        self:ApplyBuffs()
    end
end

return ScavLevels
