local npcManager = require("npcManager")
local sampleNPC = {}
local npcID = NPC_ID

local sampleNPCSettings = {
	id = npcID,

	gfxheight = 32,
	gfxwidth = 32,

	width = 32,
	height = 32,

	frames = 1,
	framestyle = 1,
	framespeed = 8,
	speed = 0,
	
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
}

npcManager.setNpcSettings(sampleNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		HARM_TYPE_OFFSCREEN,
		HARM_TYPE_PROJECTILE_USED,
	}, 
	{
		[HARM_TYPE_LAVA] = {id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_OFFSCREEN] = nil,
		[HARM_TYPE_PROJECTILE_USED] = 10,
	}
);

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
		data.lastX = v.x - 2
		data.initialized = true
		data.timer = 0
	end

	if v.heldIndex ~= 0  -- Negative when held by NPCs, positive when held by players
	or v.forcedState > 0 -- Various forced states
	then
		return
	end

	if data.moveStartTime then
		data.timer = data.timer + 1
	end

	if data.timer == data.moveStartTime then
		data.inMotion = true
		v.isProjectile = true
		v.speedX = 4 * v.direction

		local e = Effect.spawn(75, v.x + v.width/2, v.y + v.height/2)
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2

		SFX.play(9)
	end

	if not data.inMotion then
		return
	end

	if data.lastX == v.x and not v.collidesBlockBottom then
		v.isProjectile = true
		v.speedX = 4 * v.direction
	end
	data.lastX = v.x

	if v.collidesBlockBottom then
		v.speedY = -6
	elseif v.collidesBlockTop then
		v.speedY = 6
	end

	if v.collidesBlockLeft or v.collidesBlockRight then
		local e = Effect.spawn(75, v.x + v.width/2, v.y + v.height/2)
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2

		v:kill()
		return
	end

	for k, n in ipairs(Colliders.getColliding{a = v, b = NPC.HITTABLE, btype = Colliders.NPC}) do
		if n.id ~= v.id then
			n:harm(HARM_TYPE_NPC)
			v:kill()
			return
		end
	end
end

return sampleNPC