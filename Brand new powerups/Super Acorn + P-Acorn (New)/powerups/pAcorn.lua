local cp = require("customPowerups")
local ai = require("powerups/acorn_AI")

-- See acorn_AI.lua for full credits.

local superAcorn = {}

superAcorn.forcedStateType = 2 
superAcorn.basePowerup = PLAYER_BIG
superAcorn.cheats = {"needapacorn","superflyingsquirrel","cheatingnut"}
superAcorn.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

-- P-Acorn setting
superAcorn.isCheating = true

-- Sprites and hitboxes
function superAcorn.onInitPowerupLib()
	superAcorn.spritesheets = {
		superAcorn:registerAsset(CHARACTER_MARIO, "mario-pAcorn.png"),
		superAcorn:registerAsset(CHARACTER_LUIGI, "luigi-pAcorn.png"),
	}

	superAcorn.iniFiles = {
		superAcorn:registerAsset(CHARACTER_MARIO, "mario-acorn.ini"),
		superAcorn:registerAsset(CHARACTER_LUIGI, "luigi-acorn.ini"),
	}
end

-- The rest is handled by the global acorn AI

local activePlayer

function superAcorn.onEnable(p)	
	ai.onEnableAcorn(p, superAcorn)
end

function superAcorn.onDisable(p)	
	ai.onDisableAcorn(p, superAcorn)
end

function superAcorn.onTickPowerup(p) 
	ai.onTickAcorn(p, superAcorn, superAcorn.isCheating)
	activePlayer = p
end

function superAcorn.onDrawPowerup(p)
	ai.onDrawAcorn(p, superAcorn)
end

-- Revert the player back

registerEvent(superAcorn, "onExit")

function superAcorn.onExit()
	if activePlayer and cp.getCurrentName(activePlayer) == "P-Acorn" then 
		cp.setPowerup("Super Acorn", activePlayer, true) 
	end
end

return superAcorn