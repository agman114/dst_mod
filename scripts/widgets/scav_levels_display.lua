local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScavLevelsDisplay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScavLevelsDisplay")
    
    self.owner = owner

    -- Dark translucent background panel
    self.bg = self:AddChild(Image("images/global_redux.xml", "button_square.tex"))
    self.bg:SetSize(460, 30)
    self.bg:SetTint(0.0, 0.0, 0.0, 0.55)

    -- Strength Level (Сила)
    self.str_text = self:AddChild(Text(CHATFONT, 18))
    self.str_text:SetPosition(-140, 0)
    self.str_text:SetColour(0.95, 0.4, 0.4, 1)

    -- Separator 1
    self.sep1 = self:AddChild(Text(CHATFONT, 18))
    self.sep1:SetPosition(-75, 0)
    self.sep1:SetColour(0.5, 0.5, 0.5, 0.5)
    self.sep1:SetString("|")

    -- Intelligence Level (Интеллект)
    self.int_text = self:AddChild(Text(CHATFONT, 18))
    self.int_text:SetPosition(0, 0)
    self.int_text:SetColour(0.4, 0.75, 0.95, 1)

    -- Separator 2
    self.sep2 = self:AddChild(Text(CHATFONT, 18))
    self.sep2:SetPosition(75, 0)
    self.sep2:SetColour(0.5, 0.5, 0.5, 0.5)
    self.sep2:SetString("|")

    -- Endurance Level (Выносливость)
    self.end_text = self:AddChild(Text(CHATFONT, 18))
    self.end_text:SetPosition(140, 0)
    self.end_text:SetColour(0.4, 0.9, 0.4, 1)

    self:StartUpdating()
end)

function ScavLevelsDisplay:OnUpdate(dt)
    if self.owner then
        local str = self.owner.scav_level_strength and self.owner.scav_level_strength:value() or 1
        local int = self.owner.scav_level_intellect and self.owner.scav_level_intellect:value() or 1
        local endur = self.owner.scav_level_endurance and self.owner.scav_level_endurance:value() or 1

        self.str_text:SetString("СИЛА: " .. tostring(str))
        self.int_text:SetString("ИНТЕЛЛЕКТ: " .. tostring(int))
        self.end_text:SetString("ВЫНОСЛИВОСТЬ: " .. tostring(endur))
    end
end

return ScavLevelsDisplay
