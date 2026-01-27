
local npcManager = require("npcManager")
local fog = {}
local npcID = NPC_ID

local particles = require("particles")

local cp = require("customPowerups")
local fog = cp.addPowerup("Fog Dandelion", "powerups/fogDandelion", npcID)
cp.transformWhenSmall(npcID, 9)

local fogSettings = {
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

npcManager.setNpcSettings(fogSettings)
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

function fog.onInitAPI()
	registerEvent(fog, "onNPCHarm")
	npcManager.registerEvent(npcID, fog, "onStartNPC")
	npcManager.registerEvent(npcID, fog, "onDrawNPC")
end

function fog.onStartNPC(v)
	v.data.particle = particles.Emitter(0,0, "powerups/fog_dandelion_particle.ini")
	v.data.particle:Attach(v)
	v.data.particle:setPrewarm(5)
	v.data.particle:setParam("yOffset",0)
end

function fog.onDrawNPC(v)
	if v.despawnTimer <= 0 then return end
	if not v.data.particle then return end
	
	if not Misc.isPaused() and lunatime.tick() % 48 == 0 then
		v.data.particle:Emit()
	end
	
	v.data.particle:Draw(-45 - 0.01)
end

function fog.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

return fog