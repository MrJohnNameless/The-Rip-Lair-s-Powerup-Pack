local AI = require("AI/laserShot")
local npcManager = require("npcManager")

local sampleNPC = {}
local npcID = NPC_ID

local sampleNPCSettings = {
	id = npcID,

	gfxwidth = 48,
	gfxheight = 10,

	-- hitbox that is used to check collision
	width = 10,
	height = 10,
	
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	nohurt = true,
	nogravity = true,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi = true,
	nowaterphysics = true,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	ignorethrownnpcs = true,
	notcointransformable = true,
	terminalvelocity = 16,

	-- hitbox that is used to hurt npcs
	realWidth = 24,
	realHeight = 10,

	-- lifetime
	lifetime = 0,
}

npcManager.setNpcSettings(sampleNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_HELD,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_PROJECTILE_USED]=10,
		[HARM_TYPE_HELD]=10,
		[HARM_TYPE_OFFSCREEN]=10,
	}
);

AI.register(npcID)

return sampleNPC