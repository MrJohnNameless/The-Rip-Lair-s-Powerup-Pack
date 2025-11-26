local npcManager = require("npcManager")
local dashFruit = require("powerups/dashFruit")
local cp = require("customPowerups")
local dashCrystal = {}
local npcID = NPC_ID

local templateSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 0,
	width = 32,
	height = 32,
	frames = 2,
	framestyle = 0,
	framespeed = 8,
	speed = 0,
	score = SCORE_1000,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
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

	ignorethrownnpcs = true,
	notcointransformable = true,
}

npcManager.setNpcSettings(templateSettings)
npcManager.registerHarmTypes(npcID,
	{
		-- HARM_TYPE_FROMBELOW,
		-- HARM_TYPE_LAVA,
		-- HARM_TYPE_TAIL,
		-- HARM_TYPE_OFFSCREEN,
	}, 
	{
		-- [HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

local breakSFX = "powerups/dashCrystal-break.ogg"
local refillSFX = "powerups/dashCrystal-refill.ogg"

function dashCrystal.onInitAPI()
	npcManager.registerEvent(npcID, dashCrystal, "onTickEndNPC")
end

function dashCrystal.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	local p = player
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.initialized = true
		data.cooldown = 0
		data.canRefill = true
		data.sinTimer = RNG.random(0, 50)
	end

	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		-- Handling of those special states. Most NPCs want to not execute their main code when held/coming out of a block/etc.
		-- If that applies to your NPC, simply return here.
		-- return
	end
	
	data.sinTimer = data.sinTimer + 1
	
	v.speedY = math.sin(data.sinTimer * 0.05) * 0.2
	
	for _,p in ipairs(Player.get()) do
		if cp.getCurrentName(p) == "dashFruit" and Colliders.collide(p, v) and p.data.dashFruit.dashAmount == 0 and data.canRefill and data.cooldown == 0 then
			for _,p in ipairs(Player.getIntersecting(v.x, v.y, v.x + p.width, v.y + p.height)) do
				p.data.dashFruit.dashAmount = dashFruit.settings.dashes
				p.data.dashFruit.cooldown = 0
				p.data.dashFruit.dashUsedUp = p.data.dashFruit.dashUsedUp - 1
				p.data.dashFruit.canDash = true
				p.data.dashFruit.lastDashAmount = p.data.dashFruit.dashAmount
				p.data.dashFruit.moreThanOneDash = true
				data.canRefill = false
				SFX.play(breakSFX, 0.5)
				if not dashFruit.settings.disableScreenShake then
					Defines.earthquake = 6
				end
				dashFruit.spawnSparkles1(p)
				data.cooldown = 192
				local e1 = Effect.spawn(npcID, v.x, v.y)
				local e2 = Effect.spawn(npcID, v.x + (v.width/2), v.y)
				local e3 = Effect.spawn(npcID, v.x, v.y + (v.height/2))
				local e4 = Effect.spawn(npcID, v.x + (v.width/2), v.y + (v.height/2))
				
				e1.speedX = -2
				e2.speedX = 2
				e3.speedX = -2
				e4.speedX = 2
				
				e1.speedY = -4
				e2.speedY = -4
				-- e3.speedY = 4
				-- e4.speedY = 4
			end
		end
	end
	
	if data.cooldown > 0 then
		data.cooldown = data.cooldown - 1
		v.animationFrame = 1
	else
		v.animationFrame = 0
		data.canRefill = true
	end
	
	if data.cooldown == 1 then
		SFX.play(refillSFX, 0.5)
		local e1 = Effect.spawn(78, v.x + (v.width/2), v.y + (v.height/2))
	end
end


return dashCrystal