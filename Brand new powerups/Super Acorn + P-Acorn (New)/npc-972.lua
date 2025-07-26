local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local AI = require("powerups/acorn_AI")

local superAcornPowerup = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local superAcorn = cp.addPowerup("P-Acorn", "powerups/pAcorn", npcID)

local superAcornPowerupSettings = {
	id = npcID,
	gfxheight = 40,
	gfxwidth = 32,
	gfxoffsety = 6,
	width = 32,
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

	luahandlesspeed = true
}

npcManager.setNpcSettings(superAcornPowerupSettings)
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

AI.register(npcID)

return superAcornPowerup