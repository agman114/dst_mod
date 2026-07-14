local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScavLevelsDisplay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScavLevelsDisplay")
    
    self.owner = owner

    -- Scale the entire widget to fit nicely on the screen
    self:SetScale(0.7, 0.7)

    -- Stats Box Background (463x232)
    self.bg = self:AddChild(Image("images/scav_levels_bg.xml", "scav_levels_bg.tex"))
    self.bg:SetPosition(0, 0)
    self.bg:SetSize(463, 232)

    -- Text colors matching the green/cyan sci-fi terminal theme of Casualties: Unknown
    local green_color = { 75/255, 214/255, 131/255, 1 }

    -- ----------------------------------------------------
    -- Row 1: STR (Strength)
    -- ----------------------------------------------------
    -- Progress Bar Fill (height 30, max width 367)
    self.str_bar = self:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.str_bar:SetHRegPoint(ANCHOR_LEFT)
    self.str_bar:SetPosition(-144.5, 58.5)
    self.str_bar:SetSize(1, 30)

    -- Level number text
    self.str_level = self:AddChild(Text(NUMBERFONT, 24))
    self.str_level:SetPosition(-186.5, 21.0)
    self.str_level:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Stats numbers text (start_xp | current_xp | end_xp)
    self.str_numbers = self:AddChild(Text(NUMBERFONT, 18))
    self.str_numbers:SetPosition(38.0, 21.0)
    self.str_numbers:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- ----------------------------------------------------
    -- Row 2: RES (Endurance / Resistance)
    -- ----------------------------------------------------
    -- Progress Bar Fill
    self.res_bar = self:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.res_bar:SetHRegPoint(ANCHOR_LEFT)
    self.res_bar:SetPosition(-144.5, -16.5)
    self.res_bar:SetSize(1, 30)

    -- Level number text
    self.res_level = self:AddChild(Text(NUMBERFONT, 24))
    self.res_level:SetPosition(-186.5, -54.0)
    self.res_level:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Stats numbers text
    self.res_numbers = self:AddChild(Text(NUMBERFONT, 18))
    self.res_numbers:SetPosition(38.0, -54.0)
    self.res_numbers:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- ----------------------------------------------------
    -- Row 3: INT (Intelligence)
    -- ----------------------------------------------------
    -- Progress Bar Fill
    self.int_bar = self:AddChild(Image("images/scav_levels_bar.xml", "scav_levels_bar.tex"))
    self.int_bar:SetHRegPoint(ANCHOR_LEFT)
    self.int_bar:SetPosition(-144.5, -91.5)
    self.int_bar:SetSize(1, 30)

    -- Level number text
    self.int_level = self:AddChild(Text(NUMBERFONT, 24))
    self.int_level:SetPosition(-186.5, -129.0)
    self.int_level:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    -- Stats numbers text
    self.int_numbers = self:AddChild(Text(NUMBERFONT, 18))
    self.int_numbers:SetPosition(38.0, -129.0)
    self.int_numbers:SetColour(green_color[1], green_color[2], green_color[3], green_color[4])

    self:StartUpdating()
end)

local function get_str_xp_details(level, kills)
    local level_start_xp = 0
    for i = 1, level - 1 do
        local xp_needed_i = 75 + (i - 1) * 25
        level_start_xp = level_start_xp + xp_needed_i
    end
    local xp_needed = 75 + (level - 1) * 25
    local current_xp = level_start_xp + kills
    local level_end_xp = level_start_xp + xp_needed
    local pct = math.max(0, math.min(1, kills / xp_needed))
    return level_start_xp, current_xp, level_end_xp, pct
end

local function get_end_xp_details(level, steps)
    local level_start_xp = 0
    for i = 1, level - 1 do
        local xp_needed_i = 500 + (i - 1) * 100
        level_start_xp = level_start_xp + xp_needed_i
    end
    local xp_needed = 500 + (level - 1) * 100
    local current_xp = level_start_xp + steps
    local level_end_xp = level_start_xp + xp_needed
    local pct = math.max(0, math.min(1, steps / xp_needed))
    return level_start_xp, current_xp, level_end_xp, pct
end

local function get_int_xp_details(level)
    local level_start_xp = (level - 1) * 10
    local current_xp = (level - 1) * 10
    local level_end_xp = level * 10
    return level_start_xp, current_xp, level_end_xp, 0
end

function ScavLevelsDisplay:OnUpdate(dt)
    if self.owner then
        -- Read level values
        local str_lvl = self.owner.scav_level_strength and self.owner.scav_level_strength:value() or 1
        local int_lvl = self.owner.scav_level_intellect and self.owner.scav_level_intellect:value() or 1
        local endur_lvl = self.owner.scav_level_endurance and self.owner.scav_level_endurance:value() or 1

        -- Read current XP values
        local str_kills = self.owner.scav_xp_strength and self.owner.scav_xp_strength:value() or 0
        local endur_steps = self.owner.scav_xp_endurance and self.owner.scav_xp_endurance:value() or 0

        -- 1. Strength (STR)
        local str_start, str_curr, str_end, str_pct = get_str_xp_details(str_lvl, str_kills)
        self.str_level:SetString(tostring(str_lvl))
        self.str_numbers:SetString(string.format("%d | %d | %d", str_start, str_curr, str_end))
        self.str_bar:SetSize(math.max(1, 367 * str_pct), 30)

        -- 2. Endurance (RES)
        local end_start, end_curr, end_end, end_pct = get_end_xp_details(endur_lvl, endur_steps)
        self.res_level:SetString(tostring(endur_lvl))
        self.res_numbers:SetString(string.format("%d | %d | %d", end_start, end_curr, end_end))
        self.res_bar:SetSize(math.max(1, 367 * end_pct), 30)

        -- 3. Intelligence (INT)
        local int_start, int_curr, int_end, int_pct = get_int_xp_details(int_lvl)
        self.int_level:SetString(tostring(int_lvl))
        self.int_numbers:SetString(string.format("%d | %d | %d", int_start, int_curr, int_end))
        self.int_bar:SetSize(math.max(1, 367 * int_pct), 30)
    end
end

return ScavLevelsDisplay
