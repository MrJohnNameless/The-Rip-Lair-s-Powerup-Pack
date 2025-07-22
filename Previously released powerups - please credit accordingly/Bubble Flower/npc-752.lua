local npcManager = require("npcManager")
local AI = require("AI/smbw_bubble")
local bubble = {}
local npcID = NPC_ID
local deathEffect = npcID

local bubbleSettings = {
	id = npcID,
	gfxheight = 68,
	gfxwidth = 68,

	width = 48,
	height = 48,

	frames = 4,
	framestyle = 0,
	framespeed = 6, --# frames between frame change

	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.

	score = 0,

	nohurt=true,
	nogravity = true,
	noblockcollision = true,
	nofireball = true,
	noiceball = true,
	noyoshi= true,
	nowaterphysics = true,

	jumphurt = false, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false

	grabside=false,
	grabtop=false,

	isinteractable = false,
	ignorethrownnpcs = true,
	notcointransformable = true,

	thrownSpeed = 3,
	lifetime = 256,
	flashSpeed = 16,
	warningFrames = 64,
}

npcManager.setNpcSettings(bubbleSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_JUMP,
		HARM_TYPE_NPC,
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_HELD,
		HARM_TYPE_TAIL,
		HARM_TYPE_SPINJUMP,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_JUMP]=deathEffect,
		[HARM_TYPE_NPC]=deathEffect,
		[HARM_TYPE_PROJECTILE_USED]=deathEffect,
		[HARM_TYPE_HELD]=deathEffect,
		[HARM_TYPE_TAIL]=deathEffect,
		[HARM_TYPE_SPINJUMP]=deathEffect,
		[HARM_TYPE_OFFSCREEN]=deathEffect,
	}
)

AI.register(npcID)

for k, id in ipairs{15, 39, 44, 86, 200, 201, 209, 262, 267, 268, 280, 281} do
	AI.blacklist(id)
end

return bubble