local npcManager = require("npcManager")
local smallFireFlowerPowerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local smallFireFlower = cp.addPowerup("Small Fire Flower", "powerups/smallFireFlower", npcID)
cp.transformWhenSmall(npcID, 9)

local smallFireFlowerPowerupSettings = {
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

npcManager.setNpcSettings(smallFireFlowerPowerupSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

function smallFireFlowerPowerup.onInitAPI()
	registerEvent(smallFireFlowerPowerup, "onNPCHarm")
	registerEvent(smallFireFlowerPowerup, "onNPCCollect")
end

function smallFireFlowerPowerup.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

function smallFireFlowerPowerup.onNPCCollect(token,v,p) 
	if not NPC.POWERUP_MAP[v.id] then return end
	if cp.getCurrentPowerup(p) ~= smallFireFlower then return end
	p.reservePowerup = npcID
end

return smallFireFlowerPowerup