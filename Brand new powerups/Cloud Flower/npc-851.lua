local npcManager = require("npcManager")
local flower = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local cloudFlower = cp.addPowerup("Cloud Flower", "powerups/cloudFlower", npcID)
cp.transformWhenSmall(npcID, 9)

local flowerSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
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

npcManager.setNpcSettings(flowerSettings)
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

function flower.onInitAPI()
	registerEvent(flower, "onPostNPCCollect")
end

function flower.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	
	if v.forcedState == 2 then p.reservePowerup = 0 return end
	if not p.data.cloudFlower then return end
	local data = p.data.cloudFlower
		
	for i = #data.clouds,1,-1 do
		table.remove(data.clouds, i) -- disowns all the current clouds spawned by the player, allowing them to freely spawn more
		SFX.play(82)
	end
end

return flower