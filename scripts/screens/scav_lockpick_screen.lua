local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"

local ScavLockpickScreen = Class(Screen, function(self, owner, chest)
    Screen._ctor(self, "ScavLockpickScreen")
    
    self.owner = owner
    self.chest = chest
    self.lock_type = chest.scav_lock_type and chest.scav_lock_type:value() or 0 -- 0: Hotspot, 1: Keypad

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
    self.title:SetString(self.lock_type == 0 and "ВЗЛОМ ОТМЫЧКОЙ" or "КОДОВЫЙ ЗАМОК")
    self.title:SetColour(0.9, 0.7, 0.2, 1)

    -- Instructions
    self.instructions = self.panel:AddChild(Text(CHATFONT, 20))
    self.instructions:SetPosition(0, 160)
    self.instructions:SetColour(0.8, 0.8, 0.8, 1)

    -- Close Button
    self.close_btn = self.panel:AddChild(ImageButton("images/global_redux.xml", "button_red.tex", "button_red_over.tex"))
    self.close_btn:SetPosition(0, -210)
    self.close_btn:SetText("Отмена")
    self.close_btn:SetOnClick(function()
        self:Close()
    end)

    if self.lock_type == 0 then
        self:SetupHotspotGame()
    else
        self:SetupKeypadGame()
    end

    self:StartUpdating()
end)

--------------------------------------------------------------------------------
-- HOTSPOT LOCKPICK GAME (Locktype 0)
--------------------------------------------------------------------------------
function ScavLockpickScreen:SetupHotspotGame()
    self.instructions:SetString("Найдите верную точку. Держитесь дальше от ОПАСНЫХ ЗОН!")
    
    -- Draw a lock dial circle
    self.dial = self.panel:AddChild(Image("images/global_redux.xml", "warden_alert_base.tex"))
    self.dial:SetSize(240, 240)
    self.dial:SetPosition(0, -10)
    self.dial:SetTint(0.2, 0.2, 0.2, 1)

    -- Picker cursor overlay
    self.hand_pointer = self.panel:AddChild(Image("images/global_redux.xml", "pointer.tex"))
    self.hand_pointer:SetSize(40, 40)
    self.hand_pointer:Hide()

    -- Generate a secret correct angle (in radians)
    self.correct_angle = (math.random() * 2 * math.pi) - math.pi
    self.angle_tolerance = 0.18 -- tolerance in radians (~10 degrees)

    -- Threat timing
    self.wrong_zone_timer = 0
    self.in_wrong_zone = false

    -- Interactive click area overlay
    self.click_area = self.panel:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.click_area:SetPosition(0, -10)
    self.click_area:SetSize(240, 240)
    self.click_area:SetTextures("images/global.xml", "square.tex", "square.tex", "square.tex", "square.tex", "square.tex")
    self.click_area.image:SetTint(0, 0, 0, 0) -- invisible button

    self.click_area:SetOnClick(function()
        -- Handle individual clicks on the dial
        local mouse_pos = TheInput:GetScreenPosition()
        local dial_pos = self.dial:GetWorldPosition()
        
        local dx = mouse_pos.x - dial_pos.x
        local dy = mouse_pos.y - dial_pos.y
        local click_angle = math.atan2(dy, dx)

        local angle_diff = math.abs(click_angle - self.correct_angle)
        while angle_diff > math.pi do angle_diff = angle_diff - 2*math.pi end
        angle_diff = math.abs(angle_diff)

        if angle_diff <= self.angle_tolerance then
            -- Success!
            self.instructions:SetString("Замок открыт!")
            self.instructions:SetColour(0.3, 0.9, 0.3, 1)
            self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickSuccess"), self.chest)
            self:Close()
        else
            -- Clicked wrong spot, trigger click sound
            self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click")
        end
    end)
end

function ScavLockpickScreen:UpdateHotspotGame(dt)
    if not self.dial then return end

    -- Check if mouse is hovering and holding click in a dangerous zone
    local mouse_pos = TheInput:GetScreenPosition()
    local dial_pos = self.dial:GetWorldPosition()
    local dx = mouse_pos.x - dial_pos.x
    local dy = mouse_pos.y - dial_pos.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist <= 120 then
        -- Draw custom pointer at cursor position inside dial
        local local_mouse = self.panel:GetLocalPosition(mouse_pos)
        self.hand_pointer:Show()
        self.hand_pointer:SetPosition(local_mouse.x, local_mouse.y)

        if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
            local click_angle = math.atan2(dy, dx)
            local angle_diff = math.abs(click_angle - self.correct_angle)
            while angle_diff > math.pi do angle_diff = angle_diff - 2*math.pi end
            angle_diff = math.abs(angle_diff)

            -- If NOT in sweet spot, player is in the WRONG zone
            if angle_diff > self.angle_tolerance then
                self.in_wrong_zone = true
                self.wrong_zone_timer = self.wrong_zone_timer + dt

                self.instructions:SetString(string.format("ОПАСНОСТЬ! Перестаньте жать через %.1f сек!", math.max(0, 2.0 - self.wrong_zone_timer)))
                self.instructions:SetColour(1, 0.2, 0.2, 1)

                if self.wrong_zone_timer >= 2.0 then
                    -- Trigger electric shock damage on server
                    self.instructions:SetString("Замок заблокирован! Урон током!")
                    self.owner.SoundEmitter:PlaySound("dontstarve/common/lightning_impact")
                    SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickFail"), self.chest)
                    self:Close()
                end
            else
                self.in_wrong_zone = false
                self.wrong_zone_timer = 0
                self.instructions:SetString("Почти нащупали... Отпустите и кликните!")
                self.instructions:SetColour(0.3, 0.9, 0.3, 1)
            end
        else
            -- Mouse not pressed, cool down danger timer
            self.in_wrong_zone = false
            self.wrong_zone_timer = 0
            self.instructions:SetString("Найдите верную точку. Держитесь дальше от ОПАСНЫХ ЗОН!")
            self.instructions:SetColour(0.8, 0.8, 0.8, 1)
        end
    else
        self.hand_pointer:Hide()
        self.in_wrong_zone = false
        self.wrong_zone_timer = 0
    end
end

--------------------------------------------------------------------------------
-- KEYPAD GAME (Locktype 1)
--------------------------------------------------------------------------------
function ScavLockpickScreen:SetupKeypadGame()
    -- Generate 4-digit code
    self.secret_code = {}
    for i = 1, 4 do
        table.insert(self.secret_code, math.random(0, 9))
    end
    
    self.code_string = table.concat(self.secret_code)
    self.instructions:SetString("ВВЕДИТЕ КОД: " .. self.code_string)

    self.player_input = {}
    self.keypad_buttons = {}

    -- Grid coordinates for 0-9 buttons
    local button_coords = {
        { x = -60, y = 60, val = 1 }, { x = 0, y = 60, val = 2 }, { x = 60, y = 60, val = 3 },
        { x = -60, y = 0, val = 4 },  { x = 0, y = 0, val = 5 },  { x = 60, y = 0, val = 6 },
        { x = -60, y = -60, val = 7 }, { x = 0, y = -60, val = 8 }, { x = 60, y = -60, val = 9 },
        { x = 0, y = -120, val = 0 }
    }

    for _, coord in ipairs(button_coords) do
        local btn = self.panel:AddChild(ImageButton("images/global_redux.xml", "button_square.tex", "button_square_over.tex"))
        btn:SetPosition(coord.x, coord.y - 20)
        btn:ForceImageSize(50, 50)
        btn:SetText(tostring(coord.val))
        
        btn:SetOnClick(function()
            self:OnKeypadPressed(coord.val)
        end)
        
        table.insert(self.keypad_buttons, btn)
    end

    -- Indicator display text
    self.code_display = self.panel:AddChild(Text(TITLEFONT, 28))
    self.code_display:SetPosition(0, 110)
    self.code_display:SetString("ВВОД: _ _ _ _")
    self.code_display:SetColour(0.8, 0.8, 0.8, 1)
end

function ScavLockpickScreen:OnKeypadPressed(val)
    self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click")
    
    local index = #self.player_input + 1
    
    -- Check if correct digit
    if val == self.secret_code[index] then
        table.insert(self.player_input, val)
        
        -- Update indicator display
        local display_str = {}
        for i = 1, 4 do
            if self.player_input[i] ~= nil then
                table.insert(display_str, tostring(self.player_input[i]))
            else
                table.insert(display_str, "_")
            end
        end
        self.code_display:SetString("ВВОД: " .. table.concat(display_str, " "))
        
        -- Check if code fully entered
        if #self.player_input == 4 then
            self.instructions:SetString("Код верный!")
            self.instructions:SetColour(0.3, 0.9, 0.3, 1)
            self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "LockpickSuccess"), self.chest)
            self:Close()
        end
    else
        -- Wrong digit resets progress
        self.player_input = {}
        self.code_display:SetString("ОШИБКА! ВВОД: _ _ _ _")
        self.owner.SoundEmitter:PlaySound("dontstarve/HUD/click_disable")
    end
end

--------------------------------------------------------------------------------
-- FRAME UPDATE
--------------------------------------------------------------------------------
function ScavLockpickScreen:OnUpdate(dt)
    if self.lock_type == 0 then
        self:UpdateHotspotGame(dt)
    end
end

function ScavLockpickScreen:Close()
    TheFrontEnd:PopScreen(self)
end

function ScavLockpickScreen:OnControl(control, down)
    if ScavLockpickScreen._base.OnControl(self, control, down) then return true end
    
    -- Escape/Cancel control closes the menu
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
    
    return true
end

return ScavLockpickScreen
