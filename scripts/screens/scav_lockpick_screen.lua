local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"

local ScavLockpickScreen = Class(Screen, function(self, owner, chest)
    Screen._ctor(self, "ScavLockpickScreen")
    
    self.owner = owner
    self.chest = chest

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
    self.black:SetTint(0, 0, 0, 0.7)

    -- Main Panel
    self.panel = self.root:AddChild(Image("images/global_redux.xml", "panel_blank.tex"))
    self.panel:SetSize(500, 500)

    -- Title
    self.title = self.panel:AddChild(Text(TITLEFONT, 32))
    self.title:SetPosition(0, 200)
    self.title:SetString("ВЗЛОМ ЗАМКА")
    self.title:SetColour(0.9, 0.7, 0.2, 1)

    -- Precision display
    self.lock_precision = 1.0 + math.random() * 0.8 -- 1.0 to 1.8 degrees
    self.precision_text = self.panel:AddChild(Text(CHATFONT, 18))
    self.precision_text:SetPosition(-130, 215)
    self.precision_text:SetString(string.format("Точность: %.1f°", self.lock_precision))
    self.precision_text:SetColour(0.7, 0.7, 0.7, 1)

    -- Instructions
    self.instructions = self.panel:AddChild(Text(CHATFONT, 20))
    self.instructions:SetPosition(0, 165)
    self.instructions:SetColour(0.8, 0.8, 0.8, 1)
    self.instructions:SetString("Найдите верную точку на шкале!")

    -- Close Button
    self.close_btn = self.panel:AddChild(ImageButton("images/global_redux.xml", "button_red.tex", "button_red_over.tex"))
    self.close_btn:SetPosition(0, -210)
    self.close_btn:SetText("Отмена")
    self.close_btn:SetOnClick(function()
        self:Close()
    end)

    -- Lock Dial (Keyhole) in the center
    self.keyhole = self.panel:AddChild(Image("images/scav_lock_keyhole.xml", "scav_lock_keyhole.tex"))
    self.keyhole:SetSize(200, 200)
    self.keyhole:SetPosition(0, -20)
    self.keyhole:SetRotation(0)

    -- Scale above the keyhole
    self.scale = self.panel:AddChild(Image("images/scav_lock_scale.xml", "scav_lock_scale.tex"))
    self.scale:SetSize(350, 135)
    self.scale:SetPosition(0, 110)

    -- Custom Hand Cursor
    self.hand_cursor = self.root:AddChild(Image("images/Arm-removebg-preview.xml", "Arm-removebg-preview.tex"))
    self.hand_cursor:SetVRegPoint(ANCHOR_BOTTOM)
    self.hand_cursor:SetHRegPoint(ANCHOR_MIDDLE)
    
    -- Hide hardware cursor and show custom cursor
    TheInputProxy:SetCursorVisible(false)
    self.hand_cursor:Show()

    -- Gameplay variables
    self.T_target = 0.1 + math.random() * 0.8 -- Hidden correct spot (from 10% to 90% of the arch)
    self.T_claw = 0.5
    self.cylinder_rotation = 0
    self.theta_max = 0
    self.shaking = false
    self.shake_damage_timer = 0
    self.unlocked = false
    self.last_click_state = false

    self:StartUpdating()
end)

function ScavLockpickScreen:OnUpdate(dt)
    -- Hide hardware cursor continuously
    TheInputProxy:SetCursorVisible(false)
    
    -- Get local mouse coordinates relative to panel center (0, 0)
    local w, h = TheSim:GetScreenSize()
    local mouse_pos = TheInput:GetScreenPosition()
    local scale = self.root:GetScale()
    local mx = (mouse_pos.x - w / 2) / scale.x
    local my = (mouse_pos.y - h / 2) / scale.y
    
    -- Calculate angle and distance relative to keyhole center (0, -20)
    local dx = mx
    local dy = my - (-20)
    
    -- When NOT holding LMB, claw follows mouse angle along the arch
    if not self.unlocked then
        if not TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
            local angle_rad = math.atan2(dy, dx)
            local angle_deg = angle_rad * 180 / math.pi
            local T_mouse = (180 - angle_deg) / 180
            self.T_claw = math.max(0.0, math.min(1.0, T_mouse))
        end
    end
    
    -- Position and rotate custom cursor (pointing towards keyhole center)
    local R = 155
    local draw_angle = 180 - (self.T_claw * 180)
    local draw_angle_rad = draw_angle * math.pi / 180
    local claw_x = R * math.cos(draw_angle_rad)
    local claw_y = -20 + R * math.sin(draw_angle_rad)
    
    -- Swap hand texture based on click state
    local is_clicked = TheInput:IsMouseDown(MOUSEBUTTON_LEFT)
    if is_clicked ~= self.last_click_state then
        self.last_click_state = is_clicked
        local cursor_name = is_clicked and "ArmFist-removebg-preview" or "Arm-removebg-preview"
        self.hand_cursor:SetTexture("images/"..cursor_name..".xml", cursor_name..".tex")
    end
    
    -- Position shoulder at the bottom of the screen (off-screen)
    local bottom_y = -h / (2 * scale.y)
    local shoulder_x = 0
    local shoulder_y = bottom_y - 20
    
    -- Vector from shoulder to claw position
    local arm_dx = claw_x - shoulder_x
    local arm_dy = claw_y - shoulder_y
    local arm_dist = math.sqrt(arm_dx * arm_dx + arm_dy * arm_dy)
    local arm_angle_rad = math.atan2(arm_dy, arm_dx)
    local arm_angle_deg = arm_angle_rad * 180 / math.pi
    
    self.hand_cursor:SetPosition(shoulder_x, shoulder_y)
    self.hand_cursor:SetRotation(arm_angle_deg - 90)
    
    local base_height = is_clicked and 341 or 339
    local target_scale_y = arm_dist / base_height
    local target_scale_x = 1.4 -- Make it look bigger!
    self.hand_cursor:SetScale(target_scale_x, target_scale_y)
    
    -- Game logic execution
    if is_clicked and not self.unlocked then
        -- Calculate theta_max for current T_claw
        local diff = math.abs(self.T_claw - self.T_target)
        local P = self.lock_precision / 180
        local D_max = 30 / 180 -- 30 degrees detection window
        
        if diff <= P then
            self.theta_max = 180
        elseif diff < D_max then
            local ratio = (diff - P) / (D_max - P)
            self.theta_max = 180 * (1.0 - ratio)
        else
            self.theta_max = 0
        end
        
        -- Rotate cylinder clockwise towards theta_max
        if self.cylinder_rotation < self.theta_max then
            self.cylinder_rotation = math.min(self.theta_max, self.cylinder_rotation + 120 * dt)
        end
        
        -- Jam and Shake behavior
        if self.cylinder_rotation >= self.theta_max and self.theta_max < 179.9 then
            self.shaking = true
            local shake = (math.random() * 2 - 1) * 3
            self.keyhole:SetPosition(shake, -20 + shake)
            
            self.shake_damage_timer = self.shake_damage_timer + dt
            self.instructions:SetString("ОПАСНО! Замок заклинило! Отпустите кнопку!")
            self.instructions:SetColour(1, 0.2, 0.2, 1)
            
            if self.shake_damage_timer >= 1.2 then
                -- Claws hurt/break
                self.owner.SoundEmitter:PlaySound("dontstarve/common/lightning_impact")
                SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickFail"), self.chest)
                self.shake_damage_timer = 0
                self.cylinder_rotation = 0
                self.shaking = false
                self.keyhole:SetPosition(0, -20)
            end
        else
            self.shaking = false
            self.keyhole:SetPosition(0, -20)
            self.shake_damage_timer = 0
            self.instructions:SetString("Поворачиваем замок...")
            self.instructions:SetColour(0.9, 0.7, 0.2, 1)
            
            -- Win check
            if self.cylinder_rotation >= 179.9 then
                self.unlocked = true
                self.keyhole:SetRotation(180) -- Facing straight down on success
                self.instructions:SetString("Замок успешно взломан!")
                self.instructions:SetColour(0.3, 0.9, 0.3, 1)
                self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
                
                SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickSuccess"), self.chest)
                
                self.inst:DoTaskInTime(0.5, function()
                    self:Close()
                end)
            end
        end
    else
        -- Decay rotation back to 0 when not holding click
        self.shaking = false
        self.keyhole:SetPosition(0, -20)
        self.shake_damage_timer = 0
        if not self.unlocked then
            self.cylinder_rotation = math.max(0, self.cylinder_rotation - 360 * dt)
            self.instructions:SetString("Найдите верную точку на шкале!")
            self.instructions:SetColour(0.8, 0.8, 0.8, 1)
        end
    end
    
    -- Apply rotation to keyhole widget
    if not self.unlocked then
        self.keyhole:SetRotation(self.cylinder_rotation)
    end
end

function ScavLockpickScreen:Close()
    TheInputProxy:SetCursorVisible(true)
    TheFrontEnd:PopScreen(self)
end

function ScavLockpickScreen:OnControl(control, down)
    if ScavLockpickScreen._base.OnControl(self, control, down) then return true end
    
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
    
    return true
end

return ScavLockpickScreen
