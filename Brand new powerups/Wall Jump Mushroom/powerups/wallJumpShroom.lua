local wallJumpShroom = {}
local aw = require("anotherwalljump")
local cp = require("customPowerups")

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function wallJumpShroom.onInitPowerupLib()
    wallJumpShroom.spritesheets = {
        wallJumpShroom:registerAsset(1, "wallJumpMario.png"),
        wallJumpShroom:registerAsset(2, "wallJumpLuigi.png"),
        wallJumpShroom:registerAsset(3, "wallJumpPeach.png"),
        wallJumpShroom:registerAsset(4, "wallJumpToad.png"),
    }
end

wallJumpShroom.basePowerup = PLAYER_BIG

wallJumpShroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

registerEvent(wallJumpShroom, "onExitLevel", "onExitLevel")
registerEvent(wallJumpShroom, "onExit", "onExit")

function wallJumpShroom.onExit()
	for _,p in ipairs(Player.get()) do
		aw.disable(p)
	end
end

--Reset walk and run speed cause being in the water doubles it
function wallJumpShroom.onExitLevel(winType)
	for _,p in ipairs(Player.get()) do
		aw.disable(p)
	end
end

function wallJumpShroom.onEnable(p)
	aw.enable(p)
end

function wallJumpShroom.onDisable(p)
	aw.disable(p)
end

function wallJumpShroom.onTickPowerup(p)
	if cp.getCurrentName(activePlayer) == "Wall Jump Mushroom" then aw.enable(p) end
end

return wallJumpShroom