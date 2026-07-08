local function SpawnChestNearPlayer(player)
    local x, y, z = player.Transform:GetWorldPosition()
    
    -- Try to find a valid walkable spot around the player
    local max_attempts = 20
    local min_dist = 20
    local max_dist = 50
    
    for i = 1, max_attempts do
        local angle = math.random() * 2 * math.pi
        local dist = min_dist + math.random() * (max_dist - min_dist)
        local tx = x + dist * math.cos(angle)
        local tz = z + dist * math.sin(angle)
        
        -- Check if it's walkable ground (not water/abyss)
        if TheWorld.Map:IsPassableAtPoint(tx, 0, tz) then
            -- Check for nearby structures/chests to prevent overlap
            local ents = TheSim:FindEntities(tx, 0, tz, 5, { "structure", "scav_chest", "chest" })
            if #ents == 0 then
                local chest = SpawnPrefab("scav_chest")
                if chest then
                    chest.Transform:SetPosition(tx, 0, tz)
                    print("[SCAV Spawner] Spawned chest at: ", tx, tz)
                    return true
                end
            end
        end
    end
    return false
end

local function StartSpawner(world)
    -- Spawn a chest every 20 minutes (1200 seconds)
    world:DoPeriodicTask(1200, function()
        -- Only spawn if players are online
        if #AllPlayers > 0 then
            local target_player = AllPlayers[math.random(#AllPlayers)]
            SpawnChestNearPlayer(target_player)
        end
    end, 60) -- First check after 60 seconds of world load
end

-- Initialize spawning for forest and cave worlds
if TheWorld and TheWorld.ismastersim then
    StartSpawner(TheWorld)
end

return {
    SpawnChestNearPlayer = SpawnChestNearPlayer
}
