local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local easing = require("ext/easing")
local starman = require("npcs/AI/starman")

local bubble = {}

bubble.idList = {}
bubble.idMap = {}

local STATE_EMPTY = 0
local STATE_FULL = 1

bubble.SFX = {
	npcKill = {id = 9, volume = 1},
	bubblePop = {id = 91, volume = 1},
	targetFixed = {id = 13, volume = 1},
}

local blacklist = {}
local whitelist = {}
local npcData = {}

local function SFXPlay(name)
	local sfx = bubble.SFX[name]
	
	if sfx then
		return SFX.play(sfx.id, sfx.volume or 1)
	end
end

function bubble.register(id)
	npcManager.registerEvent(id, bubble, "onTickEndNPC")
	npcManager.registerEvent(id, bubble, "onDrawNPC")

	registerEvent(bubble, "onPostNPCKill")

	table.insert(bubble.idList, id)
	bubble.idMap[id] = true

	starman.ignore[id] = true
end

function bubble.whitelist(id)
	whitelist[id] = true
	blacklist[id] = nil
end

function bubble.blacklist(id)
	whitelist[id] = nil
	blacklist[id] = true
end

function bubble.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	local config = NPC.config[v.id]

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.timer = 0
		data.timer2 = 0
		data.sizeLerp = 0
		data.scale = 0
		data.enemyLerp = 0
		data.enemyScale = 0
		data.enemyRot = 0
		data.storedNPCID = 0
		data.target = vector(0, 0)
		data.storedPos = vector(0, 0)
		data.poofSpawned = false
		data.targetNPC = nil
		data.targetLerp = 0
		data.y = 1
		data.state = STATE_EMPTY
	end

	if v:mem(0x12C, FIELD_WORD) > 0 -- Grabbed
	or v:mem(0x136, FIELD_BOOL)     -- Thrown
	or v:mem(0x138, FIELD_WORD) > 0 -- Contained within
	then
		return
	end

	data.timer = data.timer + 1

	data.y = math.clamp(data.y - 0.08, -2, 1)
	v.speedY = data.y
	
	local tbl = Block.SOLID .. Block.PLAYER
	collidingBlocks = Colliders.getColliding {
		a = v,
		b = tbl,
		btype = Colliders.BLOCK
	}

	if #collidingBlocks > 0 then --Not colliding with something
		if data.state == STATE_EMPTY then
			data.timer = config.lifetime
		else
			v:kill(9)
		end
	end
	
	if data.state == STATE_EMPTY then
		v.animationFrame = math.clamp(math.floor(0.25 * data.timer), 0, 2)
		v.friendly = true
		
		v.speedX = v.speedX * 0.98
		
		if data.timer == config.lifetime then
			v:kill(9)
			SFXPlay("bubblePop")
			Effect.spawn(75, v.x, v.y)
			return
		end
		
		for k, n in NPC.iterateIntersecting(v.x - 16, v.y - 16, v.x + v.width + 16, v.y + v.height + 16) do
			if not n.isHidden and not n.isGenerator and not n.friendly and v.id ~= n.id
			and not blacklist[n.id] and not NPC.POWERUP_MAP[n.id] and (NPC.HITTABLE_MAP[n.id] or whitelist[n.id]) and not NPC.config[n.id].bubbleFlowerImmunity
			then
				n:kill(9)
				data.state = STATE_FULL
				SFXPlay("targetFixed")
				for _,p in ipairs(Player.get()) do
					if p.data.bubbleFlowerSMW then p.data.bubbleFlowerSMW.canShoot = true end
				end
				break
			end
		end
		
	else
		v.speedX = v.speedX * 0.9
		v.animationFrame = 3
		v.friendly = false
		data.timer2 = data.timer2 + 1
		
		for _,p in ipairs(Player.get()) do
			if Colliders.collide(p, v) and data.timer2 >= 32 then
				v:kill(9)
			end
		end
	end
end

function bubble.onDrawNPC(v)
	local data = v.data
	if data.initialized then

		if v.despawnTimer > 0 and not v.isHidden then
			if data.state > 0 then
				local config = NPC.config[NPC.config[v.id].reward]
				local gfxwidth, gfxheight = config.gfxwidth, config.gfxheight

				if gfxwidth == 0 then gfxwidth = config.width end
				if gfxheight == 0 then gfxheight = config.height end

				Graphics.drawImageToSceneWP(
					Graphics.sprites.npc[NPC.config[v.id].reward].img,
					v.x + v.width/2 - gfxwidth/2,
					v.y + v.height/2 - gfxheight/1.5,
					0, (math.floor(lunatime.tick() / config.framespeed) % NPC.config[v.id].rewardFrames + NPC.config[v.id].rewardFramesOffset) * gfxheight, gfxwidth, gfxheight, -46
				)
			end
		end
	end
end

function bubble.onPostNPCKill(v, r)
	if not bubble.idMap[v.id] then return end
	
	for _,p in ipairs(Player.get()) do
		if p.data.bubbleFlowerSMW then p.data.bubbleFlowerSMW.canShoot = true end
	end
	
	if v.data.state <= 0 then return end

	SFXPlay("bubblePop")
	Effect.spawn(144, v.x + v.width * 0.5, v.y + v.height * 0.5)

	local n = NPC.spawn(
		NPC.config[v.id].reward or 10,
		v.x + v.width/2, v.y + v.height/2,
		v.section, false, true
	)

	if NPC.config[n.id].iscoin then
		n.ai1 = 1
	end

	local e = Effect.spawn(10, v.x + v.width/2, v.y + v.height/2)
	e.x = e.x - e.width/2
	e.y = e.y - e.height/2
end

return bubble