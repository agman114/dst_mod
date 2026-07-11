local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ScavScratchScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "ScavScratchScreen")
    
    self.owner = owner

    -- Set up root widget
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- Background dim overlay
    self.black = self.root:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetSize(2000, 2000)
    self.black:SetTint(0.2, 0, 0, 0.75) -- Dark reddish tint for craziness

    -- Scratch target background skin patch
    self.scratch_bg = self.root:AddChild(Image("images/scav_scratch_bg.xml", "scav_scratch_bg.tex"))
    self.scratch_bg:SetPosition(0, 0)
    self.scratch_bg:SetSize(300, 400)

    -- Scratch Marks (directly overlayed on the skin patch)
    self.scratch_marks = self.root:AddChild(Image("images/scav_scratch_marks.xml", "scav_scratch_marks.tex"))
    self.scratch_marks:SetPosition(0, 0)
    self.scratch_marks:SetSize(200, 400)
    self.scratch_marks:SetTint(1, 1, 1, 0) -- Start transparent

    -- Title
    self.title = self.root:AddChild(Text(TITLEFONT, 38))
    self.title:SetPosition(0, 280)
    self.title:SetString("ГОРЯЧКА РАССУДКА")
    self.title:SetColour(0.9, 0.1, 0.1, 1)

    -- Instruction text
    self.instructions = self.root:AddChild(Text(CHATFONT, 22))
    self.instructions:SetPosition(0, 240)
    self.instructions:SetString("Зажмите левую кнопку мыши и процарапайте кожу сверху вниз!")
    self.instructions:SetColour(0.8, 0.8, 0.8, 1)

    -- Interactive Arm/Claw Hand (pointing from mouse cursor to bottom-right corner)
    self.claw_hand = self.root:AddChild(Image("images/scav_arm_normal.xml", "scav_arm_normal.tex"))
    self.claw_hand:SetVRegPoint(ANCHOR_TOP)
    self.claw_hand:SetHRegPoint(ANCHOR_MIDDLE)

    self.lowest_y = 120
    self.completed = false

    if TheInputProxy then
        TheInputProxy:SetCursorVisible(false) -- Hide hardware cursor
    end

    self:StartUpdating()
end)

function ScavScratchScreen:OnUpdate(dt)
    if self.completed then return end

    local w, h = TheSim:GetScreenSize()
    local mouse_pos = TheInput:GetScreenPosition()
    local scale = self.root:GetScale()
    local local_x = (mouse_pos.x - w / 2) / scale.x
    local local_y = (mouse_pos.y - h / 2) / scale.y

    -- Base of the arm anchored at the bottom-right corner of the screen
    local screen_w = w / scale.x
    local screen_h = h / scale.y
    local base_x = screen_w / 2
    local base_y = -screen_h / 2

    -- Calculate distance and angle from the cursor to the bottom-right corner
    local dx = base_x - local_x
    local dy = base_y - local_y
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle_rad = math.atan2(dx, -dy)
    local angle_deg = -angle_rad * 180 / math.pi

    -- Anchor the palm (top of image) at the cursor and extend the arm past the bottom-right
    self.claw_hand:SetPosition(local_x, local_y)
    self.claw_hand:SetRotation(angle_deg)
    self.claw_hand:SetSize(180, dist + 150)

    -- Check click state to switch texture
    if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
        self.claw_hand:SetTexture("images/scav_claw_hand.xml", "scav_claw_hand.tex")
        
        -- Check if mouse/hand is inside the scratch skin area
        if math.abs(local_x) < 150 and local_y < 150 and local_y > -150 then
            -- Only allow progression moving downwards
            if local_y < self.lowest_y then
                self.lowest_y = local_y
                
                -- Play scratch sounds periodically
                if math.random() < 0.15 then
                    self.owner.SoundEmitter:PlaySound("dontstarve/common/destroy_stone")
                end
            end

            -- Update scratch marks opacity based on lowest y reached
            -- Target scratch area goes from y = 120 (start) to y = -120 (end)
            local total_dist = 240
            local dragged_dist = 120 - self.lowest_y
            local progress = math.max(0, math.min(1, dragged_dist / total_dist))
            self.scratch_marks:SetTint(1, 1, 1, progress)

            -- Check for completion
            if self.lowest_y <= -120 then
                self.completed = true
                self.scratch_marks:SetTint(1, 1, 1, 1)
                self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
                
                -- Send server RPC to trigger bleeding
                SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplySanityScratch"))
                
                self.inst:DoTaskInTime(0.5, function()
                    self:Close()
                end)
            end
        end
    else
        self.claw_hand:SetTexture("images/scav_arm_normal.xml", "scav_arm_normal.tex")
    end
end

function ScavScratchScreen:Close()
    if TheInputProxy then
        TheInputProxy:SetCursorVisible(true) -- Restore hardware cursor
    end
    TheFrontEnd:PopScreen(self)
end

function ScavScratchScreen:OnControl(control, down)
    if ScavScratchScreen._base.OnControl(self, control, down) then return true end
    
    -- Prevent closing via normal cancel/escape (player is forced to complete the minigame)
    return true
end

return ScavScratchScreen
