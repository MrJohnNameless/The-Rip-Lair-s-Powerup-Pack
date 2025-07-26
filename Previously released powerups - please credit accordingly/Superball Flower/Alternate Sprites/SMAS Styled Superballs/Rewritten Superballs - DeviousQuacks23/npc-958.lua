local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local afterimages
pcall(function() afterimages = require("afterimages") end)

local ball = {}
ball.collectibleItems = {10, 33, 88, 103, 138, 152, 251, 252, 253, 258, 274, 310, 378} -- Stuff to collect

local npcID = NPC_ID

local ballSettings = {
	id = npcID,
	
	gfxheight = 20,
	gfxwidth = 20,
	
	width = 20,
	height = 20,
	
	gfxoffsetx = 0,
	gfxoffsety = 0,
	
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	
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
	nowaterphysics = true,
	
	jumphurt = false,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	SMLDamageSystem = true,

	ballSpeed = 6,
	lifetime = 280,

	afterimageTrails = true,
	afterimageColour = Color.fromHexRGB(0x282828),
}

npcManager.setNpcSettings(ballSettings)
npcManager.registerHarmTypes(npcID,{HARM_TYPE_OFFSCREEN},{})

function ball.onInitAPI()
	npcManager.registerEvent(npcID, ball, "onTickNPC")
end

local function spuff(v)
        local e = Effect.spawn(10, v.x + v.width * 0.5,v.y + v.height * 0.5)
        e.x = e.x - e.width * 0.5
        e.y = e.y - e.height * 0.5

	v:kill(HARM_TYPE_OFFSCREEN)
end

function ball.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local config = NPC.config[v.id]
	local data = v.data

	if v.despawnTimer <= 0 then
		data.init = false
		return
	end

	if not data.init then
		data.verticalDir = (v.speedY < 0 and 0) or 1
		data.lifetime = 0

		data.init = true
	end
	
	if v.heldIndex ~= 0  or v.forcedState > 0 then return end
        if v.isProjectile then v.isProjectile = false end

	-- Reboundin' logic

	v.speedX = config.ballSpeed * v.direction
	v.speedY = (data.verticalDir == 0 and -config.ballSpeed) or config.ballSpeed

	if v.collidesBlockUp and data.verticalDir == 0 then data.verticalDir = 1 end
	if v.collidesBlockBottom and data.verticalDir == 1 then data.verticalDir = 0 end

	if v.collidesBlockBottom or v.collidesBlockRight or v.collidesBlockUp or v.collidesBlockLeft then SFX.play(3, 0.5) end

	v.friendly = true

	-- Collect coins

	for _,c in NPC.iterate(ball.collectibleItems) do
		local collecter = data.owner or player
		if v:collide(c) then
			if not NPC.config[c.id].iscoin and not NPC.config[c.id].isinteractable then
				c.x = collecter.x
				c.y = collecter.y
			else
				c:collect(collecter)
			end
		end
	end

	-- Kill stuff

	for k,npc in ipairs(Colliders.getColliding{a = v, atype = Colliders.NPC, b = NPC.HITTABLE}) do
		if not (NPC.config[npc.id].nofireball and not npc.friendly and not npc.isHidden and not npc.isinteractable and not npc.iscoin) and npc:mem(0x138, FIELD_WORD) == 0 then
			npc:harm(HARM_TYPE_EXT_FIRE)
			spuff(v)
		else
			spuff(v)
		end
	end

	-- Expire after a while
	
	data.lifetime = data.lifetime + 1

	if data.lifetime and data.lifetime >= config.lifetime then
		spuff(v)
	end

	-- Fancy trails

	if afterimages and config.afterimageTrails then 
		afterimages.create(v, 24, config.afterimageColour, true, -49) 
	end
end

return ball