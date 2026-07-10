local MOD_NAME = "Real Time Machine"
local mod = RegisterMod(MOD_NAME, 1)
local font = Font()
-- local sprite = Sprite()

local defaultConfig = {
	SpeedKey = Keyboard.KEY_SLASH,
	RateDownKey = Keyboard.KEY_COMMA,
	RateUpKey = Keyboard.KEY_PERIOD,
	SpeedRate = 4.0,
}
-- begin config
if ModConfigMenu then
	ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.KEYBIND_KEYBOARD, MOD_NAME, nil,
		"SpeedKey", nil, nil, nil, defaultConfig.SpeedKey, "Speed Key", nil, true,
		"Key to start speeding up")
	ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.KEYBIND_KEYBOARD, MOD_NAME, nil,
		"RateDownKey", nil, nil, nil, defaultConfig.RateDownKey, "Rate Down Key", nil, true,
		"Key to start speeding up")
	ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.KEYBIND_KEYBOARD, MOD_NAME, nil,
		"RateUpKey", nil, nil, nil, defaultConfig.RateUpKey, "Rate Up Key", nil, true,
		"Key to start speeding up")
	ModConfigMenu.SimpleAddSetting(ModConfigMenu.OptionType.NUMBER, MOD_NAME, nil,
		"SpeedRate", 0.25, 64.0, 0.25, defaultConfig.SpeedRate, "Speed Rate", nil, true,
		"Default speed up rate after pressing Speed Key")
    function mod:config() return ModConfigMenu.Config[MOD_NAME] end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContined)
        if mod:HasData() then
            local dat = mod:LoadData()
            mod._oldCfg = dat
            local json = require('json')
            local cfg = json.decode(dat)
            for k, v in pairs(cfg) do
                cfg[k] = v
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function(_, shouldSave)
        local json = require('json')
        local dat = json.encode(mod:config())
        if not mod._oldCfg or dat ~= mod._oldCfg then
            mod._oldCfg = dat
            mod:SaveData(dat)
        end
    end)
else
    function mod:config() return defaultConfig end
end

local nowSpeed = 1.0

function mod:setSpeed(speed)
    if nowSpeed == speed then return end
    nowSpeed = speed
    if IsaacSocket then
        if speed > 1.0 and Options.VSync then
            Options.VSync = false
        end
        IsaacSocket.IsaacAPI.SetFrameInterval(1 / 60 / speed)
    end
end

local wasEnabled = false
local alpha = 0.0
local accum = 0.0
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function(_)
    if Game():IsPaused() then return end
    local cfg = mod:config()
    local enabled = Input.IsButtonPressed(cfg.SpeedKey, 0)
    if enabled and not wasEnabled then
        mod:setSpeed(cfg.SpeedRate)
    elseif not enabled and wasEnabled then
        mod:setSpeed(1.0)
    end
    if Input.IsButtonTriggered(cfg.RateDownKey, 0) then
        if nowSpeed == 1.4 then
            mod:setSpeed(1.0)
        elseif nowSpeed == 2.0 then
            mod:setSpeed(1.4)
        elseif nowSpeed == 2.8 then
            mod:setSpeed(2.0)
        elseif nowSpeed == 4.0 then
            mod:setSpeed(2.8)
        else
            mod:setSpeed(math.max(nowSpeed * 0.5, 0.125))
        end
    end
    if Input.IsButtonTriggered(cfg.RateUpKey, 0) then
        if nowSpeed == 1.0 then
            mod:setSpeed(1.4)
        elseif nowSpeed == 1.4 then
            mod:setSpeed(2.0)
        elseif nowSpeed == 2.0 then
            mod:setSpeed(2.8)
        elseif nowSpeed == 2.8 then
            mod:setSpeed(4.0)
        else
            mod:setSpeed(math.min(nowSpeed * 2.0, 64.0))
        end
    end
    wasEnabled = enabled
    if nowSpeed ~= 1.0 then
        alpha = alpha + 0.4
    else
        alpha = alpha - 0.05
    end
    alpha = math.min(math.max(0, alpha), 1)
	if alpha > 0 then
        local omits = {'', '>', '>>'}
        local frame = Game():GetFrameCount()
        local fmtSpeed = nowSpeed % 1 == 0 and string.format('%dx', nowSpeed) or string.format('%.1fx', nowSpeed)
        if not font:IsLoaded() then
            font:Load("font/teammeatfont10.fnt")
        end
        -- if not sprite:IsLoaded() then
        --     sprite:Load("gfx/madeinheaven/speedwidget.anm2", true)
        -- end
        local scale = math.max(nowSpeed, 0.5)
        if not IsaacSocket then
            scale = 1
            if nowSpeed < 1 then
                omits = {'<1x needs IsaacSocket!'}
            end
        end
        font:DrawString(
            string.format('%s %s', fmtSpeed,
                omits[math.floor(frame / (scale * 12)) % #omits + 1]),
            -- 70, 40, KColor(1, 1, #omits == 1 and 0 or 1, alpha))
            145, 90, KColor(1, 1, #omits == 1 and 0 or 1, alpha))
        -- font:DrawString(
        --     string.format('Real Time Machine (%s) %s', fmtSpeed,
        --         omits[math.floor(frame / (scale * 12)) % #omits + 1]),
        --     70, 40, KColor(1, 1, 1, alpha))
	end
    if not IsaacSocket and nowSpeed > 1 then
        local n = math.floor(nowSpeed - 1)
        local f = nowSpeed - 1 - n
        if f ~= 0 then
            if accum > f then
                n = n + 1
                accum = accum - 1
            else
                accum = accum + f
            end
        end
        if n > 0 then
            for _, e in ipairs(Isaac.GetRoomEntities()) do
                for _ = 1, n do
                    e:Update()
                end
            end
            local oldTime = Game().TimeCounter
            Game().TimeCounter = oldTime + n
            if math.floor(oldTime / 1800) ~= math.floor((oldTime + n) / 1800) then
                for i = 0, Game():GetNumPlayers() - 1 do
                    local player = Isaac.GetPlayer(i)
                    if player:HasCollectible(CollectibleType.COLLECTIBLE_PLACENTA) then
                        if not player:HasFullHearts() then
                            if Random() > 0.5 + 1 / (2 + n) then
                                player:AddHearts(1)
                                SFXManager():Play(SoundEffect.SOUND_THUMBSUP, 0.4, 0, false, 0.7, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContined)
    wasEnabled = false
end)

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function(_, shouldSave)
    mod:setSpeed(1)
    wasEnabled = false
end)
