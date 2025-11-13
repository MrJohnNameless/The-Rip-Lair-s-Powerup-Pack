local npcManager = require("npcManager")
local sampleNPC = {}
local npcID = NPC_ID

local sampleNPCSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 4,
	framestyle = 0,
	framespeed = 4,
	speed = 1,
	score = SCORE_1000,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
	nohurt = true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi = true,
	nowaterphysics = false,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	ignorethrownnpcs = true,
	notcointransformable = true,
	bubbleFlowerImmunity = true,
	
	durability = 3,
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

--Register events
function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	registerEvent(sampleNPC, "onNPCKill")
end

local heights = {-4, -5, -5.5, -3}

function sampleNPC.onNPCKill(e, v, r)
	if v.id ~= npcID then return end
	for i = 1, 15 do
		Effect.spawn(77, RNG.randomInt(v.x, v.x + v.width), RNG.randomInt(v.y, v.y + v.height), v.ai1 + 1)
	end
	SFX.play(3)
end

function sampleNPC.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
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
		data.subtract = 0
		data.hit = 0
		data.collider = Colliders.Box(v.x, v.y, v.width * 1.5, v.height * 1.5)
	end
	
	data.collider.x = v.x - v.width * 0.25
	data.collider.y = v.y - v.height * 0.25

	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		-- Handling of those special states. Most NPCs want to not execute their main code when held/coming out of a block/etc.
		-- If that applies to your NPC, simply return here.
		-- return
	end
	
	v.animationFrame = math.floor((lunatime.tick() * -math.sign(v.speedX)) / sampleNPCSettings.framespeed) % sampleNPCSettings.frames + (sampleNPCSettings.frames * v.ai1)
	
	--Spawn a trail
	if lunatime.tick() % 2 == 0 then
		Effect.spawn(77, RNG.randomInt(v.x, v.x + v.width), RNG.randomInt(v.y, v.y + v.height), v.ai1 + 1)
	end
	
	data.subtract = data.subtract + 0.025
	
	--Movement properties
	if v.ai1 == 0 or v.ai1 == 4 then
		v.speedX = (5 + v.ai2) * v.direction
	elseif v.ai1 == 1 then
		v.speedX = (4.25 + v.ai2) * v.direction
	elseif v.ai1 == 2 then
		v.speedX = math.clamp((5 + v.ai2) - data.subtract, 3 + v.ai2, 5 + v.ai2) * v.direction
	elseif v.ai1 == 3 then
		v.speedX = math.clamp((5 + v.ai2) + data.subtract, 5 + v.ai2, 8 + v.ai2) * v.direction
	end
	
	if v.ai1 == 4 then v.speedY = -Defines.npc_grav
	else
		if v.collidesBlockBottom then
			v.speedY = heights[v.ai1 + 1]
		end
	end
	
	--Harm NPCs
	for k,npc in ipairs(Colliders.getColliding{a = data.collider, atype = Colliders.NPC, b = NPC.HITTABLE}) do
		if not (NPC.config[npc.id].nofireball and not npc.friendly and not npc.isHidden and not npc.isinteractable and not npc.iscoin) and npc:mem(0x138, FIELD_WORD) == 0 then
			npc:harm(HARM_TYPE_EXT_FIRE)
			data.hit = data.hit + 1
			if data.hit >= sampleNPCSettings.durability then v:kill(9) end
		else
			npc:harm(HARM_TYPE_NPC)
			v:kill(9)
		end
	end
	
	if v.ai1 ~= 2 then
		if v.collidesBlockLeft or v.collidesBlockRight then
			v:kill(9)
		end
	end
	
end

return sampleNPC