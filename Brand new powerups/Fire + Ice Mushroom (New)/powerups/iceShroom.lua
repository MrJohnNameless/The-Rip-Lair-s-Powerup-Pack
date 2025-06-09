local cp = require("customPowerups")
local ai = require("powerups/fireIceShroom_ai")

local iceShroom = {}

iceShroom.forcedStateType = 2 
iceShroom.basePowerup = PLAYER_BIG
iceShroom.cheats = {"needaicemushroom","needaiceshroom","needanicemushroom","needaniceshroom","iceonthehill","liarliarpantsonthinice","subzero","finnland","snowballearth"}
iceShroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

function iceShroom.onInitPowerupLib()
	iceShroom.spritesheets = {
		iceShroom:registerAsset(CHARACTER_MARIO, "iceShroom-mario.png"),
		iceShroom:registerAsset(CHARACTER_LUIGI, "iceShroom-luigi.png"),
	}
end

function iceShroom.onEnable(p)	
	ai.pulseThePlayer(p, true)
	p.data.iceShroom = {
		projectileTimer = 0
	}
end

function iceShroom.onDisable(p)	
	p.data.iceShroom = nil
end

function iceShroom.onTickPowerup(p) 
	if not p.data.iceShroom then return end
	local data = p.data.iceShroom

	ai.onTickShroom(p, data, true)
end

function iceShroom.onTickEndPowerup(p)
	if not p.data.iceShroom then return end
	local data = p.data.iceShroom
end

function iceShroom.onDrawPowerup(p)
	if not p.data.iceShroom then return end
	local data = p.data.iceShroom

	ai.onDrawShroom(p, data, true)
end

return iceShroom