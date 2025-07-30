local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local powerupLib = require("powerups/ap_carrot")

local powerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local carrot = cp.addPowerup("Carrot", "powerups/ap_carrot", npcID)
cp.transformWhenSmall(npcID, 9)

local powerupSettings = {
	id = npcID,
	
	gfxheight = 32,
	gfxwidth = 32,
	
	width = 32,
	height = 32,
	
	gfxoffsetx = 0,
	gfxoffsety = 2,
	
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	
	speed = 1,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	powerup = true,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = true,
	
	jumphurt = false,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	score = SCORE_1000,
}

function powerup.onInitAPI()
	Cheats.register("needacarrot",{
		isCheat = true,
		activateSFX = 12,
		aliases = powerupLib.aliases,
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

npcManager.setNpcSettings(powerupSettings)
npcManager.registerHarmTypes(npcID,{HARM_TYPE_OFFSCREEN},{})

return powerup