
--[[
	bowsershell.lua by MegaDood
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	Del & 38A/5438a38a - made the original blue shell npc & playable sprites used here (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=20947)
	
	Version 2.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local bumper = require("npcs/ai/bumper")
local springs = require("npcs/ai/springs")

local bowsershell = {}

local shellVariant = {}
local transformableNPCs = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function bowsershell.onInitPowerupLib()
	bowsershell.spritesheets = {
		bowsershell:registerAsset(1, "mario-bowsershell.png"),
		bowsershell:registerAsset(2, "luigi-bowsershell.png"), -- Redid the sprites a bit to make it consistent with Mario's sprites
	}

	bowsershell.iniFiles = {
		bowsershell:registerAsset(1, "mario-bowsershell.ini"),
		bowsershell:registerAsset(2, "luigi-bowsershell.ini"),
	}
end

bowsershell.basePowerup = PLAYER_FIREFLOWER
bowsershell.items = {}
bowsershell.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
bowsershell.cheats = {"needabowsershell","kingofthekoopas"}

-- animation for spinning in the blue shell
local defaultAnimation = {36,37,38,39}

bowsershell.settings = {
	enableSwimAccel = true,
	swimAcceleration = 0.075, -- When underwater, how much extra speed does the player get when swimming forward? (0.075 by default)
	shellComboTime = 130, -- When in the shell, how much time does the player have to hit a NPC before their shell combo resets? (130 by default)
	shellPeachFloat = true, -- When in the shell, should peach be able to float? (true by defauk) 
	inputsNeeded = function(p)	-- What are the inputs needed to change into a shell? (p.keys.run/altRun by default)
		return(
			(p.keys.run or p.keys.altRun)
			-- or (p.keys.down)
		)
	end,
	shellAnimations = {
		[CHARACTER_MARIO] = defaultAnimation,
		[CHARACTER_LUIGI] = defaultAnimation,
		[CHARACTER_PEACH] = defaultAnimation,
		[CHARACTER_TOAD] = defaultAnimation,
		[CHARACTER_LINK] = defaultAnimation,
	}
}

bowsershell.powerupID = 788
bowsershell.projectileID = 789
bowsershell.alwaysHarmNPCs = table.map{12,37,180,179,295,357,413,432,435,437,589,590,641,643}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local projectileTimerMax = {64,64,64,64,64}

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function isUnoccupied(p)
    return (
		Level.endState() == 0
        and p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and (p.mount == 0 or p.mount == MOUNT_BOOT)
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p:mem(0x12E, FIELD_BOOL) or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function canBeShell(p)
	return p.mount == 0 
	and p.holdingNPC == nil 
	and bowsershell.settings.inputsNeeded(p) 
end

local function hittingBumper(p,npc) -- handles changing direction upon hitting a bumper or a sideway spring
	return ( 
		(springs.ids[npc.id] == springs.TYPE.SIDE and p:collide(npc)) 
		or 
		(
			bumper.ids[npc.id] and NPC.config[npc.id].bounceplayer 
			and p:collide(npc.data._basegame.hitbox) 
			and (p.y+p.height > npc.y+10 and p.y < npc.y + npc.height-10)
		)
	)
end

function bowsershell.onInitAPI()
	registerEvent(bowsershell,"onPlayerHarm")
end

-- runs once when the powerup gets activated, passes the player
function bowsershell.onEnable(p)
	if p.data.bowsershell then return end
	p.data.bowsershell = {
		isInShell = false,
		shellCombo = 0,
		comboTimer = 0,
		animTimer = 0,
		lockedDirection = p.direction,
		lastDirection = p.direction * -1,
		lockedSpeed = p.speedX,
		hurtCollider = 0,
		shootTimer = 0,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function bowsershell.onDisable(p)
	-- if the player's in a shell, force them to crouch to prevent the transformation from looking wonky
	if p.data.bowsershell and p.data.bowsershell.isInShell then	
		p.data.bowsershell.isInShell = false
		p:mem(0x12E,FIELD_WORD,0)
		p:mem(0x12E,FIELD_BOOL,true)
		p:mem(0x154,FIELD_WORD,0) -- lets the player hold items again
	end
	p.data.bowsershell = nil
end

-- runs when the powerup is active, passes the player
function bowsershell.onTickPowerup(p)
	if not p.data.bowsershell then return end
	
	local data = p.data.bowsershell 
	local settings = bowsershell.settings
	
	if Level.endState() ~= 0 or p.forcedState > 0 or p.deathTimer > 0 or p:mem(0x0C, FIELD_BOOL) then
		data.isInShell = false
		data.shootTimer = 0
		p:mem(0x3C,FIELD_BOOL,false)
		p:mem(0x12E,FIELD_WORD,0)
		p:mem(0x154,FIELD_WORD,0)
		return 
	end

	if data.hurtCollider == 0 then
		data.hurtCollider = Colliders.Box(p.x, p.y, 16, 32)
	end
	
	data.hurtCollider.x = p.x + 4
	data.hurtCollider.y = p.y - 8
	
	if p.keys.down and not data.isInShell then
		for _,n in ipairs(NPC.get()) do
			if Colliders.collide(data.hurtCollider, n) and n:mem(0x138, FIELD_WORD) == 0 and (not n.isHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] then
				n:harm()
			end
		end
	end
	
	-- handles giving the player a speed boost when underwater
	if p:mem(0x36,FIELD_BOOL) and settings.enableSwimAccel then
		p:mem(0x38, FIELD_WORD, math.min(p:mem(0x38, FIELD_WORD), 5))
		if data.isInShell then
			p:mem(0x38, FIELD_WORD, 5)
		end
		if p.keys.left then
			p.speedX = p.speedX - settings.swimAcceleration
		elseif p.keys.right then
			p.speedX = p.speedX + settings.swimAcceleration
		end
	end
	
	-- starts up going into a shell
	if isOnGround(p) and canBeShell(p) and not data.isInShell 
	and (
		math.abs(p.speedX) >= Defines.player_runspeed 
		or (p.character == CHARACTER_PEACH and math.abs(p.speedX) >= 5.5)
	) then 
		p:mem(0x12E,FIELD_WORD,1) -- keeps the player ducked
		p:mem(0x154,FIELD_WORD,-2) -- prevents the player from holding an item
		data.lockedDirection = math.sign(p.speedX)
		data.lockedSpeed = math.abs(p.speedX)
		data.isInShell = true
	elseif (p.speedX == 0 or not canBeShell(p)) and data.isInShell then -- handles exiting a shell
		data.isInShell = false
		p:mem(0x3C,FIELD_BOOL,false)
		p:mem(0x12E,FIELD_WORD,0) -- unducks the player
		p:mem(0x154,FIELD_WORD,0) -- lets the player hold items again
	end
	
	if data.isInShell then
		data.shootTimer = 0
		p.keys.left = KEYS_UP -- stops the player from skidding
		p.keys.right = KEYS_UP -- stops the player from skidding
		p.keys.down = KEYS_UP -- stops the player from sliding
		
		p.keys.run = KEYS_DOWN -- << needed in order to prevent an issue with slopes
		p.keys.altRun = KEYS_DOWN -- << needed in order to prevent an issue with slopes
		
		p:mem(0x120,FIELD_BOOL,false) -- prevent spinjumping
		p:mem(0x3C,FIELD_BOOL,false) -- stops the player from sliding
		p:mem(0x0A,FIELD_BOOL,false) -- fixes an issue regarding using a shell on slippery slopes
	end
	
	if p:mem(0x50, FIELD_BOOL) then
		data.shootTimer = 0
		p:mem(0x160, FIELD_WORD,math.max(p:mem(0x160, FIELD_WORD),1))
		if isOnGround(p) then return end
	end
	
	data.shootTimer = math.max(data.shootTimer - 1,0)
	
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end
	
	if not isUnoccupied(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED) and not p:mem(0x50, FIELD_BOOL) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	
	if ((tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2) 
	and not (p:mem(0x12E, FIELD_BOOL) and not linkChars[p.character]) and not data.isInShell and p.mount < 3 then
		local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			bowsershell.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		v.direction = dir
		v.speedX = (NPC.config[v.id].speed * dir) + p.speedX/2.5
		if linkChars[p.character] then 
			if not p:mem(0x12E,FIELD_BOOL) then -- if ducking, have the npc not rise higher
				v.y = v.y - 12
			end
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
		else
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character] or projectileTimerMax[1])
			if p.mount == 0 then
				data.shootTimer = 64
			end
			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
		SFX.play(42)
	end
end

-- runs when the powerup is active, passes the player
function bowsershell.onTickEndPowerup(p)
	if not p.data.bowsershell then return end
	local data = p.data.bowsershell
	local settings = bowsershell.settings
	-- handles moving around in a shell
	if data.isInShell then
		p.direction = data.lockedDirection
		p.speedX = data.lockedSpeed * data.lockedDirection

		local upwardsOffset = math.min(p.speedY, 0)
		local downwardsOffset = math.max(p.speedY, 0)
		local leftOffset = math.min(p.speedX, 0)
		local rightOffset = math.max(p.speedX, 0)

		local left = p.x; local right = p.x + p.width
		local top = p.y + 4
		local bottom = p.y + p.height/1.5 
		-- extends the player's horizontal hitbox depending on their current direction
		if data.lockedDirection == -1 then
			left = left + leftOffset
		else
			right = right + rightOffset
		end
		
		-- handles hitting blocks
		local bumpedBlock = false
		for _,block in Block.iterateIntersecting(left, top, right, bottom - upwardsOffset) do 
				-- If block is visible
			if block.isHidden == false and not block:mem(0x5A, FIELD_BOOL) then
				-- If the block should be broken, destroy it
				if Block.MEGA_SMASH_MAP[block.id] then
					if block.contentID > 0 then
						block:hit(false, p)
					else
						block:remove(true)
					end
					bumpedBlock = true
				-- If the block SHOULDN'T be broken, hit it & bump the player
				elseif Block.MEGA_HIT_MAP[block.id] or (Block.SOLID_MAP[block.id] and not Block.SLOPE_MAP[block.id]) then
					block:hit(true, p)
					bumpedBlock = true
				end
			end
		end
		
		local bounds = p.sectionObj.boundary
		if (p.x - 2 <= bounds.left) or (p.x + p.width + 2 >= bounds.right) then
			bumpedBlock = true
		end
		
		-- handles hitting NPCs
		local bumpedNPC = false
		for _, npc in NPC.iterateIntersecting(left, (top + upwardsOffset) + p.speedY, right, (bottom + p.height/2.5 + 10) + downwardsOffset) do 
			if (not npc.friendly) and npc.despawnTimer > 0 and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 then
				if NPC.HITTABLE_MAP[npc.id] and not bowsershell.alwaysHarmNPCs[npc.id] then
					local oldScore = NPC.config[npc.id].score
					NPC.config[npc.id].score = 2 + data.shellCombo -- temporarily changes the npc's score config depending on the current shell combo
					npc:harm(3)
					NPC.config[npc.id].score = oldScore -- immediately changes the npc's score config back to normal 
					if NPC.MULTIHIT_MAP[npc.id] then
						bumpedNPC = true
					else
						-- increments the player's shell combo
						data.comboTimer = settings.shellComboTime
						data.shellCombo = math.min(data.shellCombo + 1, 8)		
					end
				elseif (hittingBumper(p,npc) or NPC.PLAYERSOLID_MAP[npc.id])
				and p.y < npc.y + npc.height - 4 and p.y + p.height - 2 > npc.y + 4 + downwardsOffset then
					bumpedNPC = true
					if npc.data._basegame.hitbox and type(npc.data._basegame.hitbox) == "BoxCollider" then  -- if hitting a bumper NPC
						SFX.play(Misc.resolveSoundFile("bumper")) 
					elseif not hittingBumper(p,npc) then -- if hitting a playersolid NPC
						SFX.play(3)
					end
					break
				end
			end
		end
	
		-- turns the player around
		if bumpedBlock or bumpedNPC then	
			if bumpedBlock then 
				local e = Effect.spawn(
					133,
					(p.x + p.width*0.5) + (16*data.lockedDirection),
					p.y+p.height*0.5
				)
				SFX.play(3) 
			end
			data.lockedDirection = data.lockedDirection * -1
			p.speedX = data.lockedSpeed * data.lockedDirection
		end
		
		data.animTimer = data.animTimer + 1
		data.comboTimer = math.max(data.comboTimer - 1, 0)
	end
	
	-- emits a skidding effect every 2 ticks
	if (data.isInShell or p:mem(0x12E,FIELD_BOOL)) and isOnGround(p) and math.abs(p.speedX) >= 2 and lunatime.tick() % 2 == 0 then 
		Effect.spawn(74, p.x + RNG.random(0,p.width) + p.speedX, p.y + p.height + RNG.random(-4, 4) - 2) 
	end
	-- reset the player's shell combo
	if not data.isInShell or data.comboTimer <= 0 then
		data.shellCombo = 0
		data.comboTimer = 0
	end
end

-- runs when the powerup is active, passes the player
function bowsershell.onDrawPowerup(p)
	if p.forcedState ~= 0 or p.deathTimer > 0 or p.mount > 0 then return end
	if not p.data.bowsershell then return end
	local data = p.data.bowsershell
	
	bowsershell.settings.shellAnimations[p.character] = bowsershell.settings.shellAnimations[p.character] or defaultAnimation
	local animation = bowsershell.settings.shellAnimations[p.character]
	
	local frame
	if data.isInShell then
		frame = animation[1 + math.floor(data.animTimer * (math.min(math.abs(p.speedX), 4) * 0.1)) % #animation] -- sets the animation frame depending on the animTimer
	elseif not data.isInShell and isUnoccupied(p) and data.shootTimer > 0 then
		frame = 11
	end
	if not frame then return end
	p:setFrame(frame)
end

-- fallback if the player was able to be harmed by a NPC while using the blue shell
function bowsershell.onPlayerHarm(token,p)
	if cp.getCurrentPowerup(p) ~= bowsershell or not p.data.bowsershell then return end
	if not p.data.bowsershell.isInShell and not p:mem(0x12E,FIELD_BOOL) then return end
	for _,v in NPC.iterateIntersecting(p.x,p.y,p.x + p.width,p.y + p.height) do
		if (not v.friendly) and v.despawnTimer > 0 
		and (not v.isGenerator) and v.heldIndex == 0 and not bowsershell.alwaysHarmNPCs[v.id]
		and NPC.HITTABLE_MAP[v.id] and not NPC.MULTIHIT_MAP[v.id] then -- prevents the player from getting hurt if the npc can be hit by the player
			-- handles ducking interactions between the player & NPCs
			if not p.data.bowsershell.isInShell and p:mem(0x12E,FIELD_BOOL) then
				p.speedX = 0
				v.direction = -math.sign(p.x + p.width*0.5 - v.x - v.width*0.5) -- turns the npc away from the player
				v.speedX = v.speedX * v.direction
			end
			token.cancelled = true
			break
		end
	end
	if not token.cancelled then
		p:mem(0x12E,FIELD_WORD,0)
		p.data.bowsershell.isInShell = false
	end
end

return bowsershell