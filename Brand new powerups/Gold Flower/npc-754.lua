local npcManager = require("npcManager")
local AI = require("AI/goldFireBall")

local goldBall = {}
local npcID = NPC_ID

local goldBallSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,

	width = 24,
	height = 24,

	frames = 4,
	framestyle = 0,
	framespeed = 4, --# frames between frame change

	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.

	nohurt = true,
	nogravity = false,
	noblockcollision = false,
	nofireball = false,
	noiceball = false,
	noyoshi = true,
	nowaterphysics = false,

	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false

	grabside = false,
	grabtop = false,
	score = 0,

	isinteractable = false,
	ignorethrownnpcs = true,
	notcointransformable = true,
	staticdirection = true,

	useclearpipe = true,

	sparkleEffect = npcID,
	trailEffect = npcID + 1,
	variants = 5,
	collisionGroup = "npc-" .. npcID,
}

npcManager.setNpcSettings(goldBallSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_PROJECTILE_USED] = nil,
		[HARM_TYPE_OFFSCREEN] = nil,
	}
)

AI.register(npcID)

return goldBall