local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local clearpipeNPC = require("npcs/AI/clearpipeNPC")

local goldBall = {}

goldBall.idList = {}
goldBall.idMap = {}

goldBall.explosionRadius = 64
goldBall.explosionTexture = Graphics.loadImageResolved("powerups/goldFlower-explosion.png")
goldBall.explosionLife = 16
goldBall.explosionSound = "AI/goldFireBall-explode.ogg"
goldBall.explosionPriority = -45

goldBall.explosionColors = {
	[CHARACTER_MARIO] = Color.fromHexRGB(0xFFBD16),
	[CHARACTER_LUIGI] = Color.fromHexRGB(0xBECCE5),
	[CHARACTER_PEACH] = Color.fromHexRGB(0xFFD7C1),
	[CHARACTER_TOAD]  = Color.fromHexRGB(0xFFBD16),
	[CHARACTER_LINK]  = Color.fromHexRGB(0x99CC66),
}


local npcBlacklist = {}
local blockBlacklist = {}
local blockWhitelist = {}

local blockCoinsMap = {}
local explosionEffects = {}


local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

respawnRooms = respawnRooms or {}


local function handleAnimation(v, data, config)
	if data.timer % 2 == 0 then
		local e = Effect.spawn(config.trailEffect, v.x + v.width/2, v.y + v.height/2, data.character + 1)
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
	end

	if RNG.randomInt(1, 15) <= 2 then
		local e = Effect.spawn(config.sparkleEffect, v.x + RNG.randomInt(0, v.width), v.y + RNG.randomInt(0, v.height), data.character)
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
	end

	data.timer = data.timer + 1
	data.frame = math.floor(data.timer / config.framespeed) % config.frames

	v.animationTimer = -999
	v.animationFrame = npcutils.getFrameByFramestyle(v, {frame = data.frame + config.frames * (data.character - 1), frames = config.frames * config.variants})
end


-----------------------
-- Exposed Functions --
-----------------------

function goldBall.register(id)
	npcManager.registerEvent(id, goldBall, "onTickEndNPC")

	table.insert(goldBall.idList, id)
	goldBall.idMap[id] = true

	clearpipeNPC.onTickFunctions[id] = function(v)
		handleAnimation(v, v.data, NPC.config[id])
	end

	clearpipeNPC.onDrawFunctions[id] = function(v)
		local data = v.data
		local config = NPC.config[id]

		v.data._basegame.animationFrame = npcutils.getFrameByFramestyle(v, {frame = data.frame + config.frames * (data.character - 1), frames = config.frames * config.variants})
	end
end

function goldBall.blacklistNPC(id)
	npcBlacklist[id] = true
end

function goldBall.whitelistBlock(id)
	blockWhitelist[id] = true
	blockBlacklist[id] = nil
end

function goldBall.blacklistBlock(id)
	blockWhitelist[id] = nil
	blockBlacklist[id] = true
end

function goldBall.addBlockTransformation(blockID, coinID)
    blockCoinsMap[blockID] = coinID
end

function goldBall.spawnExplosion(v)
	local data = v.data
	local collider = Colliders.Circle(v.x + v.width/2, v.y + v.height/2, goldBall.explosionRadius)

	SFX.play(goldBall.explosionSound)

	table.insert(
		explosionEffects,
		{
			x = collider.x,
			y = collider.y,
			character = data.character,
			timer = 0,
			opacityMod = 1,
			canRemove = false,
		}
	)

	for i = 1, 10 do
		local e =  Effect.spawn(NPC.config[v.id].sparkleEffect, v.x - 8 + RNG.random(v.width + 8), v.y - 4 + RNG.random(v.height + 8), data.character)
		e.speedX = RNG.random(6) - 3
		e.speedY = RNG.random(6) - 3
	end

	-- hit NPCs
	for k, v in ipairs(Colliders.getColliding{a = collider, b = NPC.HITTABLE, btype = Colliders.NPC}) do
		if not npcBlacklist[v.id] then
			v:harm()
		end
	end

	-- hit blocks
	for k, v in ipairs(Colliders.getColliding{a = collider, b = Block.SOLID, btype = Colliders.BLOCK}) do
		if not blockBlacklist[v.id] then
			if v.contentID == 0 and (Block.MEGA_SMASH_MAP[v.id] or blockWhitelist[v.id]) then
				v:remove(true)

				local coin = NPC.spawn(blockCoinsMap[v.id] or 10, v.x + v.width/2, v.y + v.height/2, nil, false, true)

			elseif v.contentID ~= 0 then
				v:hit()
			end
		end
	end
end


-------------------
-- NPC Functions --
-------------------

function goldBall.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	local config = NPC.config[v.id]

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.frame = 0
		data.timer = 0
		data.explode = false
		data.wasHeld = false

		if v.collisionGroup == "" then
			v.collisionGroup = config.collisionGroup
		end

		if not data.character then
			data.character = CHARACTER_MARIO
		end

		if not data.player then
			data.player = player
		end
	end

	if v.heldIndex > 0 and v.forcedState == 0 then
		data.wasHeld = true
	end

	if data.character == CHARACTER_LINK then
		v.speedY = -Defines.npc_grav
	end

	handleAnimation(v, data, config)
	
	if v.heldIndex ~= 0 -- Grabbed
	or v.forcedState > 0 -- Contained within
	then
		return
	end

	if data.wasHeld then
		local p = data.player

		if (p.character == CHARACTER_PEACH or p.character == CHARACTER_TOAD) and p.keys.down then
			v.x = p.x + p.width/2 - v.width/2
			v.speedY = 8
		end

		data.wasHeld = false
	end

	if v.collidesBlockBottom then
		if v.speedX == 0 or v.data.character == CHARACTER_LINK then
			data.explode = true
			v:kill(HARM_TYPE_OFFSCREEN)
			return
		else
			v.speedY = -5
		end
	end

	if v.collidesBlockLeft or v.collidesBlockRight or v.collidesBlockUp then
		data.explode = true
		v:kill(HARM_TYPE_OFFSCREEN)
		return
	end

	-- check for npcs
	for k, n in ipairs(Colliders.getColliding{a = v, b = NPC.HITTABLE, btype = Colliders.NPC}) do
		if not npcBlacklist[n.id] and n.id ~= v.id then
			data.explode = true
			v:kill(HARM_TYPE_OFFSCREEN)
			return
		end
	end

	-- check for blocks
	-- we can't use collidesBlockBottom because that's used to set the npc's speed
	local oldWidth = v.width
	local oldHeight = v.height
	local oldX = v.x + v.width/2
	local oldY = v.y + v.height/2

	v.width = v.width + 2
	v.height = v.height + 2
	v.x = oldX - v.width/2
	v.y = oldY - v.height/2

	for k, b in ipairs(Colliders.getColliding{a = v, b = Block.SOLID, btype = Colliders.BLOCK}) do
		if not blockBlacklist[b.id] and (Block.MEGA_SMASH_MAP[b.id] or b.contentID > 0 or blockWhitelist[b.id]) then
			data.explode = true
			v:kill(HARM_TYPE_OFFSCREEN)
			return
		end
	end

	v.width = oldWidth
	v.height = oldHeight
	v.x = oldX - v.width/2
	v.y = oldY - v.height/2

	v:mem(0x120, FIELD_BOOL, false)
end


-----------------------
-- Handle Explosions --
-----------------------

function goldBall.onInitAPI()
	registerEvent(goldBall, "onStart")
    registerEvent(goldBall, "onTick")
    registerEvent(goldBall, "onDraw")
	registerEvent(goldBall, "onPostNPCKill")
end

function goldBall.onTick()
	for k = #explosionEffects, 1, -1 do
		local v = explosionEffects[k]

		if not v.canRemove then
			v.timer = v.timer + 1
		else
			v.opacityMod = math.max(v.opacityMod - 0.1, 0)
		end

		if v.timer >= goldBall.explosionLife then
			v.canRemove = true
		end

		if v.opacityMod == 0 then
			table.remove(explosionEffects, k)
		end
	end
end

function goldBall.onDraw()
	for k, v in ipairs(explosionEffects) do
		local progress = v.timer/goldBall.explosionLife

		local img = goldBall.explosionTexture
		local newProgress = math.min(progress, 0.5) + 0.5

		Graphics.drawBox{
			texture = img,
			x = v.x,
			y = v.y,
			width = newProgress * img.width,
			height = newProgress * img.height,
			radius = (progress + 0.5) * goldBall.explosionRadius,
			color = (goldBall.explosionColors[v.character] or Color.white) .. newProgress * v.opacityMod,
			priority = goldBall.explosionPriority,
			sceneCoords = true,
			centered = true,
		}
    end
end

function goldBall.onPostNPCKill(v, r)
	if goldBall.idMap[v.id] and (v.data.explode or r == HARM_TYPE_PROJECTILE_USED) then
		goldBall.spawnExplosion(v)
	end
end

function respawnRooms.onPreReset(fromRespawn)
	explosionEffects = {}
end

return goldBall