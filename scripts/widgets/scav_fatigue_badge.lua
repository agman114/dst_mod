local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScavFatigueBadge = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScavFatigueBadge")
    
    self.owner = owner

    -- Background circle (matches standard badge sizes)
    self.bg = self:AddChild(Image("images/global_redux.xml", "button_square.tex"))
    self.bg:SetSize(60, 60)
    self.bg:SetTint(0.1, 0.1, 0.15, 0.8)

    -- Fill circle representing fatigue
    self.fill = self:AddChild(Image("images/global_redux.xml", "button_square.tex"))
    self.fill:SetSize(52, 52)
    self.fill:SetTint(0.3, 0.3, 0.9, 0.6) -- Violet-blue color for sleepiness

    -- Sleep Icon (crescent moon with Zzz)
    self.icon = self:AddChild(Image("images/scav_fatigue_icon.xml", "scav_fatigue_icon.tex"))
    self.icon:SetSize(32, 32)
    self.icon:SetTint(0.9, 0.9, 0.9, 1)

    -- Hover Percentage Text
    self.num = self:AddChild(Text(NUMBERFONT, 20))
    self.num:SetPosition(0, 0)
    self.num:Hide()

    -- Sleep Quality Text (displayed below the badge when sleeping)
    self.quality_text = self:AddChild(Text(CHATFONT, 18))
    self.quality_text:SetPosition(0, -42)
    self.quality_text:Hide()

    self:SetTooltip("Усталость")
    self:StartUpdating()
end)

function ScavFatigueBadge:OnUpdate(dt)
    if self.owner and self.owner.scav_fatigue then
        local val = self.owner:HasTag("playerghost") and 0 or self.owner.scav_fatigue:value()
        
        -- Set fill size proportional to fatigue (max size 52)
        local size = 52 * (val / 100)
        self.fill:SetSize(size, size)
        
        -- Update text
        self.num:SetString(string.format("%d", val))

        -- Sleep Quality text update
        local is_sleeping = self.owner.scav_sleeping and self.owner.scav_sleeping:value()
        if is_sleeping then
            local x, y, z = self.owner.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 4)
            local near_firepit = false
            local near_campfire = false
            for _, ent in ipairs(ents) do
                if ent.prefab == "firepit" then
                    near_firepit = true
                    break
                elseif ent.prefab == "campfire" or ent:HasTag("fire") then
                    near_campfire = true
                end
            end
            
            if near_firepit then
                self.quality_text:SetString("Отличное")
                self.quality_text:SetColour(0.4, 0.9, 0.4, 1)
                self.quality_text:Show()
            elseif near_campfire then
                self.quality_text:SetString("Хорошее")
                self.quality_text:SetColour(0.9, 0.9, 0.4, 1)
                self.quality_text:Show()
            else
                self.quality_text:SetString("Плохое")
                self.quality_text:SetColour(0.9, 0.3, 0.3, 1)
                self.quality_text:Show()
            end
        else
            self.quality_text:Hide()
        end
    end
end

function ScavFatigueBadge:OnGainFocus()
    ScavFatigueBadge._base.OnGainFocus(self)
    self.num:Show()
    self.icon:Hide()
end

function ScavFatigueBadge:OnLoseFocus()
    ScavFatigueBadge._base.OnLoseFocus(self)
    self.num:Hide()
    self.icon:Show()
end

return ScavFatigueBadge
