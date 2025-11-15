--[[
				powerupRevert.lua by DeviousQuacks23
				
			A customPowerups plugin that allows registered powerups to revert back once clearing a level
				Use for Assist Powerups! (eg. Invincibility Leaf, P-Acorn, etc.)
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script is designed for (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
		     - also wrote the main reverting code, taken from Gold Flower script
	
	NOTE: customPowerups is recommended for this script! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")
local powerupRevert = {}

powerupRevert.validPowerups = {}
powerupRevert.revertedPowerups = {}
powerupRevert.revertEffects = {}
powerupRevert.doEffectVariation = {}

-- REGISTER FUNCTION VALUES:
-- powerup (required)		- the powerup that should be reverted upon exiting
-- revertPowerup (required)	- the powerup to revert to upon exiting
-- effect (optional) 		- the effect ID that should spawn when reverting
-- doVariation (optional) 	- if true, the effect variant will be the same as the character ID. used by gold flower.

function powerupRevert.register(powerup, revertPowerup, effect, doVariation)
	powerupRevert.validPowerups[powerup] = true
	powerupRevert.revertedPowerups[powerup] = revertPowerup

	-- Effect stuff

	if not effect then
		effect = 80
	end

	powerupRevert.revertEffects[powerup] = effect

	if not doVariation then
		doVariation = false
	end

	powerupRevert.doEffectVariation[powerup] = doVariation
end

function powerupRevert.onInitAPI()
	registerEvent(powerupRevert, "onDraw")
end

local checkedForLevelEnd = false

function powerupRevert.onDraw()
    	if checkedForLevelEnd then return end

    	if Level.endState() ~= 0 then
        	checkedForLevelEnd = true

        	for _, p in ipairs(Player.get()) do
            		if powerupRevert.validPowerups[cp.getCurrentName(p)] then
				local oldPowerup = cp.getCurrentName(p)
                		cp.setPowerup(powerupRevert.revertedPowerups[oldPowerup], p, true)

                		for i = 1, 10 do
                    			local e =  Effect.spawn(powerupRevert.revertEffects[oldPowerup], p.x - 8 + RNG.random(p.width + 8), p.y - 4 + RNG.random(p.height + 8), ((powerupRevert.doEffectVariation[oldPowerup] and p.character) or 1))
                    			e.speedX = RNG.random(6) - 3
                    			e.speedY = RNG.random(6) - 3
                		end
            		end
        	end
    	end
end

return powerupRevert