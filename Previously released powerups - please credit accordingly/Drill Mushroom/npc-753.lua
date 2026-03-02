local npcManager = require("npcManager")

local sampleNPC = {}
local npcID = NPC_ID

local cp = require("customPowerups")
cp.transformWhenSmall(npcID, 9)

local drill = cp.addPowerup("Drill", "powerups/drill", npcID)
drill.applyDefaultSettings()


local sampleNPCSettings = {
	id = npcID,
	gfxwidth = 32,
	gfxheight = 36,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 3,
	framestyle = 0,
	framespeed = 6,
	--luahandlesspeed = true,
	score = SCORE_1000,
	speed = 1.8,
	
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
	iswalker = true,
}

npcManager.setNpcSettings(sampleNPCSettings)
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

function sampleNPC.onInitAPI()
	registerEvent(sampleNPC, "onNPCHarm")
end

function sampleNPC.onNPCHarm(e, v, r, c)
	if v.id ~= npcID then
		return
	end
	
	if r == HARM_TYPE_TAIL or r == HARM_TYPE_FROMBELOW then
		SFX.play(2)
		v.speedY = -6
		e.cancelled = true
	end
end

return sampleNPC