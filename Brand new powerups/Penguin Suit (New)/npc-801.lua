local npcManager = require("npcManager")
local ai = require("penguin_ai")
local penguin = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local penguinSuit = cp.addPowerup("Penguin Suit", "powerups/penguinSuit", npcID)
cp.transformWhenSmall(npcID, 9)

local penguinSettings = {
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

npcManager.setNpcSettings(penguinSettings)
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

ai.register(npcID)

function penguin.onInitAPI()
	npcManager.registerEvent(npcID, penguin, "onTickNPC")
	registerEvent(penguin, "onNPCHarm")
end

function penguin.onTickNPC(v)
	if v:mem(0x138,FIELD_WORD) == 1 then
		v.direction = v.spawnDirection
	end
end

function penguin.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

return penguin