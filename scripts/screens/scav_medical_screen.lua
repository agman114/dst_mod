local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

-- Helper to resolve custom UI assets directly (statically registered in modmain)
local function GetUIAsset(name, fallback_atlas, fallback_tex)
    return "images/"..name..".xml", name..".tex", true
end

-- Helper to find a medical item in player inventory, active cursor, or open containers (backpacks)
local function FindMedicalItem(owner, type)
    if not owner or not owner.components.inventory then return nil end
    local prefab = "scav_" .. type
    
    -- 1. Check hand cursor active item
    local active = owner.components.inventory:GetActiveItem()
    if active and active.prefab == prefab then
        return active
    end
    
    -- 2. Check main inventory slots
    local items = owner.components.inventory.itemslots
    if items then
        for _, item in pairs(items) do
            if item and item.prefab == prefab then
                return item
            end
        end
    end
    
    -- 3. Check container items (like backpacks)
    for _, container in pairs(owner.components.inventory.opencontainers or {}) do
        if container and container.components.container then
            local c_items = container.components.container.slots
            if c_items then
                for _, item in pairs(c_items) do
                    if item and item.prefab == prefab then
                        return item
                    end
                end
            end
        end
    end
    
    return nil
end

local ScavMedicalScreen = Class(Screen, function(self, owner, item)
    Screen._ctor(self, "ScavMedicalScreen")
    
    self.owner = owner
    self.item = item -- The item inst (bandage, splint, antidote)
    self.item_type = item and item.scav_medical_type or nil

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
    local btn_atlas = "images/global_redux.xml"
    local close_btn_normal = "button_red.tex"
    local ImageButton = require "widgets/imagebutton"
    self.close_btn = self.panel:AddChild(ImageButton(btn_atlas, close_btn_normal, "button_red_over.tex"))
    self.close_btn:SetPosition(0, -250)
    self.close_btn:SetText("Закрыть")
    self.close_btn:SetOnClick(function()
        self:Close()
    end)

    -- Draw Body Silhouette
    self.limb_layout = {
        head = { x = 0, y = 140, w = 108, h = 94, asset = "Head", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        torso = { x = 0, y = 40, w = 83, h = 134, asset = "Body", fallback_atlas = "images/global_redux.xml", fallback_tex = "panel_blank.tex" },
        left_arm = { x = -125, y = 75, w = 207, h = 58, asset = "LHand", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        right_arm = { x = 125, y = 75, w = 207, h = 58, asset = "RHand", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        left_leg = { x = -30, y = -110, w = 67, h = 194, asset = "LLeg", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
        right_leg = { x = 30, y = -110, w = 67, h = 194, asset = "RLeg", fallback_atlas = "images/global_redux.xml", fallback_tex = "button_square.tex" },
    }

    self.limb_images = {}
    self.limb_texts = {}
    self.limb_bleed_icons = {}
    self.limb_bone_icons = {}

    -- 1. Create limb images first so they render under texts/icons
    for limb_name, data in pairs(self.limb_layout) do
        local atlas, tex = GetUIAsset(data.asset, data.fallback_atlas, data.fallback_tex)
        local img = self.panel:AddChild(Image(atlas, tex))
        img:SetPosition(data.x, data.y)
        img:SetSize(data.w, data.h)
        
        -- Hover scale feedback
        img.OnGainFocus = function(widget)
            widget:SetScale(1.05, 1.05)
        end
        img.OnLoseFocus = function(widget)
            widget:SetScale(1, 1)
        end
        
        -- Click handler
        img.OnMouseButton = function(widget, button, down, x, y)
            if not down and button == MOUSEBUTTON_LEFT then
                self:OnLimbClicked(limb_name)
                return true
            end
        end
        
        self.limb_images[limb_name] = img
    end

    -- 2. Create texts and icons second so they are drawn on top
    for limb_name, data in pairs(self.limb_layout) do
        -- Text display below each limb showing health & status
        local btn_text = self.panel:AddChild(Text(NUMBERFONT, 18))
        btn_text:SetPosition(data.x, data.y - data.h/2 - 12)
        self.limb_texts[limb_name] = btn_text

        -- Position the icons in a smart way based on limb layout
        local bleed_x, bleed_y, bone_x, bone_y
        if limb_name == "left_arm" then
            bleed_x, bleed_y = data.x - 30, data.y + 10
            bone_x, bone_y = data.x - 60, data.y + 10
        elseif limb_name == "right_arm" then
            bleed_x, bleed_y = data.x + 30, data.y + 10
            bone_x, bone_y = data.x + 60, data.y + 10
        elseif limb_name == "left_leg" then
            bleed_x, bleed_y = data.x - 10, data.y - 40
            bone_x, bone_y = data.x - 10, data.y - 70
        elseif limb_name == "right_leg" then
            bleed_x, bleed_y = data.x + 10, data.y - 40
            bone_x, bone_y = data.x + 10, data.y - 70
        elseif limb_name == "torso" then
            bleed_x, bleed_y = data.x - 20, data.y + 20
            bone_x, bone_y = data.x + 20, data.y + 20
        else
            bleed_x, bleed_y = data.x - 20, data.y + 20
            bone_x, bone_y = data.x + 20, data.y + 20
        end

        if limb_name ~= "head" then
            local bone_icon = self.panel:AddChild(Image("images/scav_bone_icon.xml", "scav_bone_icon.tex"))
            bone_icon:SetPosition(bone_x, bone_y)
            bone_icon:SetSize(25, 38)
            bone_icon:Hide()
            self.limb_bone_icons[limb_name] = bone_icon
        end

        local bleed_icon = self.panel:AddChild(Image("images/scav_blood_drop.xml", "scav_blood_drop.tex"))
        bleed_icon:SetPosition(bleed_x, bleed_y)
        bleed_icon:SetSize(25, 38)
        bleed_icon:Hide()
        self.limb_bleed_icons[limb_name] = bleed_icon
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
    self.wrap_bandage:SetSize(65, 65)
    self.wrap_bandage:Hide()

    -- Syringe minigame variables & assets
    self.injection_active = false
    self.syringe_pos = { x = 0, y = 160 }
    self.syringe_grabbed = false
    self.inject_progress = 0
    self.touch_time = 0

    -- Liquid rectangle (drawn BEHIND the syringe outline) - WHITE liquid
    self.syringe_liquid = self.panel:AddChild(Image("images/global.xml", "square.tex"))
    self.syringe_liquid:SetTint(1, 1, 1, 0.9) -- Solid white liquid
    self.syringe_liquid:SetSize(38, 180)
    self.syringe_liquid:SetPosition(self.syringe_pos.x, self.syringe_pos.y + 20)
    self.syringe_liquid:Hide()

    -- Syringe outline (drawn on top of the liquid)
    local syringe_atlas, syringe_tex = GetUIAsset("scav_syringe", "images/global_redux.xml", "button_square.tex")
    self.syringe_bg = self.panel:AddChild(Image(syringe_atlas, syringe_tex))
    self.syringe_bg:SetPosition(self.syringe_pos.x, self.syringe_pos.y)
    self.syringe_bg:SetSize(66, 360)
    self.syringe_bg:Hide()

    -- Syringe target body part image (dark black rectangle from the chat)
    local target_atlas, target_tex = GetUIAsset("scav_body_target", "images/global_redux.xml", "button_square.tex")
    self.body_target = self.panel:AddChild(Image(target_atlas, target_tex))
    self.body_target:SetPosition(0, -220)
    self.body_target:SetSize(450, 180)
    self.body_target:Hide()

    -- Custom Hand Cursor
    local cursor_atlas, cursor_tex = GetUIAsset("Arm-removebg-preview", "images/global_redux.xml", "button_square.tex")
    self.hand_cursor = self.root:AddChild(Image(cursor_atlas, cursor_tex))
    self.hand_cursor:SetScale(0.8, 0.8)
    self.hand_cursor:SetVRegPoint(ANCHOR_TOP)
    self.hand_cursor:SetHRegPoint(ANCHOR_MIDDLE)
    self.hand_cursor:Hide()

    -- Bone resetting minigame widgets
    self.bone_reset_active = false
    self.bone_reset_limb = nil
    self.bone_jerk_count = 0
    self.bone_target_pos = { x = 80, y = 40 }
    self.bone_current_pos = { x = 180, y = 0 }
    self.bone_current_rot = 35
    self.bone_grabbed = false

    -- Silhouette target bone (transparent grey whole bone)
    self.bone_silhouette = self.panel:AddChild(Image("images/scav_bone_whole.xml", "scav_bone_whole.tex"))
    self.bone_silhouette:SetPosition(0, 40)
    self.bone_silhouette:SetSize(320, 117)
    self.bone_silhouette:SetTint(1, 1, 1, 0.25)
    self.bone_silhouette:Hide()

    -- Static left bone fragment
    self.bone_left_part = self.panel:AddChild(Image("images/scav_bone_left.xml", "scav_bone_left.tex"))
    self.bone_left_part:SetPosition(-80, 40)
    self.bone_left_part:SetSize(180, 110)
    self.bone_left_part:Hide()

    -- Interactive/moving broken right bone fragment (solid red overlay)
    self.bone_interactive = self.panel:AddChild(Image("images/scav_bone_right.xml", "scav_bone_right.tex"))
    self.bone_interactive:SetPosition(self.bone_current_pos.x, self.bone_current_pos.y)
    self.bone_interactive:SetSize(180, 110)
    self.bone_interactive:SetRotation(self.bone_current_rot)
    self.bone_interactive:SetTint(1, 0.2, 0.2, 0.95)
    self.bone_interactive:Hide()

    self.was_clicked = nil

    -- Levels display on the right side of the medical screen
    local ScavLevelsDisplay = require("widgets/scav_levels_display")
    self.levels_display = self.root:AddChild(ScavLevelsDisplay(self.owner))
    self.levels_display:SetPosition(440, 0)

    self:UpdateLimbHealth()
    self:StartUpdating()
end)

function ScavMedicalScreen:UpdateLimbHealth()
    local inst = self.owner
    if not inst then return end

    local function GetLimbStatus(name)
        if name == "head" then
            return "ОК", { 1, 1, 1, 1 }
        end
        local is_broken = inst["scav_broken_" .. name] and inst["scav_broken_" .. name]:value() or false
        local is_bleeding = inst["scav_bleeding_" .. name] and inst["scav_bleeding_" .. name]:value() or false
        local is_heavy = inst.scav_heavy_bleeding and inst.scav_heavy_bleeding:value() or false
        
        if is_broken and is_bleeding then
            local prefix = is_heavy and "Тяж.Кров." or "Кров."
            return "Перелом+" .. prefix, { 1, 0.1, 0.05, 1 }
        elseif is_broken then
            return "Перелом", { 1, 0.5, 0, 1 }
        elseif is_bleeding then
            local text = is_heavy and "Тяж. Кровотечение" or "Кровотечение"
            local colour = is_heavy and { 0.7, 0.05, 0.05, 1 } or { 1, 0.2, 0.2, 1 }
            return text, colour
        else
            return "ОК", { 1, 1, 1, 1 }
        end
    end

    local health_data = {
        head = { health = inst.scav_limb_head and inst.scav_limb_head:value() or 100 },
        torso = { health = inst.scav_limb_torso and inst.scav_limb_torso:value() or 100 },
        left_arm = { health = inst.scav_limb_left_arm and inst.scav_limb_left_arm:value() or 100 },
        right_arm = { health = inst.scav_limb_right_arm and inst.scav_limb_right_arm:value() or 100 },
        left_leg = { health = inst.scav_limb_left_leg and inst.scav_limb_left_leg:value() or 100 },
        right_leg = { health = inst.scav_limb_right_leg and inst.scav_limb_right_leg:value() or 100 },
    }

    for name, data in pairs(health_data) do
        local status, colour = GetLimbStatus(name)
        local txt = self.limb_texts[name]
        if txt then
            txt:SetString(string.format("%d%% (%s)", data.health, status))
            txt:SetColour(colour[1], colour[2], colour[3], colour[4])
        end

        local is_broken = name ~= "head" and inst["scav_broken_" .. name] and inst["scav_broken_" .. name]:value() or false
        local is_bleeding = name ~= "head" and inst["scav_bleeding_" .. name] and inst["scav_bleeding_" .. name]:value() or false
        local is_heavy = inst.scav_heavy_bleeding and inst.scav_heavy_bleeding:value() or false

        if self.limb_bleed_icons[name] then
            if is_bleeding then
                self.limb_bleed_icons[name]:Show()
                if is_heavy then
                    self.limb_bleed_icons[name]:SetTint(0.6, 0.05, 0.05, 1) -- Deeper, darker red for heavy bleeding
                else
                    self.limb_bleed_icons[name]:SetTint(1, 1, 1, 1) -- Standard color
                end
            else
                self.limb_bleed_icons[name]:Hide()
            end
        end
        if self.limb_bone_icons[name] then
            if is_broken then self.limb_bone_icons[name]:Show() else self.limb_bone_icons[name]:Hide() end
        end
    end
end

function ScavMedicalScreen:SetLimbUIActive(active)
    -- Hide/show limbs
    for _, img in pairs(self.limb_images) do
        if active then img:Show() else img:Hide() end
    end
    
    -- Hide/show limb health texts
    for _, txt in pairs(self.limb_texts) do
        if active then txt:Show() else txt:Hide() end
    end

    -- Sync overlays
    if active then
        self:UpdateLimbHealth()
    else
        for _, icon in pairs(self.limb_bleed_icons) do icon:Hide() end
        for _, icon in pairs(self.limb_bone_icons) do icon:Hide() end
    end
end

function ScavMedicalScreen:OnLimbClicked(limb_name)
    if self.wrapping_active or self.bone_reset_active then return end

    local inst = self.owner
    self.item = nil
    self.item_type = nil

    -- 1. Determine the appropriate item type based on limb condition
    local is_bleeding = false
    if limb_name == "head" and inst.scav_bleeding_head and inst.scav_bleeding_head:value() then is_bleeding = true
    elseif limb_name == "torso" and inst.scav_bleeding_torso and inst.scav_bleeding_torso:value() then is_bleeding = true
    elseif limb_name == "left_arm" and inst.scav_bleeding_left_arm and inst.scav_bleeding_left_arm:value() then is_bleeding = true
    elseif limb_name == "right_arm" and inst.scav_bleeding_right_arm and inst.scav_bleeding_right_arm:value() then is_bleeding = true
    elseif limb_name == "left_leg" and inst.scav_bleeding_left_leg and inst.scav_bleeding_left_leg:value() then is_bleeding = true
    elseif limb_name == "right_leg" and inst.scav_bleeding_right_leg and inst.scav_bleeding_right_leg:value() then is_bleeding = true
    end

    local is_broken = false
    if limb_name == "torso" and inst.scav_broken_torso and inst.scav_broken_torso:value() then is_broken = true
    elseif limb_name == "left_arm" and inst.scav_broken_left_arm and inst.scav_broken_left_arm:value() then is_broken = true
    elseif limb_name == "right_arm" and inst.scav_broken_right_arm and inst.scav_broken_right_arm:value() then is_broken = true
    elseif limb_name == "left_leg" and inst.scav_broken_left_leg and inst.scav_broken_left_leg:value() then is_broken = true
    elseif limb_name == "right_leg" and inst.scav_broken_right_leg and inst.scav_broken_right_leg:value() then is_broken = true
    end

    local is_poisoned = inst.scav_poisoned and inst.scav_poisoned:value()

    local target_type = nil
    if is_bleeding then
        target_type = "bandage"
    elseif is_broken then
        target_type = "splint"
    elseif is_poisoned then
        target_type = "antidote"
    end

    if not target_type then
        self.instructions:SetString("Эта часть тела здорова и не требует лечения!")
        self.instructions:SetColour(0.8, 0.8, 0.8, 1)
        return
    end

    -- Find the item in inventory
    local item = FindMedicalItem(inst, target_type)
    if not item then
        if target_type == "bandage" then
            self.instructions:SetString("У вас нет бинта для остановки кровотечения!")
        elseif target_type == "splint" then
            self.instructions:SetString("У вас нет шины для фиксации перелома!")
        elseif target_type == "antidote" then
            self.instructions:SetString("У вас нет противоядия для инъекции!")
        end
        self.instructions:SetColour(1, 0.3, 0.3, 1)
        return
    end

    self.item = item
    self.item_type = target_type

    -- 2. Execute treatment
    if self.item_type == "bandage" then
        self.wrapping_active = true
        self.wrapping_limb = limb_name
        self.wrap_accumulated_angle = 0
        self.wrap_angle_prev = nil
        
        self:SetLimbUIActive(false)

        self.wrap_circle:Show()
        self.wrap_bandage:Show()
        self.wrap_bandage:SetSize(65, 65)
        
        local panel_pos = self.panel:GetWorldPosition()
        local scale = self.root:GetScale()
        self.wrap_center_screen = { x = panel_pos.x, y = panel_pos.y + 40 * scale.y }

        if not is_bleeding then
            self.instructions:SetString("Конечность не кровоточит, но накладываем бинт для тренировки!")
            self.instructions:SetColour(0.8, 0.8, 0.8, 1)
        else
            self.instructions:SetString("Зажмите мышь и водите бинт КРУГАМИ вокруг раны!")
            self.instructions:SetColour(0.3, 0.9, 0.3, 1)
        end

        if TheInputProxy then
            TheInputProxy:SetCursorVisible(false)
        end
        self.hand_cursor:Show()
        self.was_clicked = nil
    
    elseif self.item_type == "splint" then
        if not is_broken then
            self.instructions:SetString("Конечность цела, но накладываем шину для теста...")
            self.instructions:SetColour(0.8, 0.8, 0.8, 1)
            self.owner:DoTaskInTime(1.5, function()
                SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, limb_name)
                self:Close()
            end)
        else
            -- TRIGGER THE BONE RESETTING MINIGAME!
            self.bone_reset_active = true
            self.bone_reset_limb = limb_name
            self.bone_jerk_count = 0
            self.bone_grabbed = false
            
            -- Initialize position/rotation randomly off-target
            self.bone_current_pos = { x = math.random() > 0.5 and 180 or 150, y = math.random(-20, 20) }
            self.bone_start_pos = { x = self.bone_current_pos.x, y = self.bone_current_pos.y }
            self.bone_current_rot = math.random() > 0.5 and 35 or -35
            self.initial_bone_rot = self.bone_current_rot
            
            self:SetLimbUIActive(false)
            
            self.bone_silhouette:Show()
            self.bone_left_part:Show()
            self.bone_interactive:SetPosition(self.bone_current_pos.x, self.bone_current_pos.y)
            self.bone_interactive:SetRotation(self.bone_current_rot)
            self.bone_interactive:Show()
            
            self.instructions:SetString("Зажмите и тащите кость к левой части для совмещения!")
            self.instructions:SetColour(0.8, 0.8, 0.8, 1)
            
            if TheInputProxy then
                TheInputProxy:SetCursorVisible(false)
            end
            self.hand_cursor:Show()
            self.was_clicked = nil
        end
    
    elseif self.item_type == "antidote" then
        self.injection_active = true
        self.wrapping_limb = limb_name
        self.syringe_pos = { x = 0, y = 160 }
        self.syringe_grabbed = false
        
        local starting_charge = self.item and self.item.scav_charge and self.item.scav_charge:value() or 100
        self.inject_progress = 100 - starting_charge
        self.injected_this_session = 0
        self.touch_time = 0
        self.cooldown_triggered_this_session = false

        self:SetLimbUIActive(false) -- Hide the limbs and health status texts
        self.body_target:Show() -- Show the custom body area target image

        self.syringe_bg:SetPosition(self.syringe_pos.x, self.syringe_pos.y)
        self.syringe_bg:Show()
        
        -- Set liquid level based on starting charge
        local progress_ratio = self.inject_progress / 100
        local liquid_ratio = 1.0 - progress_ratio
        local fill_max_h = 180
        local fill_min_y = -70
        local h = fill_max_h * liquid_ratio
        local y = fill_min_y + h / 2

        self.syringe_liquid:SetSize(38, h)
        self.syringe_liquid:SetPosition(self.syringe_pos.x, self.syringe_pos.y - 40 + y)
        self.syringe_liquid:Show()

        self.instructions:SetString("Зажмите шприц и перетяните его на область снизу!")
        self.instructions:SetColour(0.3, 0.9, 0.3, 1)

        if TheInputProxy then
            TheInputProxy:SetCursorVisible(false)
        end
        self.hand_cursor:Show()
        self.was_clicked = nil
    end
end

function ScavMedicalScreen:OnUpdate(dt)
    self:UpdateLimbHealth()

    if self.wrapping_active or self.injection_active or self.bone_reset_active then
        -- Follow mouse with custom hand cursor
        local w, h = TheSim:GetScreenSize()
        local mouse_pos = TheInput:GetScreenPosition()
        local scale = self.root:GetScale()
        local local_x = (mouse_pos.x - w / 2) / scale.x
        local local_y = (mouse_pos.y - h / 2) / scale.y
        self.hand_cursor:SetPosition(local_x, local_y)

        -- Toggle hand cursor texture ONLY on click state change (prevents GPU rebinding flicker/disappearance)
        local is_clicked = TheInput:IsMouseDown(MOUSEBUTTON_LEFT)
        if self.was_clicked == nil or self.was_clicked ~= is_clicked then
            self.was_clicked = is_clicked
            local cursor_name = is_clicked and "ArmFist-removebg-preview" or "Arm-removebg-preview"
            local cursor_atlas, cursor_tex = GetUIAsset(cursor_name, "images/global_redux.xml", "button_square.tex")
            self.hand_cursor:SetTexture(cursor_atlas, cursor_tex)
        end

        local mouse_x = mouse_pos.x
        local mouse_y = mouse_pos.y

        if self.wrapping_active then
            if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
                -- Angle calculations relative to center of wrapping circle
                local dx = mouse_x - self.wrap_center_screen.x
                local dy = mouse_y - self.wrap_center_screen.y
                local dist = math.sqrt(dx*dx + dy*dy)

                -- Just require the player to move mouse in circles around center (avoid exact radius restriction)
                if dist > 10 then
                    local angle = math.atan2(dy, dx)
                    
                    -- Position bandage visual along the circle path (always stays on the visual guide)
                    local bx = 110 * math.cos(angle)
                    local by = 40 + 110 * math.sin(angle)
                    self.wrap_bandage:SetPosition(bx, by)

                    if self.wrap_angle_prev then
                        local diff = angle - self.wrap_angle_prev
                        while diff > math.pi do diff = diff - 2*math.pi end
                        while diff < -math.pi do diff = diff + 2*math.pi end

                        self.wrap_accumulated_angle = self.wrap_accumulated_angle + diff
                        
                        local progress_ratio = math.min(1.0, math.abs(self.wrap_accumulated_angle) / (3 * 2 * math.pi))
                        local progress = math.min(100, math.floor(progress_ratio * 100))
                        self.instructions:SetString(string.format("Намотка бинта: %d%%", progress))

                        -- Bandage shrinks dynamically as it is used
                        local size = 65 - 35 * progress_ratio
                        self.wrap_bandage:SetSize(size, size)

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
        
        elseif self.injection_active then
            if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
                -- Grab syringe if mouse is close enough
                if not self.syringe_grabbed then
                    local dx = local_x - self.syringe_pos.x
                    local dy = local_y - self.syringe_pos.y
                    -- Hitbox check to grab the syringe (tall vertical bounds)
                    if math.abs(dx) < 50 and math.abs(dy) < 180 then
                        self.syringe_grabbed = true
                    end
                end

                if self.syringe_grabbed then
                    -- Follow hand cursor, keeping the syringe body above the hand
                    self.syringe_pos.x = local_x
                    self.syringe_pos.y = local_y + 100 -- Syringe is attached above the hand cursor

                    self.syringe_bg:SetPosition(self.syringe_pos.x, self.syringe_pos.y)
                end
            else
                -- Released click: save progress made during this click session
                if self.injected_this_session > 0.1 then
                    SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
                    self.injected_this_session = 0
                end
                self.syringe_grabbed = false
            end

            -- Collision/hitbox touch detection using the needle tip (bottom of the syringe)
            -- Bounding box matches scav_body_target size at Y: -220: X: [-225, 225], Y: [-350, -130] (partially offscreen)
            local needle_x = self.syringe_pos.x
            local needle_y = self.syringe_pos.y - 180 -- Needle tip is 180px below center of syringe
            local touching_body = false
            if math.abs(needle_x) < 225 and needle_y >= -350 and needle_y <= -130 then
                touching_body = true
            end

            if touching_body and self.syringe_grabbed then
                local cooldown = self.owner.scav_overdose_cooldown and self.owner.scav_overdose_cooldown:value() or 0
                if cooldown > 0 and not self.cooldown_triggered_this_session then
                    -- They are injecting during active cooldown!
                    -- Accumulate damage timer to trigger bleeding on active limb
                    self.cooldown_damage_timer = (self.cooldown_damage_timer or 0) + dt
                    if self.cooldown_damage_timer >= 1.0 then
                        self.cooldown_damage_timer = 0
                        
                        -- Save progress made up to this tick
                        if self.injected_this_session > 0.1 then
                            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
                            self.injected_this_session = 0
                        end

                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyOverdose"), self.wrapping_limb)
                        self.owner.SoundEmitter:PlaySound("dontstarve/characters/wilson/hurt")
                    end
                    
                    self.instructions:SetString(string.format("ПЕРЕДОЗИРОВКА! Вызывает кровотечение! (Откат: %d сек)", math.ceil(cooldown)))
                    self.instructions:SetColour(1, 0.2, 0.2, 1)
                else
                    -- Touch timer accumulates
                    self.touch_time = self.touch_time + dt
                    
                    -- Start hidden 5-minute cooldown as soon as warning threshold (2.0s) is crossed
                    if self.touch_time >= 2.0 then
                        if not self.cooldown_triggered_this_session then
                            self.cooldown_triggered_this_session = true
                            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "StartOverdoseCooldown"))
                        end
                    end

                    -- Check for fatal overdose (continuous contact >= 5.0 seconds - i.e. 3 seconds after warning)
                    if self.touch_time >= 5.0 then
                        self.touch_time = 0
                        self.syringe_grabbed = false
                        
                        -- Save progress made up to overdose before dying
                        if self.injected_this_session > 0.1 then
                            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
                            self.injected_this_session = 0
                        end

                        -- Trigger bleeding on server
                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyOverdose"), self.wrapping_limb)
                        self.owner.SoundEmitter:PlaySound("dontstarve/characters/wilson/hurt")
                        self:Close()
                    else
                        if self.touch_time >= 2.0 then
                            -- Warn about imminent overdose (2.0s to 5.0s is 3 seconds)
                            self.instructions:SetString(string.format("Инъекция: %d%% - ВНИМАНИЕ: РИСК ПЕРЕДОЗИРОВКИ!", math.floor(self.inject_progress)))
                            self.instructions:SetColour(1, 0.5, 0, 1)
                        else
                            self.instructions:SetString(string.format("Инъекция: %d%%", math.floor(self.inject_progress)))
                            self.instructions:SetColour(0.3, 0.9, 0.3, 1)
                        end
                    end

                    -- White liquid is emptied (progress increases)
                    -- 6.25% empty per second (empties in 16 seconds of cumulative contact)
                    local old_progress = self.inject_progress
                    self.inject_progress = math.min(100, self.inject_progress + dt * 6.25)
                    local delta = self.inject_progress - old_progress
                    if delta > 0 then
                        self.injected_this_session = self.injected_this_session + delta
                    end

                    -- 100% completed
                    if self.inject_progress >= 100 then
                        self.injection_active = false
                        self.syringe_bg:Hide()
                        self.syringe_liquid:Hide()
                        self.body_target:Hide()
                        self.instructions:SetString("Введение завершено!")
                        self.owner.SoundEmitter:PlaySound("dontstarve/common/teleportato/tubedone")

                        -- Save final session progress
                        if self.injected_this_session > 0.1 then
                            SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
                            self.injected_this_session = 0
                        end
                        self:Close()
                    end
                end
            else
                -- Pulling it away resets the touch timer (avoiding overdose) and saves progress
                if self.touch_time > 0 or (self.cooldown_damage_timer and self.cooldown_damage_timer > 0) then
                    if self.injected_this_session > 0.1 then
                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
                        self.injected_this_session = 0
                    end
                end
                self.touch_time = 0
                self.cooldown_damage_timer = 0
                self.cooldown_triggered_this_session = false

                local cooldown = self.owner.scav_overdose_cooldown and self.owner.scav_overdose_cooldown:value() or 0
                if cooldown > 0 then
                    self.instructions:SetString(string.format("ОПАСНОСТЬ ПЕРЕДОЗИРОВКИ! Подождите: %d сек", math.ceil(cooldown)))
                    self.instructions:SetColour(1, 0.5, 0, 1)
                else
                    self.instructions:SetString(self.syringe_grabbed and "Перетяните шприц в зону снизу!" or "Зажмите и перетяните шприц в зону снизу!")
                    self.instructions:SetColour(0.8, 0.8, 0.8, 1)
                end
            end

            -- Update white liquid level and position (trimmed from top relative to syringe position)
            local progress_ratio = self.inject_progress / 100
            local liquid_ratio = 1.0 - progress_ratio
            local fill_max_h = 180
            local fill_min_y = -70
            local h = fill_max_h * liquid_ratio
            local y = fill_min_y + h / 2
            
            self.syringe_liquid:SetSize(38, h)
            self.syringe_liquid:SetPosition(self.syringe_pos.x, self.syringe_pos.y - 40 + y)
        
        elseif self.bone_reset_active then
            if TheInput:IsMouseDown(MOUSEBUTTON_LEFT) then
                if not self.bone_grabbed then
                    local dx = local_x - self.bone_current_pos.x
                    local dy = local_y - self.bone_current_pos.y
                    if math.abs(dx) < 90 and math.abs(dy) < 55 then
                        self.bone_grabbed = true
                        self.prev_mouse_x = local_x
                        self.prev_mouse_y = local_y
                    end
                end

                if self.bone_grabbed then
                    -- The bone follows the mouse position!
                    self.bone_current_pos.x = local_x
                    self.bone_current_pos.y = local_y
                    
                    -- Calculate distance to target (80, 40)
                    local dx = self.bone_target_pos.x - self.bone_current_pos.x
                    local dy = self.bone_target_pos.y - self.bone_current_pos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    -- Rotation dynamically straightens to 0 as it approaches target
                    local progress = math.max(0, math.min(1, 1 - (dist / 180)))
                    self.bone_current_rot = self.initial_bone_rot * (1 - progress)
                    
                    if dist < 30 then
                        self.instructions:SetString("Отпустите кнопку мыши, чтобы вправить кость!")
                        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
                    else
                        self.instructions:SetString("Совместите кость с силуэтом слева!")
                        self.instructions:SetColour(0.8, 0.8, 0.8, 1)
                    end
                    
                    self.prev_mouse_x = local_x
                    self.prev_mouse_y = local_y
                    self.bone_interactive:SetPosition(self.bone_current_pos.x, self.bone_current_pos.y)
                    self.bone_interactive:SetRotation(self.bone_current_rot)
                end
            else
                if self.bone_grabbed then
                    local dx = self.bone_target_pos.x - self.bone_current_pos.x
                    local dy = self.bone_target_pos.y - self.bone_current_pos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < 30 then
                        -- Snap in and finish!
                        self.bone_current_pos = { x = self.bone_target_pos.x, y = self.bone_target_pos.y }
                        self.bone_current_rot = 0
                        self.instructions:SetString("Кость вправлена!")
                        self.instructions:SetColour(0.3, 0.9, 0.3, 1)
                        self.owner.SoundEmitter:PlaySound("dontstarve/common/chest_open")
                        
                        self.bone_reset_active = false
                        self.bone_silhouette:Hide()
                        self.bone_left_part:Hide()
                        self.bone_interactive:Hide()
                        
                        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "ApplyTreatment"), self.item, self.bone_reset_limb)
                        self.inst:DoTaskInTime(0.6, function() self:Close() end)
                    else
                        -- Reset back to start position
                        self.owner.SoundEmitter:PlaySound("dontstarve/common/destroy_stone")
                        self.bone_current_pos = { x = self.bone_start_pos.x, y = self.bone_start_pos.y }
                        self.bone_current_rot = self.initial_bone_rot
                        self.bone_interactive:SetPosition(self.bone_current_pos.x, self.bone_current_pos.y)
                        self.bone_interactive:SetRotation(self.bone_current_rot)
                    end
                end
                self.bone_grabbed = false
                self.prev_mouse_x = nil
                self.prev_mouse_y = nil
            end
        end
    end
end

function ScavMedicalScreen:Close()
    self.wrapping_active = false
    self.injection_active = false
    self.bone_reset_active = false
    if self.injected_this_session and self.injected_this_session > 0.1 then
        SendModRPCToServer(GetModRPC("MEGACALLLMOD", "UpdateSyringe"), self.item, self.injected_this_session)
        self.injected_this_session = 0
    end
    if self.body_target then
        self.body_target:Hide()
    end
    if self.bone_silhouette then
        self.bone_silhouette:Hide()
    end
    if self.bone_left_part then
        self.bone_left_part:Hide()
    end
    if self.bone_interactive then
        self.bone_interactive:Hide()
    end
    if TheInputProxy then
        TheInputProxy:SetCursorVisible(true) -- Restore hardware cursor
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
