local froggy = {}

local activePlayer

local normalWalkSpeed = Defines.player_walkspeed
local normalRunSpeed = Defines.player_runspeed

local wasMuted1 = false
local wasMuted2 = false

froggy.settings = {
	allowWaterRun = true, -- should the player be able to run on water, while holding an item?
	waterAccelerationConstant = 1.5,
	waterDecelerationConstant = 0.125,
	playSwimSFX = true,
	aliases = {"ribbit","youcanstopaskingforitnow","longtimecoming","kissme"},
}

froggy.basePowerup = PLAYER_FIREFLOWER
froggy.items = {}
froggy.forcedStateType = 2
froggy.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

function froggy.onInitPowerupLib()
	froggy.spritesheets = {
		[1] = froggy:registerAsset(1, "frog-mario.png"),
		[2] = froggy:registerAsset(2, "frog-luigi.png"),
		[3] = froggy:registerAsset(3, "frog-peach.png"),
		[4] = froggy:registerAsset(4, "frog-toad.png"),
		[5] = froggy:registerAsset(5, "frog-link.png"),
	}

	froggy.iniFiles = {
		[1] = froggy:registerAsset(1, "frog-mario.ini"),
		[2] = froggy:registerAsset(2, "frog-luigi.ini"),
		[3] = froggy:registerAsset(3, "frog-peach.ini"),
		[4] = froggy:registerAsset(4, "frog-toad.ini"),
		[5] = froggy:registerAsset(5, "frog-link.ini"),
	}
end

-- jump heights for mario, luigi, peach, toad, & link respectively
local jumpheights = {23,28,23,18,23}

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function handleJumping(p,allowSpin,forceJump,playSFX,inputCheck) -- "replaces" the default SMBX jump with a replica that allows adjustable jumpheight
	if p.deathTimer > 0 then return end
	if not p.keys.jump and not p.keys.altJump then return end
	local shouldJump = false
	local holdingJump = p.keys.jump or p.keys.altJump
	local tappingJump = p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED
	
	if ((inputCheck == "tap" and tappingJump) or (inputCheck == "hold" and holdingJump))
	and p.mount ~= MOUNT_CLOWNCAR
	and p:mem(0x26,FIELD_WORD) == 0	
	then
		shouldJump = true
	end
	
	local finalHeight = jumpheights[p.character]
	if (p.mount ~= 0 and p.keys.altJump == KEYS_PRESSED) or ((isOnGround(p) or forceJump) and shouldJump) then
		Audio.sounds[1].muted = true
		Audio.sounds[33].muted = true
		if allowSpin  -- lessens the jumpheight when spinjumping
		and p.keys.altJump and p.mount == 0
		and p.character ~= CHARACTER_PEACH 
		and not linkChars[p.character] then 
			finalHeight = jumpheights[p.character] - 10
			p:mem(0x50,FIELD_BOOL, true)
			if playSFX then SFX.play(33) end
		else
			if playSFX then SFX.play(1) end
		end
		Routine.run(function()
			Routine.skip()
			p:mem(0x11C,FIELD_WORD, finalHeight) -- this handles jumpheights (this trick doesn't affect springs :[ )
			Audio.sounds[1].muted = wasMuted1
			Audio.sounds[33].muted = wasMuted2
		end)
	end
end

function froggy.onInitAPI()
	registerEvent(froggy, "onNPCHarm")
	registerEvent(froggy, "onNPCTransform")
	registerEvent(froggy, "onBlockHit")
	registerEvent(froggy, "onExitLevel", "onExitLevel")
	registerEvent(froggy, "onExit", "onExit")
end

function froggy.onExit()
	if activePlayer then
		local ps = activePlayer:getCurrentPlayerSetting()
		activePlayer.hitboxDuckHeight = 32
		activePlayer.data.keepYPositionForSuit = nil
	end
end

--Reset walk and run speed cause being in the water doubles it
function froggy.onExitLevel(winType)
	Defines.player_walkspeed = normalWalkSpeed
	Defines.player_runspeed = normalRunSpeed
end

-- runs once when the powerup gets activated, passes the player
function froggy.onEnable(p)
	local wasMuted1 = Audio.sounds[1].muted
	local wasMuted2 = Audio.sounds[33].muted
	
	p.data.froggy = {
		wasGrounded = false,
		onWater = false,

		swimSpeedY = 0,
		canPlaySwimSound = 0,
		hopTimer = 0,
		runDirection = 0,
		swimAnimIncrease = 1,
		wasSwimming = false,
		isInAir = false,
		swimSpeed = 0,
	
		isWaterRunning = false
	}
end

-- runs once when the powerup gets deactivated, passes the player
function froggy.onDisable(p)
	Defines.player_walkspeed = normalWalkSpeed
	Defines.player_runspeed = normalRunSpeed

	p.data.keepYPositionForSuit = nil
	p.data.froggy = nil
	
	local ps = p:getCurrentPlayerSetting()
	ps.hitboxDuckHeight = 32
end

--Code by Cpt. Monochrome
local function checkBlockAbove(p,speed)
	local boxHeight = (speed)
	if Block.iterateIntersecting(p.x, p.y-boxHeight, p.x+p.width, p.y) ~= nil then
		for _,currentBlock in Block.iterateIntersecting(p.x, p.y-boxHeight, p.x+player.width, p.y) do
			if table.icontains(Block.SOLID, currentBlock.id) then
				return true
			end
		end
	end
	for _,currentNPC in NPC.iterateIntersecting(p.x, p.y-boxHeight, p.x+p.width, p.y) do
		if NPC.config[currentNPC.id].playerblock and currentNPC ~= p.holdingNPC then
			return true
		end
	end
	return false
end

local function checkBlockBelow(p,speed)
	local boxHeight = (speed)
	if Block.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+speed) ~= nil then
		for _,currentBlock in Block.iterateIntersecting(p.x, p.y-boxHeight, p.x+p.width, p.y) do
			if table.icontains(Block.SOLID, currentBlock.id) then
				return true
			end
		end
	end
	for _,currentNPC in NPC.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+speed) do
		if NPC.config[currentNPC.id].playerblock and currentNPC ~= p.holdingNPC then
			return true
		end
	end
	return false
end

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canDoActions(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

-- runs when the powerup is active, passes the player
function froggy.onTickPowerup(p)
	if not p.data.froggy then return end
	local data = p.data.froggy

	activePlayer = p
	local ps = p:getCurrentPlayerSetting()

	if p.character ~= 5 then p:mem(0x160, FIELD_WORD, 2) end

	if not canDoActions(p) then return end

	if p.character ~= 5 and p.mount == 0 then
		p.keys.altJump = false
		
		local sec = Section(p.section)
		local liquid = Liquid.getIntersecting(p.x, p.y, p.x+p.width, p.y+p.height)
		
		--Swimming code by Cpt. Monochrome, with edits by me
		if p:mem(0x36, FIELD_BOOL) then
			if not data.wasSwimming then
				Defines.player_runspeed = Defines.player_runspeed*2
				Defines.player_walkspeed = Defines.player_walkspeed*2
				data.wasSwimming = true
				data.swimSpeedY = p.speedY
			end
			if data.swimSpeedY < -4 and not checkBlockAbove(p, p.speedY-data.swimSpeedY) then
				p.y = p.y+(data.swimSpeedY-p.speedY)
			elseif data.swimSpeedY > 3 and not p:isOnGround() and not checkBlockBelow(p, data.swimSpeedY-p.speedY) then
				p.y = p.y+(data.swimSpeedY-p.speedY)
			end
			
		end
		
		ps.hitboxDuckHeight = 32
		
		if (sec.isUnderwater or #liquid ~= 0) then
			if not p.data.frogOrPenguinSuitDisableWater then
				p.speedY = p.speedY-(Defines.player_grav/10)
				if Level.endState() == 0 then
					if p.keys.run or p.keys.altRun then
						--swimspeed = Defines.player_runspeed
						data.swimSpeed = 5
						data.swimAnimIncrease = 2
					else
						--swimspeed = Defines.player_walkspeed
						data.swimSpeed = 3
						data.swimAnimIncrease = 1
					end
					ps.hitboxDuckHeight = 56
					if p.keys.right then
						p.speedX = math.min(p.speedX+froggy.settings.waterAccelerationConstant,data.swimSpeed)
					elseif p.keys.left then
						p.speedX = math.max(p.speedX-froggy.settings.waterAccelerationConstant,-data.swimSpeed)
					elseif p.keys.up or p.keys.down then
						if p.speedX > 0 then
							p.speedX = math.max(0, p.speedX-froggy.settings.waterAccelerationConstant)
						else
							p.speedX = math.min(0, p.speedX+froggy.settings.waterAccelerationConstant)
						end
					elseif p.speedX > 0 then
						p.speedX = math.max(0, p.speedX-froggy.settings.waterDecelerationConstant)
					else
						p.speedX = math.min(0, p.speedX+froggy.settings.waterDecelerationConstant)
					end
				
					if data.wasSwimming then
						if p.keys.up and p:mem(0x14A, FIELD_WORD) == 0 then
							data.swimSpeedY = math.max(data.swimSpeedY-froggy.settings.waterAccelerationConstant,-data.swimSpeed)
						elseif p.keys.down then
							data.swimSpeedY = math.min(data.swimSpeedY+froggy.settings.waterAccelerationConstant,data.swimSpeed)
						elseif p.keys.right or p.keys.left then
							if data.swimSpeedY > 0 then
								data.swimSpeedY = math.max(0, data.swimSpeedY-froggy.settings.waterAccelerationConstant)
							else
								data.swimSpeedY = math.min(0, data.swimSpeedY+froggy.settings.waterAccelerationConstant)
							end
						elseif data.swimSpeedY > 0 then
							data.swimSpeedY = math.max(0, data.swimSpeedY-froggy.settings.waterDecelerationConstant)
						else
							data.swimSpeedY = math.min(0, data.swimSpeedY+froggy.settings.waterDecelerationConstant)
						end
					
						p.speedY = data.swimSpeedY-(Defines.player_grav/10)
					else
						data.swimSpeedY = 0
					end
					p:mem(0x38, FIELD_WORD, 2)
					if p:mem(0x14E, FIELD_WORD) > 0 then	
						p.keys.down = false
					--elseif (p.keys.down == KEYS_DOWN or p.keys.down == KEYS_PRESSED) and p:isOnGround() and p.holdingNPC ~= nil and (p.keys.run == KEYS_DOWN or p.keys.altRun == KEYS_DOWN) then
						--handleSwimCrouch(p)
					end
					
					data.canPlaySwimSound  = data.canPlaySwimSound  - 1
					
					--Make a swim sound effect
					if (p.frame == 41 or p.frame == 37 or p.frame == 47 or p.frame == 21) and data.canPlaySwimSound  <= 0 and froggy.settings.playSwimSFX and p.forcedState == 0 then
						SFX.play(72)
						data.canPlaySwimSound  = 12 / data.swimAnimIncrease
					end
				else
					if not p.data.keepYPositionForSuit then
						p.data.keepYPositionForSuit = p.y
					else
						p.y = p.data.keepYPositionForSuit
					end
				end
			end
		else
			--If exiting the water, leap out
			if data.wasSwimming then
				data.wasSwimming = false
				if p.speedY <= -4 then
					p.speedY = p.speedY - 6
				end
			end

			--The code that makes him hop
			if isOnGround(p) and not p:mem(0x3C, FIELD_BOOL) and p.holdingNPC == nil and p.mount == 0 then
				if data.isInAir then p.speedX = 0 end
				if data.hopTimer <= 0 and not p.keys.down then
					data.isInAir = false
					data.runDirection = p.direction
					--Initiate a hop
					if p.keys.left or p.keys.right then
						data.hopTimer = 35
						SFX.play("powerups/frog-hop.wav")
					end
				else
					--Animation for the hop, and let the player move
					data.hopTimer = data.hopTimer - 1
					--If dashing, hop further
					if (p.keys.run or p.keys.altRun) and (p.keys.left or p.keys.right) and math.abs(p.speedX) < normalRunSpeed then
						if p.direction == data.runDirection then
							p.speedX = p.speedX * 1.075
						end
						data.swimAnimIncrease = 2
					else
						data.swimAnimIncrease = 1
					end
					--Slow down the player once hopTimer reaches close to 0
					if data.hopTimer <= 8 then
						if p.speedX > 0 then
            						p.speedX = p.speedX - (0.45 * data.swimAnimIncrease)
        					elseif p.speedX < 0 then
            						p.speedX = p.speedX + (0.45 * data.swimAnimIncrease)
        					end
        					if p.speedX >= -(0.45 * data.swimAnimIncrease) and p.speedX <= (0.45 * data.swimAnimIncrease) then
            						p.speedX = 0
        					end
					end
				end
				
				p.speedX = math.clamp(p.speedX, -5, 5)
			else
				data.hopTimer = 4
				data.isInAir = true
			end
			
			-- replaces the default SMBX jump with a replica that allows extended jumpheights
			if isOnGround(p) or (not isOnGround(p) and p.mount ~= 0) then
				handleJumping(p,true,false,true,"tap")
			end

			if p:mem(0x50,FIELD_BOOL) and p.mount ~= 0 then
				for _, n in NPC.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+32+math.max(p.speedY,0)) do
					if n.isValid and not n.isHidden and n.despawnTimer > 0 and NPC.config[n.id].spinjumpsafe then
						local isColliding, isSpinjumping = Colliders.bounce(p, n)
						if isColliding and (isSpinjumping or p.mount ~= 0) then
							handleJumping(p,false,true,false,"hold")
							break
						end
					end
				end
			end
			
			data.onWater = false
			
			if p.holdingNPC ~= nil and froggy.settings.allowWaterRun then
				-- Code by MrNameless!
				for k, l in ipairs(Liquid.getIntersecting(p.x,p.y,p.x+p.width,p.y+p.height + 2 + p.speedY/2)) do 
					-- if the player's above water & is running fast enough
					if p.mount == 0 and p.y + p.height < l.y + 2 and not p.keys.down and (math.abs(p.speedX) >= 5.5) then -- speed check has to be 5.5 because peach has a slower max speed of 5.58 for some god forsaken reason
						p.y = l.y - 2 - p.height
						p.speedY = -Defines.player_grav
						data.wasGrounded = true
						data.onWater = true
						Routine.run(function()
							Routine.skip() -- delays jump handling check by 1 frame/tick
							handleJumping(p,true,false,true,"tap")
						end)
						if lunatime.tick() % 3 == 0 then -- spawn a water splashing effect every 3 frames
							local e = Effect.spawn(114, (p.x + p.width*0.5) + 4 + p.speedX, l.y) 
							e.xAlign = 0.5
							e.x = (e.x - (e.width * 0.5)) - (p.width * p.direction)
						end
						data.isWaterRunning = true
					else
						data.isWaterRunning = false
					end
				end
			end
			
			--Make all the movement stuff work properly
			p:mem(0x36, FIELD_BOOL, false)
			Defines.player_walkspeed = normalWalkSpeed
			Defines.player_runspeed = normalRunSpeed
			data.canPlaySwimSound  = 0
		end
	else
		if Level.winState() > 0 then return end
		if not p.data.frogOrPenguinSuitDisableWater then
			p:mem(0x162, FIELD_WORD, 2)
			local sec = Section(p.section)
			local liquid = Liquid.getIntersecting(p.x, p.y, p.x+p.width, p.y+p.height)
			if sec.isUnderwater or #liquid ~= 0 and p.mount == 0 then
				if (p.keys.jump or p.keys.altJump) then
					if p.keys.up and p:mem(0x14A, FIELD_WORD) == 0 then
						p.speedY = -6
						p.speedX = 0
					elseif p.keys.down then
						p.speedY = 6
						p.speedX = 0
					elseif p.keys.right then
						p.speedX = 6
						p.speedY = -Defines.npc_grav
					elseif p.keys.left then
						p.speedX = -6
						p.speedY = -Defines.npc_grav
					end
				end
			end
		end
	end
end

-- runs when the powerup is active, passes the player
function froggy.onDrawPowerup(p)
	if not p.data.froggy then return end
	local data = p.data.froggy

	if Misc.isPaused() or not canDoActions(p) then return end
	
	if p.character ~= 5 and p.mount == 0 then
		if p:mem(0x36, FIELD_BOOL) then
			
			--Animation stuff, thanks to Cpt. Monochrome's penguin code as a reference
			if not p.data.frogOrPenguinSuitDisableWater then
				if p.holdingNPC == nil then
					if p.keys.left or p.keys.right then
						p.frame = math.floor((lunatime.tick() / (12 / data.swimAnimIncrease)) % 3 + 41)
					elseif p.keys.up then
						p.frame = math.floor((lunatime.tick() / (12 / data.swimAnimIncrease)) % 3 + 46)
					elseif p.keys.down then
						p.frame = math.floor((lunatime.tick() / (12 / data.swimAnimIncrease)) % 3 + 36)
					else
						if lunatime.tick() % 24 <= 12 then
							p.frame = 40
						else
							p.frame = 44
						end
					end
				elseif p.holdingNPC ~= nil then
					if p.keys.left or p.keys.right or p.keys.up or p.keys.down then
						p.frame = math.floor((lunatime.tick() / (12 / data.swimAnimIncrease)) % 3 + 19)
					else
						if lunatime.tick() % 24 <= 12 then
							p.frame = 11
						else
							p.frame = 12
						end
					end
				end
			end			
		else
			if p.holdingNPC ~= nil and not p.keys.down and (math.abs(p.speedX) >= 5.5) and (isOnGround(p) or data.isWaterRunning) then
				p.frame = math.floor((lunatime.tick() / 2) % 3 + 16)
			end
			if not p:mem(0x3C, FIELD_BOOL) and p.holdingNPC == nil and not p.keys.down then
				if isOnGround(p) then
					if data.isInAir then
						p.frame = 1
					else
						if (p.speedX > 0 and p.keys.left) or (p.speedX < 0 and p.keys.right) then
							p.frame = 6
						elseif data.hopTimer > 0 and not p.keys.down then
							p.frame = math.floor(-(data.hopTimer - 8) / 10) % 4 + 2
						end
					end
				else
					if p.speedY < 0 then
						p.frame = 39
					else
						p.frame = 49
					end
				end
			end
		end
	end
end

-- the following chunks of code all refreshes the player's jump replica

function froggy.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "Player" then return end
	if harm ~= 1 and harm ~= 8 then return end
	if not c.data.froggy then return end 	
	handleJumping(c,false,true,false,"hold")
end

-- check if a player was right above the NPC whenever it was transformed by a jump/sword harmtype
function froggy.onNPCTransform(v,oldID,harm)
	if harm ~= 1 and harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if p.data.froggy then
			-- refreshes the player's jump replica
			handleJumping(p,false,true,false,"hold")
		end
	end
end

-- check if a player was right above the noteblock whenever it was hit from above
function froggy.onBlockHit(token,v,upper,p)
	if v.id ~= 55 or not upper then return end
	for _,p in ipairs(Player.getIntersecting(v.x,v.y - 4,v.x + v.width,v.y + v.height)) do  -- refreshes the player's jump replica after hitting a note block
		if p.data.froggy then
			handleJumping(p,false,true,true,"hold")
		end
	end
end

return froggy