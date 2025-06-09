local froggy = {}

local activePlayer
local swimSpeedY = 0
local frametodisplay = 0
local swimSpeedY = 0
local canPlaySwimSound = 0
local hopTimer = 0
local runDirection = 0
local animationTimer = 1
local swimAnimIncrease = 1
local wasSwimming = false
local isInAir = false
local normalWalkSpeed = Defines.player_walkspeed
local normalRunSpeed = Defines.player_runspeed
local normalJumpHeight = Defines.jumpspeed
local normalJumpHeightNPC = Defines.jumpheight_bounce
local normalJumpHeightPlayer = Defines.jumpheight_player
local normalJumpHeightNoteBlock = Defines.jumpheight_noteblock

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

-- jump heights for mario, luigi, peach, toad, & link respectively
local jumpheights = {20,25,20,15,20}

registerEvent(froggy, "onExitLevel", "onExitLevel")
registerEvent(froggy, "onExit", "onExit")

local function handleJumping(p,wasGrounded)	-- handles playing the jump SFX for cases where the player jumps but no SFX plays
	if not (p.keys.jump or p.keys.altJump) then return end
	p.data.froggy.wasGrounded = wasGrounded		
	SFX.play(1)
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
	Defines.jumpspeed = normalJumpHeight
	Defines.jumpheight_bounce = normalJumpHeightNPC
	Defines.jumpheight_player = normalJumpHeightPlayer
	Defines.jumpheight_noteblock = normalJumpHeightNoteBlock
end

-- runs once when the powerup gets activated, passes the player
function froggy.onEnable(p)
	p.data.froggy = {
		wasGrounded = false,
		onWater = false,
	}
	Defines.player_runspeed = Defines.player_runspeed*2
	Defines.player_walkspeed = Defines.player_walkspeed*2
end

-- runs once when the powerup gets deactivated, passes the player
function froggy.onDisable(p)
	Defines.player_walkspeed = normalWalkSpeed
	Defines.player_runspeed = normalRunSpeed
	Defines.jumpspeed = normalJumpHeight
	Defines.jumpheight_bounce = normalJumpHeightNPC
	Defines.jumpheight_player = normalJumpHeightPlayer
	Defines.jumpheight_noteblock = normalJumpHeightNoteBlock
	p.data.keepYPositionForSuit = nil
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

-- runs when the powerup is active, passes the player
function froggy.onTickPowerup(p)
	local data = p.data.froggy
	activePlayer = p
	local ps = p:getCurrentPlayerSetting()
	if p.character ~= 5 then p:mem(0x160, FIELD_WORD, 2) end
	if p.character ~= 5 and p.mount == 0 then
		p.keys.altJump = false
		
		local sec = Section(p.section)
		local liquid = Liquid.getIntersecting(p.x, p.y, p.x+p.width, p.y+p.height)
		
		
		--Swimming code by Cpt. Monochrome, with edits by me
		if p:mem(0x36, FIELD_BOOL) then
			if not wasSwimming then
				Defines.player_runspeed = Defines.player_runspeed*2
				Defines.player_walkspeed = Defines.player_walkspeed*2
				wasSwimming = true
				swimSpeedY = p.speedY
			end
			if swimSpeedY < -4 and not checkBlockAbove(p, p.speedY-swimSpeedY) then
				p.y = p.y+(swimSpeedY-p.speedY)
			elseif swimSpeedY > 3 and not p:isOnGround() and not checkBlockBelow(p, swimSpeedY-p.speedY) then
				p.y = p.y+(swimSpeedY-p.speedY)
			end
			
		end
		
		ps.hitboxDuckHeight = 32
		
		if p.holdingNPC == nil and (sec.isUnderwater or #liquid ~= 0) then
			if not p.data.frogOrPenguinSuitDisableWater then
				p.speedY = p.speedY-(Defines.player_grav/10)
				if Level.endState() == 0 then
					local swimspeed
					if p.keys.run or p.keys.altRun then
						--swimspeed = Defines.player_runspeed
						swimspeed = 5
						swimAnimIncrease = 2
					else
						--swimspeed = Defines.player_walkspeed
						swimspeed = 3
						swimAnimIncrease = 1
					end
					ps.hitboxDuckHeight = 56
					if p.keys.right then
						p.speedX = math.min(p.speedX+froggy.settings.waterAccelerationConstant,swimspeed)
					elseif p.keys.left then
						p.speedX = math.max(p.speedX-froggy.settings.waterAccelerationConstant,-swimspeed)
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
				
					if wasSwimming then
						if p.keys.up and p:mem(0x14A, FIELD_WORD) == 0 then
							swimSpeedY = math.max(swimSpeedY-froggy.settings.waterAccelerationConstant,-swimspeed)
						elseif p.keys.down then
							swimSpeedY = math.min(swimSpeedY+froggy.settings.waterAccelerationConstant,swimspeed)
						elseif p.keys.right or p.keys.left then
							if swimSpeedY > 0 then
								swimSpeedY = math.max(0, swimSpeedY-froggy.settings.waterAccelerationConstant)
							else
								swimSpeedY = math.min(0, swimSpeedY+froggy.settings.waterAccelerationConstant)
							end
						elseif swimSpeedY > 0 then
							swimSpeedY = math.max(0, swimSpeedY-froggy.settings.waterDecelerationConstant)
						else
							swimSpeedY = math.min(0, swimSpeedY+froggy.settings.waterDecelerationConstant)
						end
					
						p.speedY = swimSpeedY-(Defines.player_grav/10)
					else
						swimSpeedY = 0
					end
					p:mem(0x38, FIELD_WORD, 2)
					if p:mem(0x14E, FIELD_WORD) > 0 then	
						p.keys.down = false
					elseif (p.keys.down == KEYS_DOWN or p.keys.down == KEYS_PRESSED) and p:isOnGround() and p.holdingNPC ~= nil and (p.keys.run == KEYS_DOWN or p.keys.altRun == KEYS_DOWN) then
						handleSwimCrouch(p)
					end
					
					canPlaySwimSound = canPlaySwimSound - 1
					
					--Make a swim sound effect
					if (p.frame == 41 or p.frame == 37 or p.frame == 33) and canPlaySwimSound <= 0 and froggy.settings.playSwimSFX and p.forcedState == 0 then
						SFX.play(72)
						canPlaySwimSound = 12 / swimAnimIncrease
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
			if wasSwimming then
				wasSwimming = false
				if p.speedY <= -4 then
					p.speedY = p.speedY - 6
				end
			end

			--The code that makes him hop
			if p:isOnGround() and not p:mem(0x3C, FIELD_BOOL) and p.holdingNPC == nil and p.mount == 0 then
				if isInAir then p.speedX = 0 end
				if hopTimer <= 0 and not p.keys.down then
					isInAir = false
					runDirection = p.direction
					--Initiate a hop
					if p.keys.left or p.keys.right then
						hopTimer = 40
						SFX.play("powerups/frog-hop.wav")
					end
				else
					--Animation for the hop, and let the player move
					hopTimer = hopTimer - 1
					--If dashing, hop further
					if (p.keys.run or p.keys.altRun) and (p.keys.left or p.keys.right) and math.abs(p.speedX) < normalRunSpeed then
						if p.direction == runDirection then
							p.speedX = p.speedX * 1.0625
						end
						swimAnimIncrease = 2
					else
						swimAnimIncrease = 1
					end
					--Slow down the player once hopTimer reaches close to 0
					if hopTimer <= 4 then
						p.speedX = p.speedX / (3 * swimAnimIncrease)
					end
				end
				
				--Change the jump heights of the player
				Defines.jumpspeed = -6.4
				Defines.jumpheight_bounce = 20.7
				Defines.jumpheight_player = 22.7
				Defines.jumpheight_noteblock = 25.7
				
			else
				hopTimer = 4
				isInAir = true
			end
			
			-- "replaces" the default SMBX jump with a replica that allows extended jumpheights
			if data.wasGrounded and (p.keys.jump or p.keys.altJump) then
				local finalHeight = 0 
				finalHeight = jumpheights[p.character]
				
				p:mem(0x11C,FIELD_WORD, finalHeight) -- sets the final jumpheight the player can have
				
				data.wasGrounded = false

			elseif not p:isOnGround() then
				data.wasGrounded = false
			end
			
			data.onWater = false
			
			if p.holdingNPC ~= nil and froggy.settings.allowWaterRun then
				-- Code by MrNameless!
				for k, l in ipairs(Liquid.getIntersecting(p.x,p.y,p.x+p.width,p.y+p.height + 2 + p.speedY/2)) do 
					-- if the player's above water & is running fast enough
					if p.mount == 0 and p.y + p.height < l.y + 2 and (math.abs(p.speedX) >= 5.5) then -- speed check has to be 5.5 because peach has a slower max speed of 5.58 for some god forsaken reason
						p.y = l.y - 2 - p.height
						p.speedY = -Defines.player_grav
						data.wasGrounded = true
						data.onWater = true
						Routine.run(function()
							Routine.skip() -- delays jump handling check by 1 frame/tick
							handleJumping(p,true)
						end)
						if lunatime.tick() % 3 == 0 then -- spawn a water splashing effect every 3 frames
							local e = Effect.spawn(114, (p.x + p.width*0.5) + 4 + p.speedX, l.y) 
							e.xAlign = 0.5
							e.x = (e.x - (e.width * 0.5)) - (p.width * p.direction)
						end
					end
				end
			end
			
			--Make all the movement stuff work properly
			p:mem(0x36, FIELD_BOOL, false)
			Defines.player_walkspeed = normalWalkSpeed
			Defines.player_runspeed = normalRunSpeed
			canPlaySwimSound = 0
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
	if p.character ~= 5 and p.mount == 0 then
		if p:mem(0x36, FIELD_BOOL) then
			
			--Animation stuff, thanks to Cpt. Monochrome's penguin code as a reference
			if not p.data.frogOrPenguinSuitDisableWater then
				if not Misc.isPaused() then
					if p.holdingNPC == nil then
						if p.keys.left or p.keys.right then
							p.frame = math.floor((lunatime.tick() / (8 / swimAnimIncrease)) % 4 + 41)
						elseif p.keys.up then
							p.frame = math.floor((lunatime.tick() / (12 / swimAnimIncrease)) % 3 + 46)
						elseif p.keys.down then
							p.frame = math.floor((lunatime.tick() / (12 / swimAnimIncrease)) % 3 + 36)
						else
							if lunatime.tick() % 24 <= 12 then
								p.frame = 40
							else
								p.frame = 44
							end
						end
					end
				end
			end
			
		else
			if p:isOnGround() and not p:mem(0x3C, FIELD_BOOL) and p.holdingNPC == nil and (not p.keys.down and p.speedX ~= 0)then
				if isInAir then
					p.frame = 1
				else
					if hopTimer > 0 and not p.keys.down then
						p.frame = math.floor(-(hopTimer - 8) / 16) % 3 + 1
					end
				end
			end
		end
	end
end

return froggy