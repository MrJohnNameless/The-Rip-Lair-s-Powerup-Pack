--[[

	From MrDoubleA's NPC Pack

]]

local npcManager = require("npcManager")
local clearpipe = require("blocks/ai/clearpipe")

local ai = require("powerups/smmspikePowerup")

local spikeball = {}
local npcID = NPC_ID

local spikeballSettings = {
	id = npcID,
	
	gfxwidth = 28,
	gfxheight = 28,
	gfxoffsetx = 0,
	gfxoffsety = 2,
	width = 24,
	height = 24,
	
	frames = 1,
	framespeed = 8,
	framestyle = 0,
	
	speed = 1,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= true,
	nowaterphysics = false,
	jumphurt = true,
	spinjumpsafe = true,
	harmlessgrab = false,
	harmlessthrown = false,

	issnowball = false,
	islarge = false,

	startingSpeed = 2.5, -- What speed to start at when spawned.
	bounceHeight = 4, -- Height of bounce.

	slopeAcceleration = 0.05,
	useOldSlopeAcceleration = false,
	maxSpeed = 16,
}

npcManager.setNpcSettings(spikeballSettings)
npcManager.registerDefines(npcID, {NPC.HITTABLE})
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_NPC,
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_LAVA,
		HARM_TYPE_HELD,
		HARM_TYPE_TAIL,
		HARM_TYPE_OFFSCREEN,
		HARM_TYPE_SWORD,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
	}
)

clearpipe.registerNPC(npcID)

ai.registerBall(npcID)

return spikeball