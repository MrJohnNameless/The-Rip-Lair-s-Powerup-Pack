local npcManager = require("npcManager")
local sampleNPC = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local propeller = cp.addPowerup("Propeller Suit", "powerups/propeller", npcID)
cp.transformWhenSmall(npcID, 9)

local sampleNPCSettings = {
	id = npcID,
	gfxheight = 40,
	gfxwidth = 32,
	width = 32,
	height = 32,
	frames = 4,
	framestyle = 0,
	framespeed = 6,
	speed = 1,
	score = SCORE_1000,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
	powerup = true,
	nohurt = true,
	nogravity = true,
	noblockcollision = true,
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
}

npcManager.setNpcSettings(sampleNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA] = {id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_OFFSCREEN] = nil,
	}
);

local STATE = {
    NONE = 0,
	FROMBLOCK = 1,
    RISING = 2,
    FALLING = 3,
}

function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
end

function sampleNPC.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.timer = 0
		data.state = STATE.NONE
		data.blockDir = 0

		if not v.dontMove then
			v.speedX = v.direction
		else
			v.speedX = 0
		end
	end

	if not data.originY and v.forcedState == 0 then
		data.originY = v.y
	end

	if data.blockDir == 0 and (v.forcedState == 1 or v.forcedState == 3) then
		data.state = STATE.FROMBLOCK
		data.blockDir = (v.forcedState == 1 and -1) or 1

		if v.forcedState == 3 then
			v.y = v.y + v.height
		end

		v.direction = -player.direction
		v.speedY = data.blockDir * 4
		v.forcedState = 0
		v.speedX = v.direction
	end

	if v.heldIndex ~= 0  -- Negative when held by NPCs, positive when held by players
	or v.isProjectile    -- Thrown
	or v.forcedState > 0 -- Various forced states
	then
		data.originY = v.y
		return
	end

	if data.state == STATE.FROMBLOCK then
		v.speedY = math.min(v.speedY + 0.1, 0)

		if v.speedY == 0 then
			data.state = STATE.FALLING
		end

	elseif data.state == STATE.FALLING then
		v.speedY = math.min(v.speedY + 0.1, 3)

		if v.speedY == 3 then
			data.state = STATE.RISING
		end

	elseif data.state == STATE.RISING then
		v.speedY = math.max(v.speedY - 0.1, 0)

		if v.speedY == 0 then
			data.state = STATE.NONE
			data.originY = v.y
		end
	end

	if data.state ~= STATE.NONE then
		return
	end

	data.timer = data.timer + 1

	if not v.dontMove and data.timer >= 512 then
		v.speedY = math.max(v.speedY - 0.25, -8)
		return
	end

	if data.originY then
		v.speedY = data.originY + math.sin(data.timer * 0.075) * 8 - v.y
	end
end

return sampleNPC