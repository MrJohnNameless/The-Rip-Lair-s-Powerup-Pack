local npcManager = require("npcManager")
local powerup = require("powerups/bigShroom")
local bigShroomPowerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local bigShroom = cp.addPowerup("Big Mushroom", "powerups/bigShroom", npcID)
cp.transformWhenSmall(npcID, 9)

local bigShroomPowerupSettings = {
	id = npcID,
	gfxheight = 64,
	gfxwidth = 64,
	gfxoffsety = 2,
	width = 64,
	height = 64,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 1.5,
	iswalker = true,
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

npcManager.setNpcSettings(bigShroomPowerupSettings)
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

function bigShroomPowerup.onInitAPI()
	registerEvent(bigShroomPowerup, "onNPCHarm")
end

function bigShroomPowerup.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

return bigShroomPowerup