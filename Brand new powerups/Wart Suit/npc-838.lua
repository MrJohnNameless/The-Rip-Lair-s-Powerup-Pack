local npcManager = require("npcManager")
local powerup = require("powerups/wartSuit")
local jumper = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local wartSuit = cp.addPowerup("Wart Suit", "powerups/wartSuit", npcID)

local jumperSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 0,
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

npcManager.setNpcSettings(jumperSettings)
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

function jumper.onInitAPI()
	npcManager.registerEvent(npcID, jumper, "onTickNPC")
	registerEvent(jumper, "onPostNPCCollect")
end

function jumper.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 or v.forcedState ~= 0 or v.heldIndex ~= 0 then return end
	
	if not v.isHidden and v:mem(0x124, FIELD_WORD) ~= 0 --[[new spawn]] then
		if math.abs(v.speedX) < 1.5 * NPC.config[npcID].speed then
			v.speedX = v.direction * 1.5 * NPC.config[npcID].speed
		else
			v.speedX = v.speedX * 0.99
		end
	end
	
	if v.collidesBlockBottom then
		v.speedY = -8
	elseif v.collidesBlockUp then
		v.speedY = 2
	end
	
end

function jumper.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	
	if v.forcedState == 2 then p.reservePowerup = 0 return end
end

return jumper