local npcManager = require("npcManager")
local jetpack = {}
local npcID = NPC_ID

local jetpackSettings = {
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
	powerup = false,
	nohurt=true,
	nogravity = true,
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

npcManager.setNpcSettings(jetpackSettings)
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

function jetpack.onInitAPI()
	registerEvent(jetpack, "onNPCHarm")
	registerEvent(jetpack, "onPostNPCCollect")
end


function jetpack.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function jetpack.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	if not p.data.superJetpack then return end
	Effect.spawn(10,v)
	p.data.superJetpack.bar.value = 1
	SFX.play(23)
	SFX.play(7)
end

return jetpack