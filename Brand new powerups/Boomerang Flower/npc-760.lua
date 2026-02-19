local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local boomerang = {}

local boomEffectID = 760

boomerang.collectibleItems = {10, 33, 88, 103, 138, 152, 251, 252, 253, 258, 274, 310, 378} --some imporant coins
boomerang.lifetime = 180	-- how many frames the boomerang stays alive after returning the last time
boomerang.returnTries = 3	-- how often the boomerang will try to return to the player
boomerang.maxFallSpeed = 3	-- how fast the boomerang can go when the player is below the boomerang
boomerang.maxSpeed = 8
--[[
	***************************************
	 Uses removeCC.lua, made by Novarender	-- removeCC lol
	***************************************
	]]
	

local npcID = NPC_ID

local boomerangSettings = {
	id = npcID,
	
	gfxheight = 32,
	gfxwidth = 32,
	
	width = 32,
	height = 32,
	
	gfxoffsetx = 0,
	gfxoffsety = 0,
	
	frames = 4,
	framestyle = 0,
	framespeed = 6,
	
	speed = 1,
	score = 0,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	
	nohurt=true,
	nogravity = true,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= true,
	nowaterphysics = true,
	
	jumphurt = false,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,
	useclearpipe = true,
	bubbleFlowerImmunity = true,
	
	--These will cause the boomerang to return while harming the NPC
	stopBoomerangNPCs = {39, 205, 564, 200, 262, 608, 201, 351, 256, 257, 15, 86, 267, 268, 37, 164, 642, 646, 437, 295, 432, 435, 180, 466, 467, 531, 532, 609, 641, 643, 645, 647, 648, 649},
	
	--Must have the table entries in the same place, these transform these guys
	nontransformedNPCIDs = {578, 173, 176, 175, 177, 4, 76, 6, 161, 23, 136, 165, 408, 194, 109, 121, 110, 122, 111, 123, 112, 124, 72, 579, 172, 172, 174, 174, 5, 5, 7, 7, 24, 137, 166, 409, 195, 113, 113, 114, 114, 115, 115, 116, 116, 73},
	transformedNPCIDs = {579, 172, 172, 174, 174, 5, 5, 7, 7, 24, 137, 166, 409, 195, 113, 113, 114, 114, 115, 115, 116, 116, 73, 579, 172, 172, 174, 174, 5, 5, 7, 7, 24, 137, 166, 409, 195, 113, 113, 114, 114, 115, 115, 116, 116, 73},
	
	--Don't hurt the npc, but make it get pushed back and return the boomerang
	pushBackIDs = {531, 532, 609, 641, 643, 645, 647},
	
	--Do nothing to this npc
	noHarmNPCs = {37, 38, 437, 295, 432, 435, 180, 43, 586, 42, 44, 531, 532, 609, 641, 643, 645, 647},
}

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		--HARM_TYPE_PROJECTILE_USED,
		--HARM_TYPE_LAVA,
		--HARM_TYPE_HELD,
		HARM_TYPE_TAIL,
		HARM_TYPE_SPINJUMP,
		HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		[HARM_TYPE_JUMP]=boomEffectID,
		--[HARM_TYPE_FROMBELOW]=10,
		--[HARM_TYPE_NPC]=10,
		--[HARM_TYPE_PROJECTILE_USED]=10,
		--[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_HELD]=10,
		[HARM_TYPE_TAIL]=boomEffectID,
		[HARM_TYPE_SPINJUMP]=boomEffectID,
		--[HARM_TYPE_OFFSCREEN]=10,
		--[HARM_TYPE_SWORD]=10,
	}
);

npcManager.setNpcSettings(boomerangSettings)

function boomerang.onInitAPI()
	npcManager.registerEvent(npcID, boomerang, "onTickNPC")
end


function boomerang.onTickNPC(v)
	if Defines.levelFreeze then return end

	local config = NPC.config[v.id]
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
		data.returnToSender = false
		data.returnTries = 1	-- how often the npc tries to return to the player
		data.slowdownSpeed = 0.1875
		data.lifetime = 0		-- counts up when it stops returning. If it reaches boomerang.lifetime, it will break
		data.slowDown = v.speedX
		data.initialDir = v.direction
		data.hitBox = Colliders.Box(v.x - 8, v.y - 8, 48 ,48)
	end
	
	data.hitBox.x = v.x - 8
	data.hitBox.y = v.y - 8
	
	for _,c in NPC.iterate(boomerang.collectibleItems) do
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

	if v.direction ~= data.initialDir then
		data.returnToSender = true
	end

	if not data.returnToSender then
		v.speedY = 0
	end

	-- slow down the boomerang and speed it up again when returning
	if (v.speedX >= -boomerang.maxSpeed and v.speedX <= boomerang.maxSpeed) or (data.initialDir == v.direction) then
		v.speedX = v.speedX - data.slowdownSpeed * data.initialDir
	end
	
	--If it hits blocks, turn around
	if v.collidesBlockLeft or v.collidesBlockRight or v.collidesBlockBottom then
		if not data.returnToSender then
			data.returnToSender = true
			data.slowDown = 0
		else
			v:kill(HARM_TYPE_TAIL)
		end
	end
	
	if lunatime.tick() % 4 == 0 and math.abs(v.speedX) > 3 then  
		local e = Effect.spawn(74,v)
		e.x = e.x + RNG.randomInt(-8,24)
		e.y = e.y + RNG.randomInt(-8,24)
		e.speedX = -v.speedX/4
	end

	--If returning and it hits the player, collect it
	if data.returnToSender and data.owner then
		if Colliders.collide(v, data.owner) then
			v:kill(HARM_TYPE_OFFSCREEN)
			SFX.play(73)
		end
		if v.y < data.owner.y then
			local bombyspeed = vector.v2(Player.getNearest(v.x + v.width/2, v.y + v.height).y + 0.5 * Player.getNearest(v.x + v.width/2, v.y + v.height).height - (v.y + 0.5 * v.height))
			v.speedY = math.min(bombyspeed.y / 20,boomerang.maxFallSpeed)
		else
			v.speedY = 0
		end
		
		if boomerang.returnTries > data.returnTries then	-- if it tries to return multiple times, do checks whether it passed the player
			if (v.x + v.width * 0.5 < data.owner.x + data.owner.width * 0.5 and v.direction < 0 and data.initialDir > 0) 
					or (v.x + v.width * 0.5 > data.owner.x + data.owner.width * 0.5 and v.direction > 0 and data.initialDir < 0) then	-- it passed the player 
				data.initialDir = - data.initialDir
				data.slowdownSpeed = data.slowdownSpeed * 1.2
				data.returnTries = data.returnTries + 1
			end
		else
			if data.lifetime >= boomerang.lifetime then
				-- despawn so the player can throw a new boomerang!
				v:kill(HARM_TYPE_OFFSCREEN)
				Effect.spawn(10,v,0,0,false)
			end
			data.lifetime = data.lifetime + 1
		end
	end
	
	data.cantHarm = false
	
	--If it touches an enemy, harm it
	for _,npc in ipairs(Colliders.getColliding{a = data.hitBox, atype = Colliders.NPC, b = NPC.HITTABLE}) do
	
		if not (npc.friendly and not npc.isHidden and not npc.isinteractable and not npc.iscoin) and npc:mem(0x138, FIELD_WORD) == 0 and npc.id ~= v.id  then
			for _,s in ipairs(NPC.config[v.id].stopBoomerangNPCs) do
				if npc.id == s then
					data.returnToSender = true
					data.slowDown = 0
					v.x = v.x + 8 * -v.direction
				end
			end
		
			--If a transformable npc, transform it instead
			for e,n in ipairs(NPC.config[v.id].nontransformedNPCIDs) do
				if npc.id == n then
					npc:transform(NPC.config[v.id].transformedNPCIDs[e])
					npc.speedY = -5
					npc.speedX = 0
					SFX.play(9)
					data.cantHarm = true
				end
			end

			--Push back certain npcs
			for _,pushback in ipairs(NPC.config[v.id].pushBackIDs) do
				if npc.id == pushback then npc.speedY = -5 npc.speedX = -npc.speedX end
			end
			
			--Harm the npc, unless it has the "noHarmNPCs" setting
			for _,noHarming in ipairs(NPC.config[v.id].noHarmNPCs) do
				if npc.id == noHarming then return end
			end
			
			if not data.cantHarm then
				--Special interaction for if a bully gets hit
				if npc.id == 648 or npc.id == 649 then
					npc:harm(HARM_TYPE_JUMP)
				else
					npc:harm(HARM_TYPE_NPC)
				end
			end
		end
	end
	
	local list = Colliders.getColliding{a = data.hitBox, btype = Colliders.BLOCK, filter = function(other)
		if other.isHidden or other:mem(0x5A, FIELD_BOOL) then
			return false
		end
		return true
	end}
	
	for _,b in ipairs(list) do
		if Block.config[b.id].passthrough then return end
		if Block.SOLID_MAP[b.id] and not b.isHidden and not b.layerObj.isHidden then
			b:hit()
			if Block.config[b.id].smashable ~= nil then
				if Block.config[b.id].smashable >= 3 and b.contentID == 0 then
					b:remove(true)
					data.returnToSender = true
					data.slowDown = 0
				end
			end
		end
	end
end

return boomerang