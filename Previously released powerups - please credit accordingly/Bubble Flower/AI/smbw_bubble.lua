local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local easing = require("ext/easing")
local starman = require("npcs/AI/starman")

local bubble = {}

bubble.idList = {}
bubble.idMap = {}

bubble.SFX = {
	npcKill = {id = 9, volume = 1},
	bubblePop = {id = 2, volume = 1},
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
	registerEvent(bubble, "onNPCKill")

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

function bubble.addSettings(id, settings)
	settings = settings or {}
	npcData[id] = {
		reward = settings.reward or 10,
		drawFunc = settings.drawFunc,
		customFunc = settings.customFunc,
	}
end

function bubble.defaultDrawFunc(v, data)
	local storedID = data.storedNPCID
	local reward = npcData[storedID].reward or 10
	local npcImg = Graphics.sprites.npc[storedID].img
	local rewardImg = Graphics.sprites.npc[reward].img

	if data.enemyLerp > 0.5 then
		local config = NPC.config[reward]
		local gfxwidth, gfxheight = config.gfxwidth, config.gfxheight

		if gfxwidth == 0 then gfxwidth = config.width end
		if gfxheight == 0 then gfxheight = config.height end

		Graphics.drawImageToSceneWP(
			rewardImg,
			v.x + v.width/2 - gfxwidth/2,
			v.y + v.height/2 - gfxheight/2,
			0, 0, gfxwidth, gfxheight, -46
		)
	else
		local config = NPC.config[storedID]
		local gfxwidth, gfxheight = config.gfxwidth, config.gfxheight

		if gfxwidth == 0 then gfxwidth = config.width end
		if gfxheight == 0 then gfxheight = config.height end

		Graphics.drawBox{
			texture = npcImg, x = v.x + v.width/2, y = v.y + v.height/2,
			centered = true, priority = -46, rotation = data.enemyRot,
			sourceWidth = gfxwidth, sourceHeight = gfxheight,
			width = gfxwidth * data.enemyScale,
			height = gfxheight * data.enemyScale,
			sceneCoords = true,
		}
	end
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
	end

	if v:mem(0x12C, FIELD_WORD) > 0 -- Grabbed
	or v:mem(0x136, FIELD_BOOL)     -- Thrown
	or v:mem(0x138, FIELD_WORD) > 0 -- Contained within
	then
		return
	end

	data.timer = data.timer + 1

	data.sizeLerp = math.min(data.sizeLerp + 0.05, 1)
	data.scale = easing.outQuad(data.sizeLerp, 0, 1, 1)

	if data.timer == config.lifetime then
		v:kill(9)
		SFXPlay("bubblePop")
		return

	elseif data.timer > config.lifetime/4 or data.storedNPCID > 0 then
		v.speedX = v.speedX * 0.98
		v.speedY = v.speedY * 0.98
	end

	local speedMod = 0

	if not data.targetNPC and data.storedNPCID == 0 then
		for k, n in NPC.iterateIntersecting(v.x - 16, v.y - 16, v.x + v.width + 16, v.y + v.height + 16) do
			if not n.isHidden and not n.isGenerator and not n.friendly and v.id ~= n.id
			and not blacklist[n.id] and (NPC.HITTABLE_MAP[n.id] or whitelist[n.id])
			then
				data.targetNPC = n
				data.target.x = n.x + n.width/2
				data.target.y = n.y + n.height/2
				data.storedPos.x = v.x + v.width/2
				data.storedPos.y = v.y + v.height/2
				npcData[n.id] = npcData[n.id] or {}
				n:mem(0x138, FIELD_WORD, 4)
				n.friendly = true
				v.speedX = 0
				v.speedY = 0
				SFXPlay("targetFixed")
				break
			end
		end
		
	elseif data.targetNPC and data.storedNPCID == 0 then
		data.targetLerp = math.min(data.targetLerp + 0.03, 1)

		local pos = easing.outQuad(data.targetLerp, data.storedPos, data.target - data.storedPos, 1)

		v.speedX = pos.x - v.width/2 - v.x
		v.speedY = pos.y - v.height/2 - v.y

		if data.targetLerp == 1 then
			data.storedNPCID = data.targetNPC.id
			data.targetNPC:kill(9)
			data.targetNPC = nil
			SFXPlay("npcKill")
		end

	elseif data.storedNPCID > 0 then
		speedMod = -0.25

		if data.enemyLerp > 0.5 and not data.poofSpawned then
			data.poofSpawned = true
			local e = Effect.spawn(10, v.x + v.width/2, v.y + v.height/2)
			e.x = e.x - e.width/2
			e.y = e.y - e.height/2
		else
			data.enemyLerp = math.min(data.enemyLerp + 0.02, 1)
			data.enemyScale = easing.outQuad(data.enemyLerp, 1, -1, 1)
			data.enemyRot = easing.outBack(data.enemyLerp, 0, 360, 1)
		end
	end

	if not data.targetNPC then
		v.y = v.y + math.sin(data.timer / 20) * 0.5 + speedMod
	end
end

function bubble.onDrawNPC(v)
	local data = v.data
	local config = NPC.config[v.id]

	if data.initialized then
		local flashing = data.timer > (config.lifetime - config.warningFrames) and (data.timer - config.lifetime) % config.flashSpeed > config.flashSpeed/2

		if not flashing and v.despawnTimer > 0 and not v.isHidden then
			if data.storedNPCID > 0 then
				local func = npcData[data.storedNPCID].drawFunc or bubble.defaultDrawFunc
				func(v, data)
			end

			Graphics.drawBox{
				texture = Graphics.sprites.npc[v.id].img,
				x = v.x + v.width/2, y = v.y + v.height/2,
				centered = true, priority = -45,
				sourceWidth = config.gfxwidth,
				sourceHeight = config.gfxheight,
				sourceY = config.gfxheight * v.animationFrame,
				width = config.gfxwidth * data.scale,
				height = config.gfxheight * data.scale,
				sceneCoords = true,
			}
		end
	end

	npcutils.hideNPC(v)
end

function bubble.onNPCKill(e, v, r)
	if e.cancelled or not bubble.idMap[v.id] then return end

	local data = v.data

	if data.targetNPC and data.storedNPCID == 0 then
		e.cancelled = true
	end
end

function bubble.onPostNPCKill(v, r)
	if not bubble.idMap[v.id] then return end
	if v.data.storedNPCID <= 0 then return end

	local cfg = npcData[v.data.storedNPCID]

	local n = NPC.spawn(
		cfg.reward or 10,
		v.x + v.width/2, v.y + v.height/2,
		v.section, false, true
	)

	if cfg.customFunc then
		cfg.customFunc(n)
	elseif NPC.config[n.id].iscoin then
		n.ai1 = 1
	end

	local e = Effect.spawn(10, v.x + v.width/2, v.y + v.height/2)
	e.x = e.x - e.width/2
	e.y = e.y - e.height/2
end

return bubble