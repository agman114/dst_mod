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
    self.hand_cursor:SetScale(0.8, 0.8)
    self.hand_cursor:SetVRegPoint(ANCHOR_TOP)
    self.hand_cursor:SetHRegPoint(ANCHOR_MIDDLE)
    
    -- Hide hardware cursor and show custom cursor
    TheInputProxy:SetCursorVisible(false)
    self.hand_cursor:Show()

    -- Generate random correct index from 4 presets
    self.presets = { 2, 4, 7, 9 }
    self.correct_index = self.presets[math.random(1, #self.presets)]
    self.unlocked = false
    self.last_click_state = false

    -- Lay out 10 hitboxes along the arc of the scale
    self.hitboxes = {}
    local R = 155 -- Radius of the scale arc from keyhole center
    local start_angle = 145 * math.pi / 180
    local end_angle = 35 * math.pi / 180
    
    for i = 1, 10 do
        local t = (i - 1) / 9
        local angle = start_angle + t * (end_angle - start_angle)
        local x = R * math.cos(angle)
        local y = -20 + R * math.sin(angle)
        
        local btn = self.panel:AddChild(ImageButton("images/global.xml", "square.tex"))
        btn:SetPosition(x, y)
        btn:ForceImageSize(32, 32)
        btn.image:SetTint(0, 0, 0, 0) -- Invisible
        
        btn:SetOnClick(function()
            self:OnHitboxClicked(i)
        end)
        
        table.insert(self.hitboxes, btn)
    end

    self:StartUpdating()
end)

function ScavLockpickScreen:OnHitboxClicked(index)
    if self.unlocked then return end
    
    local C = self.correct_index
    local dist = math.abs(index - C)
    
    if dist == 0 then
        -- Success!
        self.unlocked = true
        self.keyhole:SetRotation(90)
        self.instructions:SetString("Замок успешно взломан!")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
        self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
        
        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickSuccess"), self.chest)
        
        self.panel:DoTaskInTime(0.5, function()
            self:Close()
        end)
    else
        -- Show feedback: keyhole rotates towards correct spot
        local angle = math.max(0, 90 - dist * 30)
        if C < index then
            angle = -angle -- Rotate counter-clockwise if correct spot is to the left
        end
        
        self.keyhole:SetRotation(angle)
        self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click")
        self.instructions:SetString("Замок сопротивляется...")
        self.instructions:SetColour(0.8, 0.8, 0.8, 1)
    end
end

function ScavLockpickScreen:OnUpdate(dt)
    -- Hide hardware cursor continuously
    TheInputProxy:SetCursorVisible(false)
    
    -- Position custom cursor
    local mouse_pos = TheInput:GetScreenPosition()
    local local_pos = self.root:GetLocalPosition(mouse_pos)
    self.hand_cursor:SetPosition(local_pos.x, local_pos.y)
    
    -- Swap hand texture based on click state
    local is_clicked = TheInput:IsMouseDown(MOUSEBUTTON_LEFT)
    if is_clicked ~= self.last_click_state then
        self.last_click_state = is_clicked
        local cursor_name = is_clicked and "ArmFist-removebg-preview" or "Arm-removebg-preview"
        self.hand_cursor:SetTexture("images/"..cursor_name..".xml", cursor_name..".tex")
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
