local rockMushroom = {
	setSpeed = true,	-- if true, the player will accelerate towards a set speed and gradually slow down to reach that speed again when faster
	rollSpeed = 9,		-- the speed the player is rolling at by default
	rollAccel = 0.1,	-- how quickly the rock accelerates
	rollDeccel = 0.02,	-- how quickly the rock deccelerates if it's faster than rollSpeed
	
	rollAnimDelay = 4,	-- amount of frames between each animation frame (of the startup)
	
	rockWidth = 80,		-- width of the player hitbox when in a rock
	rockHeight = 80,	-- height of yadda yadda
	
	cooldown = 32,		-- how many frames the player has to wait until they can start rollin' again
	
	canCancel = 1,		-- if 0, you can't cancel anything. If 1, you can cancel the startup animation by holding down. If 2, you can cancel the rolling as well
	
	isInvulnerable = false,	-- if true, the player will not take damage in rock formation but just leave it and get a few I-frames
}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

-- how to register:
-- local cp = require("customPowerups")
-- local myPowerup = cp.addPowerup("My Powerup", "rockMushroom", [optional itemID/list of item IDs])

local GP
pcall(function() GP = require("GroundPound") end)

local starShader = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))
local maskShader = Shader.fromFile(nil, "shaders/effects/mask.frag")

function rockMushroom.onInitPowerupLib()
	rockMushroom.spritesheets = {
		rockMushroom:registerAsset(1, "rock-mario.png"),
		rockMushroom:registerAsset(2, "rock-luigi.png"),
	}

	rockMushroom.iniFiles = {
		rockMushroom:registerAsset(1, "rock-mario.ini"),
		rockMushroom:registerAsset(2, "rock-luigi.ini"),
	}

	rockMushroom.rollSpritesheet = {
		rockMushroom:registerAsset(1, "rollingRock_mario.png"),
		rockMushroom:registerAsset(2, "rollingRock_luigi.png"),
	}
end

rockMushroom.basePowerup = 3
rockMushroom.items = {}
rockMushroom.cheats = {"needarockmushroom", "rocknroll", "theyseemerolling","wewillrockyou","ontherocks"}
rockMushroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

local function blockFilterBump(o)
    if not (o.isHidden or Block.SLOPE_MAP[o.id] or not Block.SOLID_MAP[o.id] or Block.MEGA_SMASH_MAP[o.id]) then
        return true
    end
end

local function blockFilterSmash(o)
    if not (o.isHidden or Block.SLOPE_MAP[o.id] or not Block.MEGA_SMASH_MAP[o.id]) then
        return true
    end
end

local function blockFilterslope(block)
    -- the mem addresses are for .isHidden and .invisible respectively. i just like knowing exactly what's happening lol
    if (not (block:mem(0x1C, FIELD_BOOL) or block:mem(0x1C, FIELD_BOOL))) then 
        return true
    end
end

local function isOnGroundRedigit(p) -- grounded player check. surprisingly, doing it the redigit way is more reliable than player:is On Ground()
    return (
        p.speedY == 0
        or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC (this is -1 when standing on a moving block. thanks redigit.)
        or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
    )
end

local function canStartRolling(p)
	return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and p.forcedState == 0
		and not p:mem(0x50,FIELD_BOOL)		-- spinjumping
		and p.data.rockMushroom.rockCooldown == 0	-- not on a cooldown
        and p:mem(0x26,FIELD_WORD) <= 0 	-- pulling objects from top
		and p:mem(0x06,FIELD_WORD) == 0		-- quicksand
		and not p:mem(0x36,FIELD_BOOL)		-- underwater
        and not p:mem(0x12E, FIELD_BOOL) 	-- ducking
        and not p:mem(0x3C,FIELD_BOOL) 		-- sliding
        and not p:mem(0x44,FIELD_BOOL) 		-- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) 		-- statue
        and p:mem(0x164, FIELD_WORD) == 0 	-- tail attack
        and not p:mem(0x0C, FIELD_BOOL) 	-- fairy
        and (not GP or not GP.isPounding(p))
		and p.data.rockMushroom.collisionCheck
    ) 
end

local function canContinueRolling(p)
	return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and p.forcedState == 0
		and not p:mem(0x50,FIELD_BOOL)		-- spinjumping
		and p.data.rockMushroom.rockCooldown == 0	-- not on a cooldown
        and p:mem(0x26,FIELD_WORD) <= 0 	-- pulling objects from top
		and p:mem(0x06,FIELD_WORD) == 0		-- quicksand
		and not p:mem(0x36,FIELD_BOOL)		-- underwater
        and not p:mem(0x12E, FIELD_BOOL) 	-- ducking
        and not p:mem(0x44,FIELD_BOOL) 		-- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) 		-- statue
        and p:mem(0x164, FIELD_WORD) == 0 	-- tail attack
        and not p:mem(0x0C, FIELD_BOOL) 	-- fairy
        and (not GP or not GP.isPounding(p))
		and p.data.rockMushroom.collisionCheck
    ) 
end

local function disableRoll(p,bump)
	local data = p.data.rockMushroom
	data.isRockRolling = false
	data.animTimer = 0
	data.animFrame = 0
	data.snowOpacity = 0
	data.rockCooldown = rockMushroom.cooldown	-- a little bit of cooldown
	
	local settings = PlayerSettings.get(p.character, p.powerup)	-- resize the player's hitbox to it's normal size again
	settings.hitboxHeight = data.defaultHeight
	settings.hitboxWidth = data.defaultWidth
	
	
	Effect.spawn(762,p.x + p.width * 0.5,p.y + p.height * 0.5)			-- big pebbles fall off
	Effect.spawn(763,p.x + p.width * 0.5,p.y + p.height * 0.5)			-- small pebbles fly off
	SFX.play(2)
	
	if bump then	-- hit a wall, bounce back
		p.speedX = -4 * data.rollDir
		p.speedY = -8
		SFX.play(37)	-- thwomp sfx
		Defines.earthquake = 10
	end
end

function rockMushroom.onInitAPI()
	registerEvent(rockMushroom,"onPlayerHarm")
end

-- runs once when the powerup gets activated, passes the player
function rockMushroom.onEnable(p)
	p.data.rockMushroom = {
		isRockRolling = false, 
		rollDir = 1,
		collisionCheck = false,	-- true if no block would interfere with a giant boulder that just happens to appear at Mario's position
		checkCollider = Colliders.Rect(0,0,80,80,0),
		breakCollider = Colliders.Rect(0,0,90,90,0),
		slopeCollider = Colliders.Box(0, 0, 1, 1, 0),
		defaultHeight = PlayerSettings.get(p.character, p.powerup).hitboxHeight,
		defaultWidth = 	PlayerSettings.get(p.character, p.powerup).hitboxWidth,
		animFrame = 0,
		rotation = 0,
		animTimer = 0,
		slopeAngle = 0,
		prevSpeed = 0,
		startedOnGround = false,
		snowOpacity = 0,	-- goes up towards 0.6 when the player is on slippery ground and goes down to 0 again when not.
	}
	
end

-- runs once when the powerup gets deactivated, passes the player
function rockMushroom.onDisable(p)
	if p.data.rockMushroom then		-- if the player is rolling, make sure to stop the roll!
		if p.data.rockMushroom.isRockRolling then
			disableRoll(p,false)
		end
	end
end

-- runs when the powerup is active, passes the player
function rockMushroom.onTickPowerup(p)
	local data = p.data.rockMushroom
	
	if p.character ~= CHARACTER_LINK then
		p:mem(0x160, FIELD_WORD, 2)
	else
		p:mem(0x162, FIELD_WORD, 2)
	end
	
	data.rockCooldown = math.clamp((data.rockCooldown or 0) - 1, 0, rockMushroom.cooldown) 
	
	data.collisionCheck = true
	for c, b in ipairs(Colliders.getColliding{a = data.checkCollider, btype = Colliders.BLOCK, filter = blockFilterBump}) do
		data.collisionCheck = false
	end
	
	if p.keys.altRun == KEYS_PRESSED and canStartRolling(p) and not data.isRockRolling then
		if isOnGroundRedigit(p) then
			p.speedY = -6
		end
		data.isRockRolling = true
		data.animFrame = 0
		data.animTimer = 0
	end
	
	if data.isRockRolling then
		if data.animFrame < 6 then
			if p.speedY >= 0 then	-- make the player hover in place when rolling up
				p.speedY = -0.41
			end
			if data.animTimer >= rockMushroom.rollAnimDelay then
				data.animFrame = data.animFrame + 1
				data.animTimer = 0
				if data.animFrame == 6 then	-- startup is done, now resize and let the player roll
					local settings = PlayerSettings.get(p.character, p.powerup)	-- resize the player's hitbox since rock is big
					settings.hitboxWidth = rockMushroom.rockWidth
					settings.hitboxHeight = rockMushroom.rockHeight
					p.speedX = rockMushroom.rollSpeed * p.direction
					data.rollDir = p.direction
					p:mem(0x3C,FIELD_BOOL,true)
					data.startedOnGround = false
						
				end
			end
			
			
			data.animTimer = data.animTimer + 1
			data.rotation = data.rotation + 16 * p.direction
		else
			-- Rolling code
			p:mem(0x3C,FIELD_BOOL,true) -- always sliding
			
			-- no controls
			p.keys.altRun = false
			p.keys.run = false
			p.keys.altJump = false
			if rockMushroom.canCancel < 2 then
				p.keys.down = false
			end
			p.keys.right = false
			p.keys.left = false
			p.keys.up = false
			
			if p.keys.down == KEYS_PRESSED and rockMushroom.canCancel == 2 then
				disableRoll(p,false)
			end
			
			-- speed handling
			if p.speedX == 0 and p:mem(0x48,FIELD_WORD) ~= 0 then
				p.speedX = data.prevSpeed	-- reset the player's speed to the last speed when Redigit is mean
			elseif p.speedX == 0 then	-- if you hit something that rids your speed (not a slope) then stop rolling
				disableRoll(p,true)
			end
			
			local friction = 0.1	-- default friction
			if p:mem(0x0A,FIELD_BOOL) then	-- friction when on ice
				friction = 0.025
				data.snowOpacity = math.min(0.6,data.snowOpacity + 0.01)
			else
				data.snowOpacity = math.max(0,data.snowOpacity - 0.005)
			end
			local additionalSpeed = 0
			if rockMushroom.setSpeed then
				if p.speedX * data.rollDir < rockMushroom.rollSpeed then
					additionalSpeed = rockMushroom.rollAccel
				elseif p.speedX * data.rollDir > rockMushroom.rollSpeed then
					additionalSpeed = -rockMushroom.rollDeccel
				end
			end
			p.speedX = p.speedX + (friction + additionalSpeed) * data.rollDir
			
			-- slope angle
			data.slopeAngle = 0
			for _, b in ipairs(Colliders.getColliding{a = data.slopeCollider, btype = Colliders.BLOCK, filter = blockFilterSlope}) do        -- check what slope the player is on
				if (Block.SLOPE_MAP[b.id]) then
					if Block.config[b.id].floorslope ~= 0 then
						slopeVar = 1 + math.max(0,Block.config[b.id].floorslope)						-- Thanks to KBM-Quine who solved the collider-slope-issue!!
					elseif Block.config[b.id].ceilingslope ~= 0 then
						slopeVar = 3 - math.min(0,Block.config[b.id].ceilingslope)
					end
					data.slopeAngle = b.height / b.width
				end
			end
			
			data.rotation = data.rotation + (math.max(1 , math.abs(p.speedX)) * math.sign(p.speedX)) -- horizontal rotation handling
			
			for c, n in ipairs(Colliders.getColliding{a = data.breakCollider, btype = Colliders.BLOCK, filter = blockFilterSmash}) do		-- A collider that breaks blocks!
				if Block.MEGA_SMASH_MAP[n.id] and n.contentID == 0 then
					n:remove(true)
				end
				n:hit(2)
			end
			
			for c, n in ipairs(Colliders.getColliding{a = data.breakCollider, btype = Colliders.NPC, filter = function(o) if not o.isFriendly and not o.isHidden and NPC.HITTABLE_MAP[o.id] then return true end end}) do
				n:harm(3)
				p:mem(0x140,FIELD_WORD,1)	-- a bit of I frames so the player doesn't get damaged from the npc they hit
				p:mem(0x142,FIELD_BOOL,true)
			end
			if math.sign(p.speedX) ~= data.rollDir then	-- make the character turn around
				data.rollDir = -data.rollDir
				p.direction = data.rollDir
			end
			data.prevSpeed = p.speedX	-- used so the speed can be reset to the previous value when slope jank strikes back
		end
		
		if not canContinueRolling(p) then
			local bump = not data.collisionCheck
			--Misc.dialog("!")
			disableRoll(p,bump)	-- stop rolling, and if the player hit a wall, bump them
		end
	end
end

-- runs when the powerup is active, passes the player
function rockMushroom.onTickEndPowerup(p)
	local data = p.data.rockMushroom
	if data.isRockRolling and data.animFrame >= 6 then
		data.checkCollider.x = p.x + p.width * 0.5 + p.speedX + data.rollDir
		data.checkCollider.y = p.y + p.height * 0.5 - math.max(4,p.speedX * 4 * data.slopeAngle * data.rollDir)
	elseif (not data.isRockRolling) or (data.animFrame < 6) then
		local extraOffset = 0
		if isOnGroundRedigit(p) or (data.animFrame < 6 and data.startedOnGround and p.speedY < -0.1) then
			extraOffset = -64	-- around the height that a speed of -8 gets you
			data.startedOnGround = true
		end
		data.checkCollider.x = p.x + p.width * 0.5 + p.speedX + data.rollDir
		data.checkCollider.y = p.y + p.height * 0.5 - math.max(0,32 * data.slopeAngle * data.rollDir) + extraOffset	-- 64 is around the height that a speed of -8 gets you
	end
	data.breakCollider.x = p.x + p.width * 0.5 + p.speedX
	data.breakCollider.y = p.y + p.height * 0.5 - math.max(0,32 * data.slopeAngle * data.rollDir)
	
	data.slopeCollider.width = 1
	data.slopeCollider.height = 64
	data.slopeCollider.x = p.x + p.width * 0.5 + p.speedX
	data.slopeCollider.y = p.y + p.height
	--data.checkCollider:debug(true)
	--data.breakCollider:debug(true)			-- -200662     200727
	--data.slopeCollider:debug(true)
end

-- runs when the powerup is active, passes the player
function rockMushroom.onDrawPowerup(p)
	local data = p.data.rockMushroom
	local sprite = rockMushroom:getAsset(p.character, rockMushroom.rollSpritesheet[p.character])
	
	if data.isRockRolling and not p:mem(0x142,FIELD_BOOL) then
		p:setFrame(-50)
		
		local spriteWidth = 48
		local spriteHeight = 44
		Graphics.drawBox{
			texture      = sprite,
			sceneCoords  = true,
			x            = p.x + (p.width / 2),
			y            = p.y + (p.height / 2) + 16 * math.abs(data.slopeAngle),
			width        = spriteWidth * 2 * data.rollDir,
			height       = spriteHeight * 2,
			sourceX      = 0,
			sourceY      = spriteHeight * data.animFrame,
			sourceWidth  = spriteWidth,
			sourceHeight = spriteHeight,
			centered     = true,
			priority     = -25,
			color        = Color.white .. 1,
			rotation     = data.rotation,
			shader = (p.hasStarman and starShader) or nil,
			uniforms = (p.hasStarman and {time = lunatime.tick() * 2}) or nil,
		}
		if not p.hasStarman and data.snowOpacity > 0 then	-- draw a snow overlay
			Graphics.drawBox{
				texture      = sprite,
				sceneCoords  = true,
				x            = p.x + (p.width / 2),
				y            = p.y + (p.height / 2) + 16 * math.abs(data.slopeAngle),
				width        = spriteWidth * 2 * data.rollDir,
				height       = spriteHeight * 2,
				sourceX      = 0,
				sourceY      = spriteHeight * data.animFrame,
				sourceWidth  = spriteWidth,
				sourceHeight = spriteHeight,
				centered     = true,
				priority     = -24,
				color        = Color.white .. data.snowOpacity,
				rotation     = data.rotation,
				shader 		 = (not p.hasStarman and maskShader) or nil,
				uniforms 	 = (not p.hasStarman and {time = lunatime.tick() * 2}) or nil,
			}
		end
	end
end

function rockMushroom.onPlayerHarm(event,p)
	if p.data.rockMushroom then
		if p.data.rockMushroom.isRockRolling and rockMushroom.isInvulnerable then
			p:mem(0x140,FIELD_WORD,50)	-- I frames
			disableRoll(p,true)
			event.cancelled = true
		end
	end
end

return rockMushroom