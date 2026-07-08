local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"

local function FormatCode(str)
    if not str or str == "" then return "" end
    local chars = {}
    for i = 1, #str do
        table.insert(chars, str:sub(i, i))
    end
    return table.concat(chars, "-")
end

local ScavKeypadScreen = Class(Screen, function(self, owner, chest)
    Screen._ctor(self, "ScavKeypadScreen")
    
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
    self.panel:SetSize(500, 550)

    -- Instructional Heading
    self.heading = self.panel:AddChild(Text(TITLEFONT, 28))
    self.heading:SetPosition(0, 210)
    self.heading:SetString("Match the code to open.")
    self.heading:SetColour(1, 1, 1, 1)

    -- Target Code Box
    self.target_box = self.panel:AddChild(Image("images/scav_pinpad.xml", "scav_pinpad_enterpod.tex"))
    self.target_box:SetSize(350, 70)
    self.target_box:SetPosition(0, 130)

    -- Target Code Text
    self.target_code = ""
    for i = 1, 10 do
        self.target_code = self.target_code .. tostring(math.random(0, 9))
    end

    self.target_code_text = self.panel:AddChild(Text(CHATFONT, 26))
    self.target_code_text:SetPosition(0, 130)
    self.target_code_text:SetString(FormatCode(self.target_code))
    self.target_code_text:SetColour(1, 1, 1, 1)

    -- Player Input Box
    self.input_box = self.panel:AddChild(Image("images/scav_pinpad.xml", "scav_pinpad_enterpod.tex"))
    self.input_box:SetSize(270, 70)
    self.input_box:SetPosition(-40, 40)

    -- Player Input Text
    self.entered_code = ""
    self.player_input_text = self.panel:AddChild(Text(CHATFONT, 26))
    self.player_input_text:SetPosition(-40, 40)
    self.player_input_text:SetString("")
    self.player_input_text:SetColour(1, 1, 1, 1)

    -- Clear Button ("C")
    self.clear_btn = self.panel:AddChild(ImageButton("images/scav_pinpad.xml", "scav_pinpad_clear.tex"))
    self.clear_btn:SetPosition(130, 40)
    self.clear_btn:SetScale(0.95, 0.95)
    self.clear_btn:SetOnClick(function()
        if not self.unlocked and not self.input_blocked then
            self.entered_code = ""
            self.player_input_text:SetString("")
            self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click")
        end
    end)

    -- Grid of numeric keys
    -- Row 1: 1, 2, 3, 4, 5
    -- Row 2: 6, 7, 8, 9, 0
    local keys_row1 = { 1, 2, 3, 4, 5 }
    local keys_row2 = { 6, 7, 8, 9, 0 }
    
    local start_x = -180
    local step_x = 90
    
    self.buttons = {}
    
    -- Lay out Row 1
    for i, num in ipairs(keys_row1) do
        local x = start_x + (i - 1) * step_x
        local y = -60
        local btn = self.panel:AddChild(ImageButton("images/scav_pinpad.xml", "scav_pinpad_"..num..".tex"))
        btn:SetPosition(x, y)
        btn:SetScale(0.87, 0.87)
        btn:SetOnClick(function()
            self:PressNum(num)
        end)
        table.insert(self.buttons, btn)
    end

    -- Lay out Row 2
    for i, num in ipairs(keys_row2) do
        local x = start_x + (i - 1) * step_x
        local y = -160
        local btn = self.panel:AddChild(ImageButton("images/scav_pinpad.xml", "scav_pinpad_"..num..".tex"))
        btn:SetPosition(x, y)
        btn:SetScale(0.87, 0.87)
        btn:SetOnClick(function()
            self:PressNum(num)
        end)
        table.insert(self.buttons, btn)
    end

    -- Exit prompt
    self.exit_prompt = self.panel:AddChild(Text(CHATFONT, 20))
    self.exit_prompt:SetPosition(0, -225)
    self.exit_prompt:SetString("Press RMB/ESC to exit")
    self.exit_prompt:SetColour(0.6, 0.6, 0.6, 1)

    -- Custom Hand Cursor
    self.hand_cursor = self.root:AddChild(Image("images/Arm-removebg-preview.xml", "Arm-removebg-preview.tex"))
    self.hand_cursor:SetVRegPoint(ANCHOR_BOTTOM)
    self.hand_cursor:SetHRegPoint(ANCHOR_MIDDLE)
    
    -- Hide hardware cursor and show custom cursor
    TheInputProxy:SetCursorVisible(false)
    self.hand_cursor:Show()

    self.unlocked = false
    self.input_blocked = false

    self:StartUpdating()
end)

function ScavKeypadScreen:PressNum(num)
    if self.unlocked or self.input_blocked then return end
    if #self.entered_code >= 10 then return end
    
    self.entered_code = self.entered_code .. tostring(num)
    self.player_input_text:SetString(FormatCode(self.entered_code))
    self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click")
    
    if #self.entered_code == 10 then
        if self.entered_code == self.target_code then
            -- Win/Unlock!
            self.unlocked = true
            self.player_input_text:SetColour(0.3, 0.9, 0.3, 1)
            self.player_input_text:SetString("CODE MATCHED!")
            self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
            
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickSuccess"), self.chest)
            
            self.inst:DoTaskInTime(0.6, function()
                self:Close()
            end)
        else
            -- Fail!
            self.input_blocked = true
            self.player_input_text:SetColour(1, 0.2, 0.2, 1)
            self.player_input_text:SetString("ERROR!")
            self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click_disable")
            
            self.inst:DoTaskInTime(0.6, function()
                self.entered_code = ""
                self.player_input_text:SetString("")
                self.player_input_text:SetColour(1, 1, 1, 1)
                self.input_blocked = false
            end)
        end
    end
end

function ScavKeypadScreen:OnUpdate(dt)
    -- Hide hardware cursor continuously
    TheInputProxy:SetCursorVisible(false)
    
    -- Get local mouse coordinates relative to panel center (0, 0)
    local w, h = TheSim:GetScreenSize()
    local mouse_pos = TheInput:GetScreenPosition()
    local scale = self.root:GetScale()
    local local_x = (mouse_pos.x - w / 2) / scale.x
    local local_y = (mouse_pos.y - h / 2) / scale.y
    
    -- Handle mouse button state for cursor swap
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
    
    -- Vector from shoulder to mouse position
    local arm_dx = local_x - shoulder_x
    local arm_dy = local_y - shoulder_y
    local arm_dist = math.sqrt(arm_dx * arm_dx + arm_dy * arm_dy)
    local arm_angle_rad = math.atan2(arm_dy, arm_dx)
    local arm_angle_deg = arm_angle_rad * 180 / math.pi
    
    self.hand_cursor:SetPosition(shoulder_x, shoulder_y)
    self.hand_cursor:SetRotation(90 - arm_angle_deg)
    
    local base_height = is_clicked and 341 or 339
    local target_scale_y = arm_dist / base_height
    local target_scale_x = 1.4 -- Make it look bigger!
    self.hand_cursor:SetScale(target_scale_x, target_scale_y)
end

function ScavKeypadScreen:Close()
    TheInputProxy:SetCursorVisible(true)
    TheFrontEnd:PopScreen(self)
end

function ScavKeypadScreen:OnControl(control, down)
    if ScavKeypadScreen._base.OnControl(self, control, down) then return true end
    
    if not down and (control == CONTROL_CANCEL or control == CONTROL_SECONDARY) then
        self:Close()
        return true
    end
    
    return true
end

return ScavKeypadScreen
