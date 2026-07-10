local hasoldtmmc = (tmmc and not tmmc.istmmcfixed and tmmc or nil)
tmmc = RegisterMod("TimeMachine [Fixed]", 1)
tmmc.istmmcfixed = true
local function show_warn(warnmsg)
    local warncounter = 300
    print(warnmsg)
    gt:AddCallback(ModCallbacks.MC_POST_RENDER, function (_)
        if warncounter >= 0 then
            local alpha = math.min(60, math.max(0, warncounter)) / 60
            local player = Isaac.GetPlayer(0)
            local pos = Isaac.WorldToScreen(player.Position - Vector(0, player.Size * 5))
            pos.X = pos.X - Isaac.GetTextWidth(warnmsg) * 0.25
            Isaac.RenderScaledText(warnmsg, pos.X, pos.Y, 0.5, 0.5, 1, 1, 0, alpha)
            warncounter = warncounter - 1
        end
    end)
end
if hasoldtmmc then
    show_warn('WARNING: You must disable the old TimeMachine before using TimeMachine [Fixed]!')
    gt = hasoldtmmc
    return
end

tmmc.speedmin = 0
tmmc.speeda = 0.05
tmmc.speedmax = 5
tmmc.supressFly = false
tmmc.supressBomb = false
tmmc.enable = {
    true,   --1.Slot Machine
    true,   --2.Blood Donation Machine
    true,   --3.Fortune Telling Machine
    true,   --4.Beggar
    true,   --5.Devil Beggar
    true,  --6.Shell Game
    true,   --7.Key Master
    false,  --8.Donation Machine
    true,   --9.Bomb Bum
    false,  --10.Shop Restock Machine
    true,  --11.Greed Donation Machine
    false,  --12.Mom's Dressing Table
    true,   --13.Battery Bum
    false,  --14.Isaac (secret)
    true,  --15.Hell Game
    true,   --16.Crane Game
    true,   --17.Confessional
    true,   --18.Rotten Beggar
}
local speedNow = tmmc.speedmin
local speedAccum = 0.0
function tmmc:new_room()
    speedNow = tmmc.speedmin
end
function tmmc:find_slot()
    local machines = {}
    local slots = Isaac.FindByType(6, -1, -1, false, false)
    for _, slot in ipairs(slots) do
        if tmmc.enable[slot.Variant] then
            table.insert(machines, slot)
        end
    end
    return machines
end
function tmmc:step()
    if Game():GetRoom():IsClear() then
        local machines = tmmc:find_slot()
        if #machines then
            local timeplus = 0
            local count = 1
            speedAccum = speedAccum + math.max(0, speedNow)
            while speedAccum > 1 do
                speedAccum = speedAccum - 1
                timeplus = timeplus + 1
                count = count + 1
            end
            local isTouched = false
            for i = 1, Game():GetNumPlayers() do
                local player = Isaac.GetPlayer(i)
                for _, slot in ipairs(machines) do
                    if player.Position:Distance(slot.Position) < (player.Size + slot.Size) then
                        isTouched = true
                        local dx = player.Position.X - slot.Position.X
                        local dy = player.Position.Y - slot.Position.Y
                        if math.abs(dx) < math.max(5, 6 * player.MoveSpeed) then
                            if ((Input.IsActionPressed(ButtonAction.ACTION_UP, player.ControllerIndex) and dy > 0) or (Input.IsActionPressed(ButtonAction.ACTION_DOWN, player.ControllerIndex) and dy < 0))
                                and (not Input.IsActionPressed(ButtonAction.ACTION_RIGHT, player.ControllerIndex)) and (not Input.IsActionPressed(ButtonAction.ACTION_LEFT, player.ControllerIndex)) then
                                player.Position = Vector(player.Position.X - dx / 2, player.Position.Y + dy / math.abs(dy) * (player.Size + slot.Size - math.abs(dy)) * (player.MoveSpeed + speedNow) / 2)
                            else
                            end
                        end
                        for _ = 1, count do
                            slot:Update()
                            local oldPosition = player.Position
                            player:Update()
                            player.Position = oldPosition
                            if (slot.Variant == 2 or slot.Variant == 17) and player:HasInvincibility() then
                                oldPosition = player.Position
                                player:Update()
                                player.Position = oldPosition
                            end
                        end
                        if tmmc.supressFly then
                            for _, e in ipairs(Isaac.FindByType(85, 0, 0)) do
                                e:Kill()
                            end
                            for _, e in ipairs(Isaac.FindByType(18, 0, 0)) do
                                e:Kill()
                            end
                        end
                        if tmmc.supressBomb then
                            for _, e in ipairs(Isaac.FindByType(4, -1, -1)) do
                                e:ToBomb():SetExplosionCountdown(100)
                                e.Velocity = -e.Velocity
                            end
                        end
                    end
                end
            end
            if isTouched then
                if speedNow <= tmmc.speedmax then
                    speedNow = speedNow + tmmc.speeda
                end
            else
                speedNow = tmmc.speedmin
            end
            Game().TimeCounter = Game().TimeCounter + timeplus
        end
    end
end

tmmc:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, tmmc.new_room)
tmmc:AddCallback(ModCallbacks.MC_POST_UPDATE, tmmc.step)
