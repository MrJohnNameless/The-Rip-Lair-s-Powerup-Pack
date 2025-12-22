--[[

    Cape for anotherpowerup.lua
    by MrDoubleA

    Credit to JDaster64 for the SMW physics guide
    Graphics from AwesomeZackC

]]

local npcManager = require("npcManager")
local powerupLib = require("powerups/cp_laser")

local powerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local capefeather = cp.addPowerup("Laser Suit", "powerups/cp_laser", npcID, true)

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
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	powerup = true,
	nohurt = true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi = false,
	nowaterphysics = false,
	
	jumphurt = false,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	score = SCORE_1000,
}

npcManager.setNpcSettings(powerupSettings)
npcManager.registerHarmTypes(npcID,{HARM_TYPE_OFFSCREEN},{})


return powerup
