local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScavStatsDisplay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScavStatsDisplay")
    
    self.owner = owner

    -- Scale both panels to fit nicely on the left side of the medical screen
    self:SetScale(0.7, 0.7)

    -- ----------------------------------------------------
    -- 1. Main Stats Panel (486x513)
    -- ----------------------------------------------------
    self.stats_panel = self:AddChild(Widget("stats_panel"))
    self.stats_panel:SetPosition(0, 160)

    self.bg = self.stats_panel:AddChild(Image("images/scav_stats_bg.xml", "scav_stats_bg.tex"))
    self.bg:SetPosition(0, 0)
    self.bg:SetSize(486, 513)

    local green_color = { 75/255, 214/255, 131/255, 1 }

    -- Header / Title text
    self.header_text = self.stats_panel:AddChild(Text(NUMBERFONT, 20))
    self.header_text:SetPosition(0, 238.5)
    self.header_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.header_text:SetString("EXPERIMENT   180cm 20y    8387")

    -- Sanity progress bar fill
    self.sanity_bar = self.stats_panel:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.sanity_bar:SetHRegPoint(ANCHOR_LEFT)
    self.sanity_bar:SetPosition(-100, 206.5)
    self.sanity_bar:SetSize(210, 20)

    -- Consciousness (CONSC)
    self.consc_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.consc_text:SetPosition(-80, 158.5)
    self.consc_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Pain (PAIN)
    self.pain_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.pain_text:SetPosition(-80, 121.5)
    self.pain_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Blood volume (BLOOD)
    self.blood_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.blood_text:SetPosition(-80, 84.5)
    self.blood_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Oxygen (O2)
    self.o2_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.o2_text:SetPosition(-130, 47.5)
    self.o2_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Infection / Immune
    self.inf_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.inf_text:SetPosition(110, 47.5)
    self.inf_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Temperature (TEMP)
    self.temp_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.temp_text:SetPosition(-90, -35.0)
    self.temp_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Heart rate / Pulse (HR)
    self.pulse_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.pulse_text:SetPosition(70, -35.0)
    self.pulse_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Stomach / Hunger
    self.stomach_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.stomach_text:SetPosition(-90, -142.5)
    self.stomach_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Fatigue / Sleep
    self.fatigue_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.fatigue_text:SetPosition(70, -142.5)
    self.fatigue_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Weight
    self.weight_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.weight_text:SetPosition(-90, -225.0)
    self.weight_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.weight_text:SetString("72.5 kg")

    -- Radiation (RAD)
    self.rad_text = self.stats_panel:AddChild(Text(NUMBERFONT, 18))
    self.rad_text:SetPosition(70, -225.0)
    self.rad_text:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.rad_text:SetString("0.0 gy")

    -- ----------------------------------------------------
    -- 2. Selected Limb Panel (198x331)
    -- ----------------------------------------------------
    self.limb_panel = self:AddChild(Widget("limb_panel"))
    self.limb_panel:SetPosition(0, -310)

    self.limb_bg = self.limb_panel:AddChild(Image("images/scav_limb_bg.xml", "scav_limb_bg.tex"))
    self.limb_bg:SetPosition(0, 0)
    self.limb_bg:SetSize(198, 331)

    -- Selected Limb Title
    self.limb_title = self.limb_panel:AddChild(Text(TITLEFONT, 20))
    self.limb_title:SetPosition(0, 130)
    self.limb_title:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Skin health label & bar
    self.skin_label = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.skin_label:SetPosition(-55, 45)
    self.skin_label:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.skin_label:SetString("SKIN")

    self.skin_bar = self.limb_panel:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.skin_bar:SetHRegPoint(ANCHOR_LEFT)
    self.skin_bar:SetPosition(-5, 45)
    self.skin_bar:SetSize(1, 12)

    -- Muscle health label & bar
    self.muscl_label = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.muscl_label:SetPosition(-55, -5)
    self.muscl_label:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.muscl_label:SetString("MUSCL")

    self.muscl_bar = self.limb_panel:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.muscl_bar:SetHRegPoint(ANCHOR_LEFT)
    self.muscl_bar:SetPosition(-5, -5)
    self.muscl_bar:SetSize(1, 12)

    -- Fracture status label & value
    self.frac_label = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.frac_label:SetPosition(-55, -55)
    self.frac_label:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.frac_label:SetString("FRAC")

    self.frac_val = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.frac_val:SetPosition(25, -55)
    self.frac_val:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Dislocation status label & value
    self.disl_label = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.disl_label:SetPosition(-55, -105)
    self.disl_label:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])
    self.disl_label:SetString("DISL")

    self.disl_val = self.limb_panel:AddChild(Text(NUMBERFONT, 16))
    self.disl_val:SetPosition(25, -105)
    self.disl_val:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Default selection
    self.selected_limb = "torso"

    self:StartUpdating()
end)

function ScavStatsDisplay:UpdateSelectedLimb(limb_name)
    if limb_name then
        self.selected_limb = limb_name
    end
end

function ScavStatsDisplay:OnUpdate(dt)
    local inst = self.owner
    if not inst then return end

    -- 1. Update Main Stats
    local sanity_pct = inst.components.sanity and inst.components.sanity:GetPercent() or 1
    self.sanity_bar:SetSize(math.max(1, 210 * sanity_pct), 20)

    local pain_val = inst.components.scav_health and inst.components.scav_health:GetPain() or 0
    local consc_val = math.max(0, 100 - pain_val)
    self.consc_text:SetString(string.format("  %d%% CONSC", consc_val))
    self.pain_text:SetString(string.format("  %d%% PAIN", pain_val))

    local num_bleeds = 0
    if inst.components.scav_health and inst.components.scav_health.limbs then
        for _, limb in pairs(inst.components.scav_health.limbs) do
            if limb.bleeding then
                num_bleeds = num_bleeds + 1
            end
        end
    end
    local blood_vol = 5.00 - (num_bleeds * 0.25)
    self.blood_text:SetString(string.format("  %.2fL", blood_vol))

    self.o2_text:SetString("O2 99%")
    self.inf_text:SetString("159%")

    local temp = inst.components.temperature and inst.components.temperature:GetCurrent() or 37
    self.temp_text:SetString(string.format("%.1f c", temp))

    local pulse = 60 + math.floor(pain_val * 0.5)
    self.pulse_text:SetString(string.format("%d bpm", pulse))

    local hunger_pct = inst.components.hunger and inst.components.hunger:GetPercent() or 1
    self.stomach_text:SetString(string.format("%d%%", math.floor(hunger_pct * 100)))

    local fatigue_val = inst.scav_fatigue and inst.scav_fatigue:value() or 0
    self.fatigue_text:SetString(string.format("%d%%", math.floor(fatigue_val)))

    -- 2. Update Selected Limb details
    local limb_names_display = {
        head = "HEAD",
        torso = "TORSO",
        left_arm = "LEFT ARM",
        right_arm = "RIGHT ARM",
        left_leg = "LEFT LEG",
        right_leg = "RIGHT LEG",
    }
    self.limb_title:SetString(limb_names_display[self.selected_limb] or "TORSO")

    local limb_health = 100
    local is_broken = false
    if inst.components.scav_health and inst.components.scav_health.limbs then
        local limb = inst.components.scav_health.limbs[self.selected_limb]
        if limb then
            limb_health = limb.health or 100
            is_broken = limb.broken or false
        end
    end

    -- Skin health vs muscle health simulation based on limb health
    local skin_pct = math.clamp(limb_health / 100, 0, 1)
    local muscl_pct = math.clamp(limb_health / 100, 0, 1)
    self.skin_bar:SetSize(math.max(1, 65 * skin_pct), 12)
    self.muscl_bar:SetSize(math.max(1, 65 * muscl_pct), 12)

    self.frac_val:SetString(is_broken and "YES" or "-")
    self.disl_val:SetString("-")
end

return ScavStatsDisplay
