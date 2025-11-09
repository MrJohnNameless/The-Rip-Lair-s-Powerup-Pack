local npcManager = require("npcManager")
local jumper = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local jumpingLui = cp.addPowerup("Jumping Lui", "powerups/jumpingLui", npcID)
cp.transformWhenSmall(npcID, 9)

local jumperSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 0,
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
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	ignorethrownnpcs = true,
	notcointransformable = true,
}

npcManager.setNpcSettings(jumperSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

function jumper.onInitAPI()
	npcManager.registerEvent(npcID, jumper, "onTickNPC")
end

function jumper.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 or v.forcedState ~= 0 or v.heldIndex ~= 0 then return end
	
	if v.collidesBlockBottom and not v.dontMove then 
		v.speedY = -9
	end
	
end

return jumper
