local assets = {}

local function OnOpen(inst)
    if not inst:HasTag("opened") then
        inst:AddTag("opened")
        inst.SoundEmitter:PlaySound("dontstarve/common/chest_open")
        inst.AnimState:PlayAnimation("open")
    end
end

local function OnClose(inst)
    if inst:HasTag("opened") then
        inst:RemoveTag("opened")
        inst.SoundEmitter:PlaySound("dontstarve/common/chest_close")
        inst.AnimState:PlayAnimation("close")
    end
end

-- Generate random loot inside the chest
local function PopulateLoot(inst)
    local loot_pool = {
        "scav_bandage",
        "scav_antidote",
        "scav_splint",
        "goldnugget",
        "flint",
        "gears",
        "nitre",
        "charcoal",
    }
    
    if inst.components.container then
        local num_items = math.random(3, 5)
        for i = 1, num_items do
            local item_prefab = loot_pool[math.random(#loot_pool)]
            local item = SpawnPrefab(item_prefab)
            if item then
                inst.components.container:GiveItem(item)
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("structure")
    inst:AddTag("scav_chest")
    inst:AddTag("chest")

    inst.AnimState:SetBank("sacred_chest")
    inst.AnimState:SetBuild("sacred_chest")
    inst.AnimState:PlayAnimation("closed")

    -- Add a net variable to tell clients if the chest is locked
    inst.scav_locked = net_bool(inst.GUID, "scav_locked")
    inst.scav_locked:set(true) -- Initially locked

    -- Lock type synced to client: 0 for hotspot (lockpick), 1 for keypad
    inst.scav_lock_type = net_byte(inst.GUID, "scav_lock_type")
    inst.scav_lock_type:set(1) -- Always keypad type

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("treasurechest")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose

    -- Populate loot immediately but keep it locked
    PopulateLoot(inst)

    -- Save/Load chest lock state
    inst.OnSave = function(inst, data)
        data.locked = inst.scav_locked:value()
        data.lock_type = inst.scav_lock_type:value()
    end
    inst.OnLoad = function(inst, data)
        if data then
            inst.scav_locked:set(data.locked ~= false)
            if data.lock_type then
                inst.scav_lock_type:set(data.lock_type)
            end
        end
    end

    return inst
end

return Prefab("scav_keypad_chest", fn, assets)
