local npcManager = require("npcManager")
local weirdShroomPowerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local weirdShroom = cp.addPowerup("Weird Mushroom", "powerups/weirdShroom", npcID)

local weirdShroomPowerupSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 28,
	gfxoffsety = 2,
	width = 28,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
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

	luahandlesspeed = true,
}

npcManager.setNpcSettings(weirdShroomPowerupSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
	}
);

function weirdShroomPowerup.onInitAPI()
	npcManager.registerEvent(npcID, weirdShroomPowerup, "onTickEndNPC")
	registerEvent(weirdShroomPowerup, "onNPCHarm")
end

function weirdShroomPowerup.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	if v.heldIndex ~= 0 
	or v.isProjectile   
	or v.forcedState > 0
	then return end
	
	v.speedX = 1.8 * v.direction
end

function weirdShroomPowerup.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

return weirdShroomPowerup