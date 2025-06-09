local npcManager = require("npcManager")
local cp = require("customPowerups")
local shell = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local blueShell = cp.addPowerup("Blue Shell", "powerups/blueShell", npcID)
cp.transformWhenSmall(npcID, 9)

local shellSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 2,
	framestyle = 0,
	framespeed = 8,
	speed = 1,
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

npcManager.setNpcSettings(shellSettings)
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

function shell.onInitAPI()
	npcManager.registerEvent(npcID, shell, "onTickEndNPC")
end

function shell.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	if v.despawnTimer <= 0 then
		if v.data.lastNPC then
			v:transform(v.data.lastNPC)
		end
	end
	
	if v.data.variant then
		v.animationFrame = math.max(v.data.variant - 1, 0)
	else
		v.animationFrame = 0
	end
end

return shell