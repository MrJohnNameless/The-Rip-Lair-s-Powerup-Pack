local npcManager = require("npcManager")
local sampleNPC = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local goldFlower = cp.addPowerup("Gold Flower", "powerups/goldFlower", npcID)

local sampleNPCSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	width = 32,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 0,
	score = SCORE_1000,
	
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

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	ignorethrownnpcs = true,
	notcointransformable = true,

	sparkleEffect = npcID - 1,
}

npcManager.setNpcSettings(sampleNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA] = {id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_OFFSCREEN] = nil,
	}
);

function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
end

function sampleNPC.onTickNPC(v)
	if Defines.levelFreeze or v.forcedState > 0 then return end

	if RNG.randomInt(1, 15) == 1 then
		local e = Effect.spawn(NPC.config[v.id].sparkleEffect, v.x + RNG.randomInt(0, v.width), v.y + RNG.randomInt(0, v.height))
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
	end
end

return sampleNPC