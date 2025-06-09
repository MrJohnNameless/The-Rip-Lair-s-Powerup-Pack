local npcManager = require("npcManager")
local cp = require("customPowerups")
local powerup = require("powerups/flyingStar")
local flyingStar = {}
local npcID = NPC_ID

local flyingStar = cp.addPowerup("Red Star", "powerups/flyingStar", npcID)

local flyingStarSettings = {
	id = npcID,
	gfxheight = 38,
	gfxwidth = 36,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 1,
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
	nogravity = true,
	noblockcollision = true,
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

npcManager.setNpcSettings(flyingStarSettings)
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

function flyingStar.onInitAPI()
	npcManager.registerEvent(npcID, flyingStar, "onTickEndNPC")
	Cheats.register("needaredstar",{
		isCheat = true,
		activateSFX = 12,
		aliases = powerup.aliases,
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function flyingStar.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	local data = v.data

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.hasStopped = false
	end

	if v.heldIndex ~= 0  -- Negative when held by NPCs, positive when held by players
	or v.isProjectile    -- Thrown
	or v.forcedState > 0 -- Various forced states
	then
		return
	end

	v.speedX = v.speedX * 0.97
	v.speedY = v.speedY* 0.97

	if math.abs(v.speedX) < 0.1 then
		v.speedX = 0
	end

	if math.abs(v.speedY) < 0.1 and data.hasStopped == false then
		data.hasStopped = true
		v.speedY = 0
	end
	
	if data.hasStopped == true then
		v.speedY = math.sin(lunatime.tick() / 12)
	end
end

return flyingStar