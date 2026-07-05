local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"

-- Helper to check and resolve custom UI assets with fallback support
local function GetUIAsset(name, fallback_atlas, fallback_tex)
    local xml_path = "images/"..name..".xml"
    local tex_path = name..".tex"
    if kleifileexists("mods/MEGACALLLMOD/"..xml_path) then
        return xml_path, tex_path, true
    end
    return fallback_atlas, fallback_tex, false
end

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
    self.instructions:SetPosition(0, 215)
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
    -- Coordinates, dimensions, and asset configuration for limbs
    self.limb_layout = {
        head = { x = 0, y = 140, w = 108, h = 94, asset = "Head", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        torso = { x = 0, y = 40, w = 83, h = 134, asset = "Body", fallback_atlas = "images/global_redux.xml", fallback_tex = "panel_blank.tex" },
        left_arm = { x = -125, y = 75, w = 207, h = 58, asset = "LHand", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        right_arm = { x = 125, y = 75, w = 207, h = 58, asset = "RHand", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        left_leg = { x = -30, y = -110, w = 67, h = 194, asset = "LLeg", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        right_leg = { x = 30, y = -110, w = 67, h = 194, asset = "RLeg", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
    }

    self.limb_buttons = {}
    self.limb_texts = {}

    for limb_name, data in pairs(self.limb_layout) do
        local atlas, tex, is_custom = GetUIAsset(data.asset, data.fallback_atlas, data.fallback_tex)
        local btn = self.panel:AddChild(ImageButton(atlas, tex, tex))
        btn:SetPosition(data.x, data.y)
        btn:ForceImageSize(data.w, data.h)
        btn:SetFocusScale(1.03, 1.03) -- Subtle pop on hover
        
        -- Text display below each limb showing health & status
        local btn_text = btn:AddChild(Text(NUMBERFONT, 18))
        -- Align text cleanly below the limb
        btn_text:SetPosition(0, -data.h/2 - 12)
        
        btn:SetOnClick(function()
            self:OnLimbClicked(limb_name)
        end)

        self.limb_buttons[limb_name] = btn
        self.limb_texts[limb_name] = btn_text
    end

    -- Circular wrapping variables & assets
    self.wrapping_active = false
    self.wrapping_limb = nil
    self.wrap_accumulated_angle = 0
    self.wrap_angle_prev = nil
    self.wrap_center_screen = { x = 0, y = 0 }

    -- Black circle (wrapping guide radius)
    local circle_atlas, circle_tex = GetUIAsset("Circle-removebg-preview", "images/global.xml", "square.tex")
    self.wrap_circle = self.panel:AddChild(Image(circle_atlas, circle_tex))
    self.wrap_circle:SetPosition(0, 40)
    self.wrap_circle:SetSize(220, 222)
    self.wrap_circle:Hide()

    -- White circle (bandage visual)
    local bandage_atlas, bandage_tex = GetUIAsset("Bondage-removebg-preview", "images/global_redux.xml", "button_square.tex")
    self.wrap_bandage = self.panel:AddChild(Image(bandage_atlas, bandage_tex))
    self.wrap_bandage:SetSize(40, 40)
    self.wrap_bandage:Hide()

    -- Custom Hand Cursor
    local cursor_atlas, cursor_tex = GetUIAsset("Arm-removebg-preview", "images/global_redux.xml", "button_square.tex")
    self.hand_cursor = self.root:AddChild(Image(cursor_atlas, cursor_tex))
    self.hand_cursor:SetScale(0.3, 0.3) -- Scale down large PNG hand asset
    self.hand_cursor:SetVRegPoint(ANCHOR_MIDDLE)
    self.hand_cursor:SetHRegPoint(ANCHOR_MIDDLE)

    -- Hide standard mouse cursor
    if TheFrontEnd then
        TheFrontEnd:ShowCursor(false)
    end

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
        local limb_asset = self.limb_layout[name].asset
        if btn and txt then
            local _, _, is_custom = GetUIAsset(limb_asset, "", "")
            if not is_custom then
                -- Text name on button only if custom silhouette assets are not loaded
                btn:SetText(limb_ru_names[name])
            else
                btn:SetText("")
            end
            txt:SetString(string.format("%d%% (%s)", data.health, data.status))
            txt:SetColour(data.colour[1], data.colour[2], data.colour[3], data.colour[4])
        end
    end
end

function ScavMedicalScreen:OnLimbClicked(limb_name)
    if self.wrapping_active then return end

    local inst = self.owner

    if self.item_type == "bandage" then
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

        -- Start wrapping minigame
        self.wrapping_active = true
        self.wrapping_limb = limb_name
        self.wrap_accumulated_angle = 0
        self.wrap_angle_prev = nil
        
        -- Temporarily hide limbs to focus visual on the wrapping game
        for _, btn in pairs(self.limb_buttons) do
            btn:Hide()
        end

        self.wrap_circle:Show()
        self.wrap_bandage:Show()
        
        -- Get screen space center of the wrapping circle (centered at torso center 0, 40)
        local panel_pos = self.panel:GetGlobalPosition()
        self.wrap_center_screen = { x = panel_pos.x, y = panel_pos.y + 40 }

        self.instructions:SetString("Зажмите мышь и водите бинт КРУГАМИ вокруг раны!")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
    
    elseif self.item_type == "splint" then
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

        self.instructions:SetString("Накладываем шину...")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
        
        self.owner:DoTaskInTime(1.5, function()
            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, limb_name)
            self:Close()
        end)
    
    elseif self.item_type == "antidote" then
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

function ScavMedicalScreen:OnUpdate(dt)
    self:UpdateLimbHealth()

    -- Follow mouse with custom hand cursor
    local mouse_pos = TheInput:GetScreenPosition()
    local local_mouse = self.root:GetLocalPosition(mouse_pos)
    self.hand_cursor:SetPosition(local_mouse.x, local_mouse.y)

    -- Toggle hand cursor texture on hold/click
    local is_clicked = TheInput:IsMouseDown(MOUSEBUTTON_LEFT)
    local cursor_name = is_clicked and "ArmFist-removebg-preview" or "Arm-removebg-preview"
    local cursor_atlas, cursor_tex = GetUIAsset(cursor_name, "images/global_redux.xml", "button_square.tex")
    self.hand_cursor:SetTexture(cursor_atlas, cursor_tex)

    if self.wrapping_active then
        local mouse_x = mouse_pos.x
        local mouse_y = mouse_pos.y

        if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
            -- Angle calculations relative to center of wrapping circle
            local dx = mouse_x - self.wrap_center_screen.x
            local dy = mouse_y - self.wrap_center_screen.y
            local dist = math.sqrt(dx*dx + dy*dy)

            -- Constrain bandage rotation radius to 110 pixels (matching Circle PNG radius)
            if dist > 20 and dist < 220 then
                local angle = math.atan2(dy, dx)
                
                -- Position bandage visual along the circle path
                local bx = 110 * math.cos(angle)
                local by = 40 + 110 * math.sin(angle)
                self.wrap_bandage:SetPosition(bx, by)

                if self.wrap_angle_prev then
                    local diff = angle - self.wrap_angle_prev
                    while diff > math.pi do diff = diff - 2*math.pi end
                    while diff < -math.pi do diff = diff + 2*math.pi end

                    self.wrap_accumulated_angle = self.wrap_accumulated_angle + diff
                    
                    local progress = math.min(100, math.floor(math.abs(self.wrap_accumulated_angle) / (3 * 2 * math.pi) * 100))
                    self.instructions:SetString(string.format("Намотка бинта: %d%%", progress))

                    -- 3 rotations completed
                    if math.abs(self.wrap_accumulated_angle) >= (3 * 2 * math.pi) then
                        self.wrapping_active = false
                        self.wrap_circle:Hide()
                        self.wrap_bandage:Hide()
                        self.instructions:SetString("Перевязка завершена!")
                        self.owner.SoundEmitter:PlaySound("dontstarve/common/cloth_rippage")

                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, self.wrapping_limb)
                        self:Close()
                    end
                end
                self.wrap_angle_prev = angle
            end
        else
            self.wrap_angle_prev = nil
            self.wrap_accumulated_angle = math.max(0, self.wrap_accumulated_angle - dt * 2.0)
            self.instructions:SetString("Зажмите мышь для намотки!")
            self.instructions:SetColour(1, 0.5, 0.5, 1)
        end
    end
end

function ScavMedicalScreen:Close()
    self.wrapping_active = false
    if TheFrontEnd then
        TheFrontEnd:ShowCursor(true) -- Restore hardware cursor
    end
    TheFrontEnd:PopScreen(self)
end

function ScavMedicalScreen:OnControl(control, down)
    if ScavMedicalScreen._base.OnControl(self, control, down) then return true end
    
    -- Escape/Cancel control closes the menu
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
    
    return true
end

return ScavMedicalScreen
