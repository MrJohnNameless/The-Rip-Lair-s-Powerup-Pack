local npcManager = require("npcManager")

local sampleNPC = {}
local npcID = NPC_ID

local sampleNPCSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,

	width = 24,
	height = 24,

	frames = 2,
	framestyle = 0,
	framespeed = 8, --# frames between frame change

	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.

	nohurt = true,
	nogravity = false,
	noblockcollision = true,
	nofireball = false,
	noiceball = false,
	noyoshi = true,
	nowaterphysics = true,

	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false

	grabside = false,
	grabtop = false,
	score = 0,
	foreground = true,

	isinteractable = false,
	ignorethrownnpcs = true,
	notcointransformable = true,
	staticdirection = true,
}

npcManager.setNpcSettings(sampleNPCSettings)
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

function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
end

function sampleNPC.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data

	if v.despawnTimer <= 0 then
		return
	end

	if v.heldIndex ~= 0  -- Negative when held by NPCs, positive when held by players
	or v.isProjectile    -- Thrown
	or v.forcedState > 0 -- Various forced states
	then
		return
	end

	for k, n in ipairs(Colliders.getColliding{a = v, b = NPC.HITTABLE, btype = Colliders.NPC}) do
		if n.id ~= v.id then
			n:harm(HARM_TYPE_NPC)
		end
	end
end

return sampleNPC