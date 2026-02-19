
--[[
	thwompMushroom.lua by Deltomx3

	OURGH.
	
	CREDITS:
	Marioman2007 - created customPowerups framework which this script uses as a base (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - I used his Cloud Flower script as a base : )
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
	2ND NOTE: Not for people who are easily scared of amateur code that was put together through pure trial & error.
]]--

local thwompMushroom = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

------ SETTINGS ------

thwompMushroom.settings = {
	directionControl = true, -- if the player can use the ability in any direction by using the respective direction keys (true by default)
	canInfinitelySlam = false, -- if the player can use the ability multiple times at once mid-air (false by default)
}
----------------------
thwompMushroom.cheats = {"needathwompmushroom","ourgh"}

function thwompMushroom.onInitPowerupLib()
	thwompMushroom.spritesheets = {
		thwompMushroom:registerAsset(1, "mario-thwompMushroom.png"),
		thwompMushroom:registerAsset(2, "luigi-thwompMushroom.png"),
		thwompMushroom:registerAsset(3, "peach-thwompMushroom.png"), -- "ask sleepy for peach sprites, not me"	 -MrNameless
		thwompMushroom:registerAsset(4, "toad-thwompMushroom.png"),
		thwompMushroom:registerAsset(5, "link-thwompMushroom.png"),
	}

	thwompMushroom.iniFiles = {
		thwompMushroom:registerAsset(1, "mario-thwompMushroom.ini"),
		thwompMushroom:registerAsset(2, "luigi-thwompMushroom.ini"),
		thwompMushroom:registerAsset(3, "peach-thwompMushroom.ini"),
		thwompMushroom:registerAsset(4, "toad-thwompMushroom.ini"),
		thwompMushroom:registerAsset(5, "link-thwompMushroom.ini"),
	}

	thwompMushroom.gpImages = {
        thwompMushroom:registerAsset(CHARACTER_MARIO, "thwompMushroom-groundPound-1.png"),
        thwompMushroom:registerAsset(CHARACTER_LUIGI, "thwompMushroom-groundPound-2.png"),
    }
end

thwompMushroom.basePowerup = 3
thwompMushroom.items = {}
thwompMushroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

local validForcedStates = table.map{0,754,755}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p.standingNPC -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function getPlayerSide(p)
	local side
	if p.data.thwompMushroom.lastDirection == DIR_RIGHT then
		side = p.x -- sets the coord on the left edge of the player's hurtbox
	elseif p.data.thwompMushroom.lastDirection == DIR_LEFT then 
		side = p.x + p.width -- sets the coord on the right edge of the player's hurtbox
	end

	return side
end

function thwompMushroom.onInitAPI()
	registerEvent(thwompMushroom, "onNPCHarm")
	registerEvent(thwompMushroom, "onNPCTransform")
end

-- runs once when the powerup gets activated, passes the player
function thwompMushroom.onEnable(p)
	p:mem(0x160,FIELD_WORD, 5)
	p.data.thwompMushroom = {
		animTimer = 0,
		lastDirection = p.direction,
		slamming = false,
		slammed = false,
		returning = false,
		returningFromUp = false,
		returningFromSide = false,
		alreadySlammed = false,
		timer = 0,
		playerLastY = 0,
		playerLastX = 0,
		combo = 2,
		slamDir = 1,
	}
end

-- Disables horizontal speedcap, call each onTick, after you set any speed you want
function ultimateSlip(p)
    p:mem(0x138, FIELD_FLOAT, player.speedX)
    p.speedX = 0
end

-- runs once when the powerup gets deactivated, passes the player
function thwompMushroom.onDisable(p)
	if not p.data.thwompMushroom then return end
	p.speedX = p.speedX / 2
	p.data.thwompMushroom = nil
end

local function sideSlam(p)
	local data = p.data.thwompMushroom
	data.slamming = false
	data.slammed = true
	if not thwompMushroom.settings.canInfinitelySlam then
		data.alreadySlammed = true
	end
	SFX.play(37)
	if p.direction == -1 then
		local e1 = Effect.spawn(10, p.x - 16, p.y - 16)
		local e2 = Effect.spawn(10, p.x - 16, p.y + p.height - 16)
		e1.speedY = -1
		e2.speedY = 1
	elseif p.direction == 1 then
		local e1 = Effect.spawn(10, p.x + p.width - 8, p.y - 16)
		local e2 = Effect.spawn(10, p.x + p.width - 8, p.y + p.height - 16)
		e1.speedY = -1
		e2.speedY = 1
	end
	data.timer = 0
	Defines.earthquake = math.max(Defines.earthquake, 4)
end

local function upSlam(p)
	local data = p.data.thwompMushroom
	data.slamming = false
	data.slammed = true
	if not thwompMushroom.settings.canInfinitelySlam then
		data.alreadySlammed = true
	end
	SFX.play(37)
	local e1 = Effect.spawn(10, p.x - 4 - 16, p.y - 16)
	local e2 = Effect.spawn(10, p.x - 4 + 16, p.y - 16)
	e1.speedX = -1
	e2.speedX = 1
	data.timer = 0
	Defines.earthquake = math.max(Defines.earthquake, 4)
end

local function enemyHurt(p, x1, y1, x2, y2)
	local data = p.data.thwompMushroom
	
	for _, npc in ipairs(NPC.getIntersecting(x1, y1, x2, y2)) do
		if NPC.HITTABLE_MAP[npc.id] and (not NPC.config[npc.id].jumphurt) and (not npc.friendly) and npc.despawnTimer > 0 and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 then
			local oldScore = NPC.config[npc.id].score
			NPC.config[npc.id].score = data.combo
			npc:harm(3,3)
			NPC.config[npc.id].score = oldScore
			data.combo = math.min(data.combo + 1, 10)
		end
	end
end

-- runs when the powerup is active, passes the player
function thwompMushroom.onTickPowerup(p)
	if not p.data.thwompMushroom then return end
	
	-- disables shooting the projectile of the respective basegame powerup used
    if linkChars[p.character] then
		p:mem(0x162, FIELD_WORD, 2)
	else
		p:mem(0x160, FIELD_WORD, 2) 
	end
	
	if p.deathTimer ~= 0 or p.forcedState ~= 0 or p.mount ~= 0 or p:mem(0x0C, FIELD_BOOL) then p.data.thwompMushroom.animTimer = 0 return end
	
	local data = p.data.thwompMushroom	
	
	if isOnGround(p) then
		data.combo = 2
		data.alreadySlammed = false
	end
	
	if not isOnGround(p) then
		if not data.slamming and not data.slammed and not data.returning and not data.alreadySlammed and p.keys.altRun == KEYS_PRESSED then
			if linkChars[p.character] then
				p:mem(0x160, FIELD_WORD, 2)
			end
			data.slamming = true
			p:mem(0x11C, FIELD_WORD, 0)
			p.speedY = -1
			data.playerLastY = p.y
			data.playerLastX = p.x
			Effect.spawn(10, p.x - 4, p.y + 8)
			data.timer = 0
			SFX.play(35)
			if thwompMushroom.settings.directionControl then
				if p.keys.left == KEYS_DOWN then
					data.slamDir = 1
				elseif p.keys.down == KEYS_DOWN then
					data.slamDir = 2
				elseif p.keys.up == KEYS_DOWN then
					data.slamDir = 3
				elseif p.keys.right == KEYS_DOWN then
					data.slamDir = 4
				else
					data.slamDir = 2
				end
			else
				data.slamDir = 2
			end
		end
	end
	
	if data.slamming then
		if data.slamDir == 1 then
			p.speedX = math.max(p.speedX - 0.4,-12)
			p.speedY = -Defines.player_grav + 0.001
			p.direction = -1
			p.keys.left = false
			p.keys.right = false
			ultimateSlip(p)
		elseif data.slamDir == 2 then
			p.speedX = 0
			p.speedY = p.speedY + 0.2
		elseif data.slamDir == 3 then
			p.speedX = 0
			p.speedY = p.speedY - (Defines.player_grav * 2) - 0.2
			if p.speedY < -Defines.gravity then
				p.speedY = -Defines.gravity
			end
		elseif data.slamDir == 4 then
			p.speedX = math.min(p.speedX + 0.4,12)
			p.speedY = -Defines.player_grav + 0.001
			p.direction = 1
			p.keys.left = false
			p.keys.right = false
			ultimateSlip(p)
		end
		p.keys.down = false
		
		data.timer = data.timer + 1
		
		if data.timer >= 5 and p.keys.altRun == KEYS_PRESSED then
			data.slamming = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			p.speedY = p.speedY / 1.5
			SFX.play(35)
			if not thwompMushroom.settings.canInfinitelySlam then
				data.alreadySlammed = true
			end
		end
		
		-- To prevent the player from skipping levels
		if data.timer >= 128 then
			data.slamming = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			p.speedX = p.speedX / 2.5
			p.speedY = p.speedY / 1.5
			SFX.play(35)
			if not thwompMushroom.settings.canInfinitelySlam then
				data.alreadySlammed = true
			end
		end
		
		if isOnGround(p) then
			data.slamming = false
			data.slammed = true
			SFX.play(37)
			local e1 = Effect.spawn(10, p.x - 4 - 16, p.y + p.height - 8)
			local e2 = Effect.spawn(10, p.x - 4 + 16, p.y + p.height - 8)
			e1.speedX = -1
			e2.speedX = 1
			data.timer = 0
			Defines.earthquake = math.max(Defines.earthquake, 4)
		end
		
		if data.slamDir == 1 or data.slamDir == 4 then
			for _,block in ipairs(Block.getIntersecting(p.x + (14 * p.direction), p.y, p.x + p.width + (14 * p.direction), p.y + p.height)) do
				-- If block is visible
				if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 then
					-- If the block should be broken, destroy it
					if Block.MEGA_SMASH_MAP[block.id] then
						if block.contentID > 0 then
							if Block.SOLID_MAP[block.id] and not block.isHidden and not block.layerObj.isHidden then
								block:hit(false, p)
							end
							sideSlam(p)
						else
							block:remove(true)
						end
					elseif Block.MEGA_HIT_MAP[block.id] then
						block:hit(true, p)
						sideSlam(p)
					elseif Block.MEGA_STURDY_MAP[block.id] then
						if block.contentID > 0 then
							block:hit(true, p)
							sideSlam(p)
						else
							sideSlam(p)
						end
					elseif Block.SOLID_MAP[block.id] then
						sideSlam(p)
					end
					
					if Block.LAVA_MAP[block.id] then
						p:kill()
					end
				end
			end
		end
		
		if data.slamDir == 3 then
			for _,block in ipairs(Block.getIntersecting(p.x, p.y - 12, p.x + p.width, p.y + p.height)) do
				-- If block is visible
				if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 then
					-- If the block should be broken, destroy it
					if Block.MEGA_SMASH_MAP[block.id] then
						if block.contentID > 0 then
							if Block.SOLID_MAP[block.id] and not block.isHidden and not block.layerObj.isHidden then
								block:hit(false, p)
							end
							upSlam(p)
						else
							block:remove(true)
						end
					elseif Block.MEGA_HIT_MAP[block.id] then
						block:hit(true, p)
						upSlam(p)
					elseif Block.MEGA_STURDY_MAP[block.id] then
						if block.contentID > 0 then
							block:hit(true, p)
							upSlam(p)				
						else
							upSlam(p)
						end
					elseif Block.SOLID_MAP[block.id] then
						upSlam(p)
					end
					
					if Block.LAVA_MAP[block.id] then
						p:kill()
					end
				end
			end
		end
		
		if data.slamDir == 2 then
			for _,block in ipairs(Block.getIntersecting(p.x, p.y + p.height, p.x + p.width, p.y + p.height + 12)) do
				-- If block is visible
				if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 then
					-- If the block should be broken, destroy it
					if Block.MEGA_SMASH_MAP[block.id] then
						if block.contentID > 0 then
							if block.contentID >= 1000 then
								block:hit(true, p)
							else
								block:hit(false, p)
							end
						else
							block:remove(true)
						end
					elseif Block.MEGA_HIT_MAP[block.id] then
						block:hit(true, p)
					elseif Block.MEGA_STURDY_MAP[block.id] then
						if block.contentID > 0 then
							block:hit(true, p)
						end
					end
					
					if Block.LAVA_MAP[block.id] then
						p:kill()
					end
				end
			end
		end
		
		if data.slamDir == 1 or data.slamDir == 4 then
			enemyHurt(p, p.x + (16 * p.direction) + p.speedX, p.y, p.x + p.width + (16 * p.direction) + p.speedX, p.y + p.height)
		elseif data.slamDir == 2 then
			enemyHurt(p, p.x, p.y + p.height, p.x + p.width, p.y + p.height + 12)
		elseif data.slamDir == 3 then
			enemyHurt(p, p.x, p.y - 12, p.x + p.width, p.y)
		end
	end
	
	if data.slammed then
		p.speedX = 0
		p.speedY = -Defines.player_grav
		p.keys.jump = false
		p.keys.altJump = false
		p.keys.down = false
		p.keys.left = false
		p.keys.right = false
		if not thwompMushroom.settings.canInfinitelySlam then
			data.alreadySlammed = true
		end
		
		if p.keys.altRun == KEYS_PRESSED then
			data.timer = 0
			data.slammed = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			if not thwompMushroom.settings.canInfinitelySlam then
				data.alreadySlammed = true
			end
		end
		
		data.timer = data.timer + 1
		if data.timer >= 30 then
			data.timer = 0
			data.slammed = false
			if data.slamDir == 3 then
				data.returningFromUp = true
			elseif data.slamDir == 1 or data.slamDir == 4 then
				data.returningFromSide = true
			else
				data.returning = true
			end
		end
	end
	
	if data.returning then
		p.speedX = 0
		p.speedY = -3
		p.keys.jump = false
		p.keys.altJump = false
		p.keys.down = false
		if not thwompMushroom.settings.canInfinitelySlam then
			data.alreadySlammed = true
		end
		
		for _,block in ipairs(Block.getIntersecting(p.x, p.y - 1, p.x + p.width, p.y)) do
			if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 and not Block.NONSOLID_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
				data.returning = false
				Effect.spawn(10, p.x - 4, p.y + 8)
			end
		end
		
		if p.keys.altRun == KEYS_PRESSED then
			data.returning = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			p.speedY = 0.1
		end
		
		if p.y <= data.playerLastY - 64 then
			data.returning = false
			Effect.spawn(10, p.x - 4, p.y + 8)
		end
	end
	
	if data.returningFromUp then
		p.speedX = 0
		p.speedY = 3
		p.keys.jump = false
		p.keys.altJump = false
		p.keys.down = false
		if not thwompMushroom.settings.canInfinitelySlam then
			data.alreadySlammed = true
		end
		
		if isOnGround(p) then
			data.returningFromUp = false
			Effect.spawn(10, p.x - 4, p.y + 8)
		end
		
		for _,block in ipairs(Block.getIntersecting(p.x, p.y, p.x + p.width, p.y - 1)) do
			if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 and not Block.NONSOLID_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
				data.returningFromUp = false
				Effect.spawn(10, p.x - 4, p.y + 8)
			end
		end
		
		if p.keys.altRun == KEYS_PRESSED then
			data.returningFromUp = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			p.speedY = 0.1
		end
		
		if p.y >= data.playerLastY then
			data.returningFromUp = false
			Effect.spawn(10, p.x - 4, p.y + 8)
		end
	end
	
	if data.returningFromSide then
		p.speedX = -3 * p.direction
		p.speedY = -Defines.player_grav
		p.keys.jump = false
		p.keys.altJump = false
		p.keys.down = false
		p.keys.left = false
		p.keys.right = false
		if not thwompMushroom.settings.canInfinitelySlam then
			data.alreadySlammed = true
		end
		
		for _,block in ipairs(Block.getIntersecting(p.x - 1, p.y, p.x + p.width + 1, p.y)) do
			if block.isHidden == false and block:mem(0x5a, FIELD_WORD) == 0 and not Block.NONSOLID_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
				data.returningFromSide = false
				Effect.spawn(10, p.x - 4, p.y + 8)
			end
		end
		
		if p.keys.altRun == KEYS_PRESSED then
			data.returningFromSide = false
			Effect.spawn(10, p.x - 4, p.y + 8)
			p.speedX = -0.1 * p.direction
		end
		
		if data.slamDir == 4 then
			if p.x <= data.playerLastX then
				data.returningFromSide = false
				Effect.spawn(10, p.x - 4, p.y + 8)
			end
		elseif data.slamDir == 1 then
			if p.x >= data.playerLastX then
				data.returningFromSide = false
				Effect.spawn(10, p.x - 4, p.y + 8)
			end
		end
	end
end

-- runs when the powerup is active, passes the player
function thwompMushroom.onTickEndPowerup(p)
	if not p.data.thwompMushroom then return end
	local data = p.data.thwompMushroom
	
	-- resets or decrements the animation timer
	if p.deathTimer ~= 0 or p.mount ~= 0 or p.forcedState ~= 0 then 
		data.animTimer = 0 
	else
		if data.slamming or data.slammed or data.returning or data.returningFromUp or data.returningFromSide then
			p.frame = 21
			p:mem(0x160, FIELD_WORD, 2)
		end
	end
end

-- runs when the powerup is active, passes the player
-- function thwompMushroom.onDrawPowerup(p)
	-- if not p.data.thwompMushroom then return end
	-- local data = p.data.thwompMushroom

	-- Text.print(data.alreadySlammed, 10, 10)
-- end

function thwompMushroom.onNPCHarm(token, v, harm, c)
	if harm ~= 1 and harm ~= 8 then return end
	if not c or type(c) ~= "Player" then return end
	if not c.data.thwompMushroom then return end
	c.data.thwompMushroom.alreadySlammed = false
end

function thwompMushroom.onNPCTransform(v, oldId, harm)
	if harm ~= 1 and harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if p.data.thwompMushroom then
			p.data.thwompMushroom.alreadySlammed = false
		end
	end
end


return thwompMushroom