local cp = require("customPowerups")
local ai = require("powerups/acorn_AI")

-- See acorn_AI.lua for full credits.

local superAcorn = {}
local checkedForLevelEnd = false

superAcorn.forcedStateType = 2 
superAcorn.basePowerup = PLAYER_FIRE
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

function superAcorn.onInitAPI()
    registerEvent(superAcorn, "onTick")
    cp = require("customPowerups")
end

function superAcorn.onTick()
    if checkedForLevelEnd then return end

    if Level.endState() ~= 0 then
        checkedForLevelEnd = true

        for _, p in ipairs(Player.get()) do
            if cp.getCurrentPowerup(p) == superAcorn then
                cp.setPowerup("Super Acorn", p, true)

                for i = 1, 10 do
                    local e =  Effect.spawn(80, p.x - 8 + RNG.random(p.width + 8), p.y - 4 + RNG.random(p.height + 8))
                    e.speedX = RNG.random(6) - 3
                    e.speedY = RNG.random(6) - 3
                end
            end
        end
    end
end

return superAcorn