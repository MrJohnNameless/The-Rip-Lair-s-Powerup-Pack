local npcManager = require("npcManager")
local miniMush = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local miniMushroom = cp.addPowerup("Mini Mushroom", "powerups/miniMushroom", npcID)

local miniMushSettings = {
	id = npcID,
	gfxheight = 16,
	gfxwidth = 16,
	gfxoffsety = 2,
	width = 16,
	height = 16,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 0.85,
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
	luahandlesspeed = true,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	ignorethrownnpcs = true,
	notcointransformable = true,
}

npcManager.setNpcSettings(miniMushSettings)
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

function miniMush.onInitAPI()
	npcManager.registerEvent(npcID, miniMush, "onTickNPC")
	registerEvent(miniMush,"onNPCHarm")
	registerEvent(miniMush,"onNPCCollect")
end

function miniMush.onTickNPC(v)
	if Defines.levelFreeze or v.despawnTimer <= 0 or v.forcedState ~= 0 or v.isProjectile or v.dontMove then return end
	
	v.speedX = NPC.config[v.id].speed * v.direction
end

function miniMush.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function miniMush.onNPCCollect(token,v,p) -- implement manually adding the mini mushroom to a player's reserve box
	if not NPC.POWERUP_MAP[v.id] then return end
	if cp.getCurrentPowerup(p) ~= miniMushroom then return end
	p.reservePowerup = npcID
end

return miniMush