--------- copied from mcm ---------
Controller = Controller or {}
Controller.DPAD_LEFT = 0
Controller.DPAD_RIGHT = 1
Controller.DPAD_UP = 2
Controller.DPAD_DOWN = 3
Controller.BUTTON_A = 4
Controller.BUTTON_B = 5
Controller.BUTTON_X = 6
Controller.BUTTON_Y = 7
Controller.BUMPER_LEFT = 8
Controller.TRIGGER_LEFT = 9
Controller.STICK_LEFT = 10
Controller.BUMPER_RIGHT = 11
Controller.TRIGGER_RIGHT = 12
Controller.STICK_RIGHT = 13
Controller.BUTTON_BACK = 14
Controller.BUTTON_START = 15
--------- copied from mcm ---------

local mod = RegisterMod("Restart Until Special Room", 1)

local cfg = {
	ItemQuality = 0,
	FindTreasureRoom = true,
	FindPlanetarium = true,
	FindLibrary = true,
	FindSacrificeRoom = false,
	FindCurseRoom = false,
	FindSecretRoom = false,
	FindShop = false,
	SkipCurse = false,
	EntireFloor = false,
	EdenStartItem = false,
	ItemIdHigh = 0,
	ItemIdMid = 0,
	ItemIdLow = 0,
    ItemId = 0,
}

local cfgKeys = {
	"ItemQuality",
	"FindTreasureRoom",
	"FindPlanetarium",
	"FindLibrary",
	"FindSacrificeRoom",
	"FindCurseRoom",
	"FindSecretRoom",
	"FindShop",
	"SkipCurse",
	"EntireFloor",
	"EdenStartItem",
	"ItemIdHigh",
	"ItemIdMid",
	"ItemIdLow",
}

local cfgKeysGreed = {
	"ItemQuality",
	"EdenStartItem",
	"ItemIdHigh",
	"ItemIdMid",
	"ItemIdLow",
}

local cfgLimits = {
	ItemQuality = 4,
	ItemIdLow = 9,
	ItemIdMid = 9,
	ItemIdHigh = 9,
}

local game = Game()
local font = Font()

function mod:getEdenItems(player)
    local result = {}
    for i = 1, CollectibleType.NUM_COLLECTIBLES - 1 do
        if player:HasCollectible(i) then
            result[#result + 1] = i
        end
    end
    return result
end

function mod:needSeekRoom()
    if game:IsGreedMode() then
        return true
    else
        return (cfg.FindTreasureRoom or cfg.FindPlanetarium or
                cfg.FindLibrary or cfg.FindSacrificeRoom or
                cfg.FindCurseRoom or cfg.FindSecretRoom or
                cfg.FindShop)
    end
end

function mod:isRoomWanted(rt)
    if game:IsGreedMode() then
        return rt == RoomType.ROOM_SHOP
    end
	local lut = {
		[RoomType.ROOM_TREASURE] = cfg.FindTreasureRoom,
		[RoomType.ROOM_PLANETARIUM] = cfg.FindPlanetarium,
		[RoomType.ROOM_LIBRARY] = cfg.FindLibrary,
		[RoomType.ROOM_SACRIFICE] = cfg.FindSacrificeRoom,
		[RoomType.ROOM_CURSE] = cfg.FindCurseRoom,
		[RoomType.ROOM_SECRET] = cfg.FindSecretRoom,
		[RoomType.ROOM_SHOP] = cfg.FindShop,
	}
	return lut[rt]
end

mod.foundRoomId = -1
mod.changedRoom = false

function mod:checkRoomItem(gid, player)
	if cfg.ItemQuality ~= 0 or cfg.ItemId ~= 0 or game:IsGreedMode() then
		mod.changedRoom = true
		mod.foundRoomId = gid
		-- game:ChangeRoom(gid, -1)
        -- game:GetRoom():PlayMusic()
		game:StartRoomTransition(gid, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player, -1)
	end
end

function mod:isLevelOk(level, player)
	local rooms = level:GetRooms()

	if cfg.SkipCurse and level:GetCurses() ~= LevelCurse.CURSE_NONE then
		return false
	end
    local eden = cfg.EdenStartItem and (player:GetPlayerType() == PlayerType.PLAYER_EDEN or player:GetPlayerType() == PlayerType.PLAYER_EDEN_B)
    if eden then
        for _, item in ipairs(mod:getEdenItems(player)) do
            if mod:isEdenItemQualityOk(item) then
                print('eden item ok', item)
                return true
            end
        end
    end
	if not mod:needSeekRoom() then
		return not eden
	end
	local sgid = level:GetStartingRoomIndex()
	for i = 0, rooms.Size - 1 do
		local rd = rooms:Get(i)
		if rd then
			if mod:isRoomWanted(rd.Data.Type) then
				if cfg.EntireFloor or game:IsGreedMode() then
					mod:checkRoomItem(rd.GridIndex, player)
					return true
				end
				local gid = rd.GridIndex
				local delta = math.abs(gid - sgid)
				if delta == 1 or delta == 13 then
					mod:checkRoomItem(gid, player)
					return true
				end
			end
		end
	end
	return false
end

mod.restarting = false
mod.showMenu = false
mod.rReleased = true

mod.menuSprite = nil
mod.selectSprite = nil
mod.selectIdx = 0

local itemConfig = Isaac.GetItemConfig()

local function getScreenBottomRight()
	return game:GetRoom():GetRenderSurfaceTopLeft() * 2 + Vector(442, 286)
end

function mod:isGroundItemQualityOk(itemId)
	return (cfg.ItemId ~= 0 and itemId == cfg.ItemId) or ((cfg.ItemId == 0 or cfg.ItemQuality ~= 0) and itemConfig:GetCollectible(itemId).Quality >= cfg.ItemQuality)
end

function mod:isEdenItemQualityOk(itemId)
	return itemId == cfg.ItemId or (cfg.ItemQuality ~= 0 and itemConfig:GetCollectible(itemId).Quality >= cfg.ItemQuality)
end

function mod:isCurrentRoomItemOk()
	local entities = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
	for _, item in ipairs(entities) do
		if item then
			if mod:isGroundItemQualityOk(item.SubType) then
				return true
			end
		end
	end
	return false
end

function mod:pressedR(player)
	return Input.IsActionTriggered(ButtonAction.ACTION_RESTART, player.ControllerIndex)
		or (Controller and
			Input.IsButtonTriggered(Controller.STICK_RIGHT, player.ControllerIndex)
		)
end

function mod:heldR(player)
	return Input.IsActionPressed(ButtonAction.ACTION_RESTART, player.ControllerIndex)
		or (Controller and
			Input.IsButtonPressed(Controller.STICK_RIGHT, player.ControllerIndex)
		)
end

function mod:pressedCtrlR(player)
	return (Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex) and
			Input.IsActionTriggered(ButtonAction.ACTION_RESTART, player.ControllerIndex)
		) or (Controller and
			Input.IsButtonPressed(Controller.STICK_LEFT, player.ControllerIndex) and
			Input.IsButtonTriggered(Controller.STICK_RIGHT, player.ControllerIndex)
		) or (Controller and
			Input.IsButtonTriggered(Controller.STICK_LEFT, player.ControllerIndex) and
			Input.IsButtonPressed(Controller.STICK_RIGHT, player.ControllerIndex)
		)
end

local pogDisabled = false

-- local function disablePogMod()
--     if pogDisabled then return end
--     pogDisabled = true
--     for _, pogMod in ipairs({Epic, Poglite}) do
--         if pogMod then
--             pogMod:RemoveCallback(ModCallbacks.MC_POST_UPDATE,pogMod.OnGameUpdate)
--             pogMod:RemoveCallback(ModCallbacks.MC_POST_NEW_ROOM,pogMod.OnPogReset or pogMod.OnNewRoom)
--             pogMod:RemoveCallback(ModCallbacks.MC_USE_ITEM,pogMod.OnUseItem or pogMod.OnRoomUpdate)
--             pogMod:RemoveCallback(ModCallbacks.MC_USE_CARD,pogMod.OnUseCard or pogMod.OnRoomUpdate)
--         end
--     end
-- end
--
-- local function enablePogMod()
--     if not pogDisabled then return end
--     pogDisabled = false
--     for _, pogMod in ipairs({Epic, Poglite}) do
--         if pogMod then
--             pogMod:AddCallback(ModCallbacks.MC_POST_UPDATE,pogMod.OnGameUpdate)
--             pogMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,pogMod.OnPogReset or pogMod.OnNewRoom)
--             pogMod:AddCallback(ModCallbacks.MC_USE_ITEM,pogMod.OnUseItem or pogMod.OnRoomUpdate)
--             pogMod:AddCallback(ModCallbacks.MC_USE_CARD,pogMod.OnUseCard or pogMod.OnRoomUpdate)
--         end
--     end
-- end

function mod:onRender()
    -- if game:GetFrameCount() > 30 then
    --     enablePogMod()
    -- else
    --     disablePogMod()
    -- end
    mod:onUpdate()
	local level = game:GetLevel()
	if mod.showMenu and level:GetStage() == 1 and not game:IsPaused() then
        local player = Isaac.GetPlayer(0)
        if not mod.menuSprite then
            mod.menuSprite = Sprite()
            mod.menuSprite:Load("gfx/restarter/minimap_icons.anm2", true)
        end
        if not mod.selectSprite then
            mod.selectSprite = Sprite()
            mod.selectSprite:Load("gfx/restarter/gt_ui.anm2", true)
        end
        if not mod.menuSprite:IsLoaded() or not mod.selectSprite:IsLoaded() then return end
        local i = 0
        local br = getScreenBottomRight()
        local menuPos = Vector(br.X * 0.15, br.Y * 0.35)
        local selectedKey = nil
        if not font:IsLoaded() then font:Load("font/teammeatfont10.fnt") end
        local localCfgKeys = cfgKeys
        if game:IsGreedMode() then
            localCfgKeys = cfgKeysGreed
        end
        for _, k in ipairs(localCfgKeys) do
            local frame = cfg[k] and 0 or 1
            if string.sub(k, 1, 4) == "Find" then
                mod.menuSprite:SetFrame("Icon" .. string.sub(k, 5), frame)
            elseif string.sub(k, 1, 6) == "ItemId" then
                mod.menuSprite:SetFrame(cfg.ItemId ~= 0 and "IconNumber" or "IconItemQuality", cfg[k])
            elseif cfgLimits[k] then
                mod.menuSprite:SetFrame("Icon" .. k, cfg[k])
            else
                mod.menuSprite:SetFrame("Icon" .. k, frame)
            end
            mod.menuSprite:Render(Vector(menuPos.X, menuPos.Y + 10 * i), Vector(0, 0), Vector(0, 0))
            if i == mod.selectIdx then
                selectedKey = k
                mod.selectSprite:SetFrame("select", 1)
                mod.selectSprite:Render(Vector(menuPos.X, menuPos.Y + 10 * i), Vector(0, 0), Vector(0, 0))
                if cfgLimits[k] then
                    k = string.format("%s=%d", k, cfg[k])
                end
                font:DrawStringScaledUTF8(k, menuPos.X + 13, menuPos.Y + 3 + 10 * i, 0.5, 0.5, KColor(1, 1, 1, 0.3))
            end
            i = i + 1
        end
        if not game:IsPaused() then
            if Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, player.ControllerIndex) then
                mod.selectIdx = (mod.selectIdx + 1) % i
            elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, player.ControllerIndex) then
                mod.selectIdx = (mod.selectIdx - 1) % i
            elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, player.ControllerIndex) then
            if selectedKey then
                    if cfgLimits[selectedKey] then
                        cfg[selectedKey] = (cfg[selectedKey] - 1) % (cfgLimits[selectedKey] + 1)
                    else
                        cfg[selectedKey] = not cfg[selectedKey]
                    end
                end
            elseif Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, player.ControllerIndex) then
            if selectedKey then
                    if cfgLimits[selectedKey] then
                        cfg[selectedKey] = (cfg[selectedKey] + 1) % (cfgLimits[selectedKey] + 1)
                    else
                        cfg[selectedKey] = not cfg[selectedKey]
                    end
                end
            end
        end
        cfg.ItemId = cfg.ItemIdHigh * 100 + cfg.ItemIdMid * 10 + cfg.ItemIdLow
    end
end

function mod:restart()
    if cfg.EdenStartItem then
        Isaac.ExecuteCommand("restart 9")
    else
        Isaac.ExecuteCommand("restart")
    end
end

function mod:onUpdate()
	local level = game:GetLevel()
	if level:GetStage() == 1 then
        local player = Isaac.GetPlayer(0)
		if mod:pressedCtrlR(player) then
            mod.restarting = true
			mod.showMenu = false
			mod.changedRoom = false
            mod.rReleased = false
            mod:restart()
		elseif mod.restarting and not mod:isLevelOk(level, player) then
            if not mod:heldR(player) then
                mod.rReleased = true
            elseif mod.rReleased then
                mod.restarting = false
                print('restart canceled')
                return
            end
            mod.restarting = true
            mod:restart()
		else
            mod.restarting = false
			if mod.changedRoom then
				if level:GetCurrentRoomIndex() == mod.foundRoomId then
					if not mod:isCurrentRoomItemOk() then
						mod.changedRoom = false
						mod.foundRoomId = -1
						mod.restarting = true
                        mod:restart()
					else
						mod.changedRoom = false
						mod.foundRoomId = -1
                        if game:IsGreedMode() then
                            for i = 0, game:GetNumPlayers() - 1 do
                                local playerI = Isaac.GetPlayer(i)
                                playerI.Position = Vector(600, 400)
                            end
                        end
                        -- if (cfg.EntireFloor or level:GetCurrentRoom():GetType() ~= RoomType.ROOM_TREASURE) and not game:IsGreedMode() then
                        --     print('teleporting back to starting room')
                        --     player:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS)
                        -- end
						-- game:ChangeRoom(level:GetStartingRoomIndex(), -1)
						-- game:StartRoomTransition(level:GetStartingRoomIndex(), Direction.NO_DIRECTION, RoomTransitionAnim.WALK, Isaac.GetPlayer(0), -1)
					end
				end
			elseif not game:IsPaused() and mod:pressedR(player) then
				mod.showMenu = not mod.showMenu
			end
		end
	end
end

mod:AddPriorityCallback(ModCallbacks.MC_POST_RENDER, CallbackPriority.IMPORTANT, mod.onRender)
mod:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, CallbackPriority.IMPORTANT, mod.onUpdate)
