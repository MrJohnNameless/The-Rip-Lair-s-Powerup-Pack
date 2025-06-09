local npcManager = require("npcManager")
local chicken = {}
local npcID = NPC_ID

-- calls in Capt.Monochrome's Penguin Suit NPC AI to let the npc act like it
local ai
pcall(function() ai = require("penguin_ai") end)

local cp = require("customPowerups")
local chickenSuit = cp.addPowerup("Chicken Suit", "powerups/chickenSuit", npcID)
cp.transformWhenSmall(npcID, 9)

local chickenSettings = {
	id = npcID,
	gfxwidth = 32,
	gfxheight = 38,
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

npcManager.setNpcSettings(chickenSettings)
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

-- give the powerup npc, the penguin suit's movement & rotation AI of their powerup NPC
if ai then
	ai.register(npcID)
end

function chicken.onInitAPI()
	registerEvent(chicken, "onNPCHarm")
end

function chicken.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

return chicken