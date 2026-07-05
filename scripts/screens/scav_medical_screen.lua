local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"

local ScavMedicalScreen = Class(Screen, function(self, owner, item)
    Screen._ctor(self, "ScavMedicalScreen")
    
    self.owner = owner
    self.item = item -- The item inst (bandage, splint, antidote)
    self.item_type = item.scav_medical_type or "bandage"

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
    self.black:SetTint(0, 0, 0, 0.65)

    -- Main Panel
    self.panel = self.root:AddChild(Image("images/global_redux.xml", "panel_blank.tex"))
    self.panel:SetSize(550, 600)

    -- Title
    self.title = self.panel:AddChild(Text(TITLEFONT, 32))
    self.title:SetPosition(0, 250)
    self.title:SetString("МЕДИЦИНСКИЙ ОСМОТР")
    self.title:SetColour(0.9, 0.3, 0.3, 1)

    -- Instruction text
    self.instructions = self.panel:AddChild(Text(CHATFONT, 20))
    self.instructions:SetPosition(0, 210)
    self.instructions:SetString("Выберите поврежденную конечность для лечения")
    self.instructions:SetColour(0.8, 0.8, 0.8, 1)

    -- Close Button
    self.close_btn = self.panel:AddChild(ImageButton("images/global_redux.xml", "button_red.tex", "button_red_over.tex"))
    self.close_btn:SetPosition(0, -250)
    self.close_btn:SetText("Закрыть")
    self.close_btn:SetOnClick(function()
        self:Close()
    end)

    -- Draw Body Silhouette
    -- Center coords for each limb in panel space
    self.limb_centers = {
        head = { x = 0, y = 110 },
        torso = { x = 0, y = 20 },
        left_arm = { x = -90, y = 30 },
        right_arm = { x = 90, y = 30 },
        left_leg = { x = -45, y = -90 },
        right_leg = { x = 45, y = -90 },
    }

    self.limb_buttons = {}
    self.limb_texts = {}

    -- Safe textures for limbs (falls back to generic UI assets if custom ones aren't built)
    local use_custom_assets = false -- set true when compiled XML/TEX exist

    for limb_name, coords in pairs(self.limb_centers) do
        -- Add interactive button for each limb
        local btn = self.panel:AddChild(ImageButton("images/global_redux.xml", "button_square.tex", "button_square_over.tex"))
        btn:SetPosition(coords.x, coords.y)
        btn:ForceImageSize(80, 80)
        
        -- Text inside the button showing health
        local btn_text = btn:AddChild(Text(NUMBERFONT, 20))
        btn_text:SetPosition(0, -35)
        
        btn:SetOnClick(function()
            self:OnLimbClicked(limb_name)
        end)

        self.limb_buttons[limb_name] = btn
        self.limb_texts[limb_name] = btn_text
    end

    -- Circular wrapping variables
    self.wrapping_active = false
    self.wrapping_limb = nil
    self.wrap_accumulated_angle = 0
    self.wrap_angle_prev = nil
    self.wrap_center_screen = { x = 0, y = 0 }

    -- Visual hand indicator for wrapping
    self.hand_visual = self.panel:AddChild(Image("images/global_redux.xml", "pointer.tex"))
    self.hand_visual:Hide()
    self.hand_visual:SetSize(40, 40)

    self:UpdateLimbHealth()
    self:StartUpdating()
end)

-- Read network variables on the character to update UI health
function ScavMedicalScreen:UpdateLimbHealth()
    local inst = self.owner
    if not inst then return end

    local health_data = {
        head = { 
            health = inst.scav_limb_head and inst.scav_limb_head:value() or 100, 
            status = "ОК",
            colour = { 1, 1, 1, 1 }
        },
        torso = { 
            health = inst.scav_limb_torso and inst.scav_limb_torso:value() or 100, 
            status = inst.scav_bleeding_torso and inst.scav_bleeding_torso:value() and "Кровотечение" or "ОК",
            colour = inst.scav_bleeding_torso and inst.scav_bleeding_torso:value() and { 1, 0.2, 0.2, 1 } or { 1, 1, 1, 1 }
        },
        left_arm = { 
            health = inst.scav_limb_left_arm and inst.scav_limb_left_arm:value() or 100, 
            status = inst.scav_broken_left_arm and inst.scav_broken_left_arm:value() and "Перелом" or "ОК",
            colour = inst.scav_broken_left_arm and inst.scav_broken_left_arm:value() and { 1, 0.5, 0, 1 } or { 1, 1, 1, 1 }
        },
        right_arm = { 
            health = inst.scav_limb_right_arm and inst.scav_limb_right_arm:value() or 100, 
            status = inst.scav_broken_right_arm and inst.scav_broken_right_arm:value() and "Перелом" or "ОК",
            colour = inst.scav_broken_right_arm and inst.scav_broken_right_arm:value() and { 1, 0.5, 0, 1 } or { 1, 1, 1, 1 }
        },
        left_leg = { 
            health = inst.scav_limb_left_leg and inst.scav_limb_left_leg:value() or 100, 
            status = inst.scav_broken_left_leg and inst.scav_broken_left_leg:value() and "Перелом" or "ОК",
            colour = inst.scav_broken_left_leg and inst.scav_broken_left_leg:value() and { 1, 0.5, 0, 1 } or { 1, 1, 1, 1 }
        },
        right_leg = { 
            health = inst.scav_limb_right_leg and inst.scav_limb_right_leg:value() or 100, 
            status = inst.scav_broken_right_leg and inst.scav_broken_right_leg:value() and "Перелом" or "ОК",
            colour = inst.scav_broken_right_leg and inst.scav_broken_right_leg:value() and { 1, 0.5, 0, 1 } or { 1, 1, 1, 1 }
        },
    }

    local limb_ru_names = {
        head = "Голова",
        torso = "Торс",
        left_arm = "Л. Рука",
        right_arm = "П. Рука",
        left_leg = "Л. Нога",
        right_leg = "П. Нога",
    }

    for name, data in pairs(health_data) do
        local btn = self.limb_buttons[name]
        local txt = self.limb_texts[name]
        if btn and txt then
            btn:SetText(limb_ru_names[name])
            txt:SetString(string.format("%d%% (%s)", data.health, data.status))
            txt:SetColour(data.colour[1], data.colour[2], data.colour[3], data.colour[4])
        end
    end
end

function ScavMedicalScreen:OnLimbClicked(limb_name)
    if self.wrapping_active then return end

    local inst = self.owner

    if self.item_type == "bandage" then
        -- Bandaging bleeding limbs
        local is_bleeding = false
        if limb_name == "torso" and inst.scav_bleeding_torso and inst.scav_bleeding_torso:value() then is_bleeding = true
        elseif limb_name == "left_arm" and inst.scav_bleeding_left_arm and inst.scav_bleeding_left_arm:value() then is_bleeding = true
        elseif limb_name == "right_arm" and inst.scav_bleeding_right_arm and inst.scav_bleeding_right_arm:value() then is_bleeding = true
        elseif limb_name == "left_leg" and inst.scav_bleeding_left_leg and inst.scav_bleeding_left_leg:value() then is_bleeding = true
        elseif limb_name == "right_leg" and inst.scav_bleeding_right_leg and inst.scav_bleeding_right_leg:value() then is_bleeding = true
        end

        if not is_bleeding then
            self.instructions:SetString("Конечность не кровоточит! Бинт не нужен.")
            self.instructions:SetColour(1, 0.3, 0.3, 1)
            return
        end

        -- Start the circular wrapping minigame
        self.wrapping_active = true
        self.wrapping_limb = limb_name
        self.wrap_accumulated_angle = 0
        self.wrap_angle_prev = nil
        
        -- Get screen space center of the clicked button
        local button = self.limb_buttons[limb_name]
        local screen_pos = button:GetGlobalPosition()
        self.wrap_center_screen = screen_pos

        self.instructions:SetString("Зажмите мышь и водите КРУГАМИ вокруг раны!")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)

        self.hand_visual:Show()
        self.hand_visual:SetPosition(button:GetPosition())
    
    elseif self.item_type == "splint" then
        -- Splint fixes fractures
        local is_broken = false
        if limb_name == "left_arm" and inst.scav_broken_left_arm and inst.scav_broken_left_arm:value() then is_broken = true
        elseif limb_name == "right_arm" and inst.scav_broken_right_arm and inst.scav_broken_right_arm:value() then is_broken = true
        elseif limb_name == "left_leg" and inst.scav_broken_left_leg and inst.scav_broken_left_leg:value() then is_broken = true
        elseif limb_name == "right_leg" and inst.scav_broken_right_leg and inst.scav_broken_right_leg:value() then is_broken = true
        end

        if not is_broken then
            self.instructions:SetString("Конечность цела! Шина не нужна.")
            self.instructions:SetColour(1, 0.3, 0.3, 1)
            return
        end

        -- Splint is a simple hold action (QTE)
        self.instructions:SetString("Накладываем шину...")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
        
        self.owner:DoTaskInTime(1.5, function()
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, limb_name)
            self:Close()
        end)
    
    elseif self.item_type == "antidote" then
        -- Antidote can be applied anywhere to cure poison
        if not inst.scav_poisoned or not inst.scav_poisoned:value() then
            self.instructions:SetString("Вы не отравлены! Шприц не нужен.")
            self.instructions:SetColour(1, 0.3, 0.3, 1)
            return
        end

        self.instructions:SetString("Вкалываем противоядие...")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
        
        self.owner:DoTaskInTime(1.0, function()
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, limb_name)
            self:Close()
        end)
    end
end

-- Frame update loop to handle mouse tracking in the wrapping minigame
function ScavMedicalScreen:OnUpdate(dt)
    self:UpdateLimbHealth()

    if self.wrapping_active then
        -- Track the mouse position
        local mouse_pos = TheInput:GetScreenPosition()
        local mouse_x = mouse_pos.x
        local mouse_y = mouse_pos.y

        -- Position visual indicator relative to the panel
        local local_mouse = self.panel:GetLocalPosition(mouse_pos)
        self.hand_visual:SetPosition(local_mouse.x, local_mouse.y)

        -- If player is holding LMB down
        if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
            -- Calculate angle relative to center of the wrapping limb
            local dx = mouse_x - self.wrap_center_screen.x
            local dy = mouse_y - self.wrap_center_screen.y
            local dist = math.sqrt(dx*dx + dy*dy)

            -- Player needs to move in a reasonable circle radius (e.g., between 20 and 150 pixels)
            if dist > 20 and dist < 200 then
                local angle = math.atan2(dy, dx)
                
                if self.wrap_angle_prev then
                    local diff = angle - self.wrap_angle_prev
                    
                    -- Normalize difference to [-pi, pi]
                    while diff > math.pi do diff = diff - 2*math.pi end
                    while diff < -math.pi do diff = diff + 2*math.pi end

                    -- Accumulate the angle change
                    self.wrap_accumulated_angle = self.wrap_accumulated_angle + diff
                    
                    local progress = math.min(100, math.floor(math.abs(self.wrap_accumulated_angle) / (3 * 2 * math.pi) * 100))
                    self.instructions:SetString(string.format("Намотка бинта: %d%%", progress))

                    -- 3 full rotations completed
                    if math.abs(self.wrap_accumulated_angle) >= (3 * 2 * math.pi) then
                        self.wrapping_active = false
                        self.hand_visual:Hide()
                        self.instructions:SetString("Перевязка завершена!")
                        self.owner.SoundEmitter:PlaySound("dontstarve/common/cloth_rippage")

                        -- Tell server to apply the heal
                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, self.wrapping_limb)
                        self:Close()
                    end
                end
                self.wrap_angle_prev = angle
            end
        else
            -- If player releases LMB, reset rotation progress slightly
            self.wrap_angle_prev = nil
            self.wrap_accumulated_angle = math.max(0, self.wrap_accumulated_angle - dt * 2.0)
            self.instructions:SetString("Зажмите мышь для намотки!")
            self.instructions:SetColour(1, 0.5, 0.5, 1)
        end
    end
end

function ScavMedicalScreen:Close()
    self.wrapping_active = false
    TheFrontEnd:PopScreen(self)
end

function ScavMedicalScreen:OnControl(control, down)
    if ScavMedicalScreen._base.OnControl(self, control, down) then return true end
    
    -- Escape/Cancel control closes the menu
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
    
    -- Block standard clicks from interacting with the background world while screen is open
    return true
end

return ScavMedicalScreen
