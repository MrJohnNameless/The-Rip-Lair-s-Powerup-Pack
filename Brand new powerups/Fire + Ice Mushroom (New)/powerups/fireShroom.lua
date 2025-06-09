local cp = require("customPowerups")
local ai = require("powerups/fireIceShroom_ai")

local fireShroom = {}

fireShroom.forcedStateType = 2 
fireShroom.basePowerup = PLAYER_BIG
fireShroom.cheats = {"needafiremushroom","needafireshroom","fireinthehole","liarliarpantsonfire","inferno","leasthotdayinthephilippines","australia","globalwarming"}
fireShroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

function fireShroom.onInitPowerupLib()
	fireShroom.spritesheets = {
		fireShroom:registerAsset(CHARACTER_MARIO, "fireShroom-mario.png"),
		fireShroom:registerAsset(CHARACTER_LUIGI, "fireShroom-luigi.png"),
	}
end

function fireShroom.onEnable(p)	
	ai.pulseThePlayer(p, false)
	p.data.fireShroom = {
		projectileTimer = 0
	}
end

function fireShroom.onDisable(p)	
	p.data.fireShroom = nil
end

function fireShroom.onTickPowerup(p) 
	if not p.data.fireShroom then return end
	local data = p.data.fireShroom

	ai.onTickShroom(p, data, false)
end

function fireShroom.onTickEndPowerup(p)
	if not p.data.fireShroom then return end
	local data = p.data.fireShroom
end

function fireShroom.onDrawPowerup(p)
	if not p.data.fireShroom then return end
	local data = p.data.fireShroom

	ai.onDrawShroom(p, data, false)
end

return fireShroom