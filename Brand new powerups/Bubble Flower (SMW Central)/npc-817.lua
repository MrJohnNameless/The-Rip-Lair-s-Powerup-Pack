local npcManager = require("npcManager")
local AI = require("AI/smbw_bubble_smw")
local bubble = {}
local npcID = NPC_ID
local deathEffect = npcID

local bubbleSettings = {
	id = npcID,
	gfxheight = 44,
	gfxwidth = 44,

	width = 32,
	height = 32,

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

	thrownSpeed = 2,
	lifetime = 32,
	
	reward = 33,
	rewardFrames = 4,
	rewardFramesOffset = 0,
}

npcManager.setNpcSettings(bubbleSettings)

npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_JUMP
	}
)

AI.register(npcID)

for k, id in ipairs{15, 39, 44, 86, 200, 201, 209, 262, 267, 268, 280, 281} do
	AI.blacklist(id)
end

return bubble