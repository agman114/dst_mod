local Widget = require "widgets/widget"
local Image = require "widgets/image"

local ScavHeadBlurOverlay = Class(Widget, function(self, owner)
    Widget._ctor(self, "ScavHeadBlurOverlay")
    
    self.owner = owner
    self:SetClickable(false)

    self.bg = self:AddChild(Image("images/scav_head_blur.xml", "scav_head_blur.tex"))
    self.bg:SetVAnchor(ANCHOR_MIDDLE)
    self.bg:SetHAnchor(ANCHOR_MIDDLE)
    self.bg:SetScaleMode(SCALEMODE_FILLSCREEN)

    self.alpha = 0
    self.bg:SetTint(1, 1, 1, self.alpha)
    self:Hide()

    self:StartUpdating()
end)

function ScavHeadBlurOverlay:OnUpdate(dt)
    if self.owner then
        local target_alpha = 0
        if self.owner.scav_head_injured and self.owner.scav_head_injured:value() then
            target_alpha = 1.0
        end

        if self.alpha ~= target_alpha then
            if self.alpha < target_alpha then
                self.alpha = math.min(target_alpha, self.alpha + dt * 2.0) -- fade in over 0.5s
            else
                self.alpha = math.max(target_alpha, self.alpha - dt * 1.0) -- fade out over 1.0s
            end
            self.bg:SetTint(1, 1, 1, self.alpha)
        end

        if self.alpha > 0 then
            self:Show()
        else
            self:Hide()
        end
    end
end

return ScavHeadBlurOverlay
