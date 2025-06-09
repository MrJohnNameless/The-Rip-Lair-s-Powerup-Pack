local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local powerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local invertedMushroom = cp.addPowerup("Inverted Mushroom", "powerups/invertedMushroom", npcID)

local powerupSettings = {
	id = npcID,
	
	gfxheight = 32,
	gfxwidth = 32,
	
	width = 32,
	height = 32,
	
	gfxoffsetx = 0,
	gfxoffsety = 0,
	
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	
	speed = 1.5,
	
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
	iswalker = true,
	score = SCORE_1000,
}

npcManager.setNpcSettings(powerupSettings)
npcManager.registerHarmTypes(npcID,{HARM_TYPE_OFFSCREEN},{})

return powerup