
--[[
		Fog Dandelion by John Nameless & Sleepy
				
			An original customPowerups script that 
		allows the player to teleport to a destination 
				chosen by a movable cursor
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
						 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	Sleepy - Made the powerup npc sprites, dandelion particle sprites, & the player sprites for Mario. 
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local particles = require("particles")
local pm = require("playerManager")
local fog = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

fog.projectileID = 13
fog.forcedStateType = 2 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
fog.basePowerup = PLAYER_FIREFLOWER
fog.cheats = {"needadandelion","needafogdandelion","thefogiscoming","iloveeatingfog","teleportbread","mistme","blinkandyoullmissit"}
fog.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

fog.settings = {
	cursorIMG = Graphics.loadImageResolved("powerups/fog_dandelion_cursor.png"), -- what's the image used for the cursor for teleporting?
	cursorInvalidSpotIMG = Graphics.loadImageResolved("background/background-199e.png"), -- what's the image used for indicating that a teleport spot is invalid?
	cursorDistanceMarkerIMG = Graphics.sprites.hardcoded["33-1"].img, -- what's the image used for marking the line between the player & a teleport spot?
	maxTeleportDistance = 400, -- what's the max horizontal & vertical distance can a teleport spot be away from the player? (400 by default)
	teleportAcceleration = 0.2, -- how fast does the player speed up towards their teleport spot upon teleporting (0.2 by default)
	antiTeleportZoneID = 949,	-- what's the block id for the anti-teleport zone? (949 by default, but automatically changed by the anti-teleport zone block itself)
}

-- runs when customPowerups is done initializing the library
function fog.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	fog.spritesheets = {
		fog:registerAsset(CHARACTER_MARIO, "mario-fog.png"),
		fog:registerAsset(CHARACTER_LUIGI, "luigi-fog.png"),
		fog:registerAsset(CHARACTER_PEACH, "peach-fog.png"),
		fog:registerAsset(CHARACTER_TOAD,  "toad-fog.png"),
		fog:registerAsset(CHARACTER_LINK,  "link-fog.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	fog.iniFiles = {
		fog:registerAsset(CHARACTER_MARIO, "mario-fog.ini"),
		fog:registerAsset(CHARACTER_LUIGI, "luigi-fog.ini"),
		fog:registerAsset(CHARACTER_PEACH, "peach-fog.ini"),
		fog:registerAsset(CHARACTER_TOAD,  "toad-fog.ini"),
		fog:registerAsset(CHARACTER_LINK,  "link-fog.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	fog.gpImages = {
		fog:registerAsset(CHARACTER_MARIO, "template-groundPound-1.png"),
		fog:registerAsset(CHARACTER_LUIGI, "template-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {30, 35, 40, 25, 40}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local STATE_NORMAL	 = 0
local STATE_FLOAT	 = 1
local STATE_TELEPORT = 2

local rectCast = Colliders.Rect(0,0,8,0)

local function isUnoccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount ~= MOUNT_CLOWNCAR
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function isOnGround(p)
	return (
		(p.speedY == 0 and p.forcedState == 0) -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:isClimbing() -- on a vine
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function withinBounds(p,cursor)
	local bounds = p.sectionObj.boundary
	return (
		cursor.x > bounds.left + 2
		and cursor.x + cursor.width < bounds.right - 2
		and cursor.y > bounds.top + 2
		and cursor.y + cursor.height < bounds.bottom
	)
end

local function isValidTeleportSpot(p,cursor,startCoords,targetCoords,distance)
	if (math.abs(distance.x) <= 48 and math.abs(distance.y) <= 48)
	or (math.abs(distance.x) >= fog.settings.maxTeleportDistance or math.abs(distance.y) >= fog.settings.maxTeleportDistance)
	or not withinBounds(p,cursor)
	or #Colliders.getColliding{ -- destination not colliding with any solid block or an anti-teleport zone
			a = cursor,
			b = table.append(Block.SOLID .. Block.PLAYERSOLID .. Block.SIZEABLE), 
			btype = Colliders.BLOCK,
			filter = function(o) return (
					o.isValid
					and not o.isHidden 
					and not Block.SEMISOLID_MAP[o.id] 
					and ((not Block.NONSOLID_MAP[o.id] and not Block.SIZEABLE_MAP[o.id]) or o.id == fog.settings.antiTeleportZoneID)
					) end			
		} > 0
	then
		return false
	end
	
	local targetVec = targetCoords - startCoords  -- direction from start to target point
	targetVec:normalize()
	local finalRotation = math.deg(math.atan2(targetVec.y, targetVec.x))
	
	rectCast.x = startCoords.x - distance.x/2 
	rectCast.y = startCoords.y - distance.y/2 
	rectCast.height = math.sqrt((targetCoords - startCoords).sqrlength) - 32
	rectCast.rotation = (finalRotation + 90)
	
	if #Colliders.getColliding{ -- travel line not colliding with any solid block
			a = rectCast,
			b = table.append(Block.SOLID .. Block.PLAYERSOLID), 
			btype = Colliders.BLOCK,
			filter = function(o) return (
					o.isValid
					and not o.isHidden
					and not Block.SEMISOLID_MAP[o.id] 
					and not Block.SIZEABLE_MAP[o.id]
					and not Block.LAVA_MAP[o.id] 
					and not Block.HURT_MAP[o.id] 
					and not Block.PLAYER_MAP[o.id]
					) end			
		} > 0
	then 
		return false 
	end

	return true
end

local function doPoof(p,playerData)
	if not playerData or not playerData.fogDandelion then return end
	local data = playerData.fogDandelion
	
	data.particle:setParam("xOffset",0)
	data.particle:setParam("yOffset",0)
	data.particle:setParam("accelY",0)
	data.particle:setParam("colTime","{0,1},{0xFFFFFFFF,0x00000000}")
	for i = 1,4 do
		local offset = 0
		local side = math.sign((i % 2) - ((i + 1) % 2))
		local verticalSide = -1
		if i > 2 then
			verticalSide = 1
		end
		
		for count = 1,2 do
			data.particle:setParam("speedX",(0.5 + RNG.random(0,1)) * side)
			data.particle:setParam("speedY",(0.5 + RNG.random(0,1)) * verticalSide)
			data.particle:Emit()
		end
		
		local e = Effect.spawn(10,(p.x + p.width*0.5) + (p.width*0.25*RNG.randomSign()),(p.y + p.height*0.5) + (p.height*0.25*RNG.randomSign()))
		e.x = e.x - e.width*0.5
		e.y = e.y - e.height*0.5
	end
	
	data.particle:setParam("xOffset","-12:12")
	data.particle:setParam("yOffset",data.particle:getParamDefault("yOffset"))
	data.particle:setParam("speedX",data.particle:getParamDefault("speedX"))
	data.particle:setParam("speedY",data.particle:getParamDefault("speedY"))
	data.particle:setParam("accelY","-0.025:-0.075")
	data.particle:setParam("colTime","{0,0.25,1},{0x00000000,0xFFFFFFFF,0x00000000}")
end

-- runs once when the powerup gets activated, passes the player
function fog.onEnable(p)
	p.data.fogDandelion = {
		state = STATE_NORMAL,
		wasGrounded = isOnGround(p),
		wasSpinJumping = p.isSpinJumping,
		teleportCursor = Colliders.Box(p.x,p.y,100,100),
		teleportTimer = 0,
		floatTimer = 0,
		particle = particles.Emitter(0,0, Misc.resolveFile("powerups/fog_dandelion_particle.ini"))
	}
	p.data.fogDandelion.particle:Attach(p)
	p:mem(0x162, FIELD_WORD,5) -- prevents link from accidentally shooting a base projectile when getting the powerup via a sword
end

-- runs once when the powerup gets deactivated, passes the player
function fog.onDisable(p)
	if p.data.fogDandelion and p.data.fogDandelion.state == STATE_TELEPORT then
		p.noblockcollision = false
		p.nonpcinteraction = false
		p.noplayerinteraction = false
		SFX.play(12)
	end
	p.data.fogDandelion = nil
end

-- runs when the powerup is active, passes the player
function fog.onTickPowerup(p) 
	if not p.data.fogDandelion then return end
	local data = p.data.fogDandelion
	
	if not isUnoccupied(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then 
		data.state = STATE_NORMAL
		data.floatTimer = 0
		return 
	end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,5)
	elseif p.mount ~= MOUNT_YOSHI or data.state ~= STATE_NORMAL then
		p:mem(0x160, FIELD_WORD,5)
	end
	
	if data.state == STATE_NORMAL and data.wasGrounded and p.keys.altRun == KEYS_PRESSED then
		p.speedX = p.speedX*0.5
		p:mem(0x11C,FIELD_WORD,0)
		p:mem(0x160, FIELD_WORD,10)
		Routine.run(function()
			data.wasSpinJumping = p.isSpinJumping
			p.isSpinJumping = false
			p.keys.down = KEYS_UP
			p:mem(0x12E,FIELD_BOOL,false)
			Routine.skip()
			data.teleportCursor.x = p.x + p.speedX
			data.teleportCursor.y = p.y + p.speedY
			data.teleportCursor.width = p.width
			data.teleportCursor.height = p.height
			data.wasGrounded = false
			data.state = STATE_FLOAT
			p.keys.down = KEYS_UP
			SFX.play(26)
		end)

	elseif data.state == STATE_NORMAL then
		if isOnGround(p) or p:mem(0x11C,FIELD_WORD) > 0 then
			data.wasGrounded = true
			data.floatTimer = 0
		end
		return
	end
	
	local playerCenter = vector(p.x + p.width*0.5,p.y + p.height*0.5)
	local cursorCenter = vector(data.teleportCursor.x + data.teleportCursor.width*0.5,data.teleportCursor.y + data.teleportCursor.height*0.5)
	
	local distance = vector(
		playerCenter.x - cursorCenter.x,
		playerCenter.y - cursorCenter.y
	)
	
	if data.state == STATE_FLOAT then
		p.speedX = p.speedX * 0.9
		
		local player_grav = Defines.player_grav
		local baseID = pm.getBaseID(p.character)
		
		if baseID == CHARACTER_LUIGI then
			player_grav = player_grav * 0.9
		end
		
		if not isOnGround(p) then
			if data.floatTimer <= 120 then
				p.speedY = math.clamp(p.speedY,-Defines.jumpheight,-player_grav + 0.1)
			elseif p.speedY > player_grav then
				p.speedY = p.speedY - (player_grav - 0.05)
			end
		end
		
		data.floatTimer = data.floatTimer + 1
		
		if p.mount == MOUNT_NONE then
			local finalFrame = 44
			if baseID > 2 then finalFrame = 6 end -- use a different frame if not a plumber character
			p:setFrame(finalFrame)
		end
		
		local hadMovedCursor = false
		if p.keys.left then
			data.teleportCursor.x = data.teleportCursor.x - 4
			hadMovedCursor = true
		elseif p.keys.right then
			data.teleportCursor.x = data.teleportCursor.x + 4
			hadMovedCursor = true
		else 
			data.teleportCursor.x = data.teleportCursor.x + p.speedX
		end
		if p.keys.up then
			data.teleportCursor.y = data.teleportCursor.y - 4
			hadMovedCursor = true
		elseif p.keys.down then
			data.teleportCursor.y = data.teleportCursor.y + 4
			hadMovedCursor = true
		end	
	
		if hadMovedCursor and data.floatTimer % 8 == 0 then	
			SFX.play(74)
		end
	
		if cursorCenter.x < playerCenter.x then
			p.direction = -1
		elseif cursorCenter.x > playerCenter.x then
			p.direction = 1
		end
		
		if not p.keys.altRun then
			if isValidTeleportSpot(p,data.teleportCursor,playerCenter,cursorCenter,distance) then
				data.state = STATE_TELEPORT
				data.teleportTimer = 0
				data.floatTimer = 0
				p.speedX = 0
				p.speedY = 0
				p.noblockcollision = true
				p.nonpcinteraction = true
				p.noplayerinteraction = true
				SFX.play(82)
				SFX.play(66)
				doPoof(p,p.data)
			else
				data.state = STATE_NORMAL
				data.wasGrounded = true
			end
		end
	end
	
	if data.state == STATE_TELEPORT then
		local v = data.teleportCursor
		local vec = vector(playerCenter.x - cursorCenter.x, playerCenter.y - cursorCenter.y):normalize() -- does the rotation for facing the player (from MegaDood orignally) 
		local rotation = math.deg(math.atan2(-vec.y, -vec.x)) -- sets the final angle for the cane to rotate to 
		
		local shootForce = vector.right2:rotate(rotation)
		local speed = math.min(data.teleportTimer * 0.25,8)
		p.speedX = shootForce.x * speed
		p.speedY = shootForce.y * speed
		p.invincibilityTimer = math.max(p.invincibilityTimer,2)
		
		if data.teleportTimer % 6 == 0 then
			local e = Effect.spawn(10,playerCenter.x,playerCenter.y)
			e.x = e.x - e.width*0.5
			e.y = e.y - e.height*0.5
		end
		
		if math.abs(distance.x) <= 10 and math.abs(distance.y) <= 10 then
			data.state = STATE_NORMAL
			data.teleportTimer = 0
			p:teleport(v.x,v.y)
			p.isSpinJumping = data.wasSpinJumping
			p.noblockcollision = false
			p.nonpcinteraction = false
			p.noplayerinteraction = false
			SFX.play(82)
			--SFX.play(66)
			doPoof(p,p.data)
			return
		end
		data.teleportTimer = data.teleportTimer + 1
		
	end
	
	p.keys.left,p.keys.right,p.keys.down,p.keys.jump,p.keys.altJump,p.keys.run,p.keys.altRun = KEYS_UP
end

function fog.onDrawPowerup(p)
	if not p.data.fogDandelion then return end
	local data = p.data.fogDandelion
	
	if not Misc.isPaused() and lunatime.tick() % 48 == 0 and data.state ~= STATE_TELEPORT then
		data.particle:Emit()
	end
	data.particle:Draw(-25 - 0.01)
	
	if data.state == STATE_NORMAL then return end

	if data.state == STATE_TELEPORT then
		if p.mount == MOUNT_YOSHI then
			p:mem(0x72,FIELD_WORD,-1)
			p:mem(0x7A,FIELD_WORD,-1)
		elseif p.mount == MOUNT_BOOT then
			p:mem(0x110,FIELD_WORD,-1)
		end
		p:setFrame(-50 * p.direction)
	elseif data.state == STATE_FLOAT then
		local playerCenter = vector(p.x + p.width*0.5,p.y + p.height*0.5)
		local cursorCenter = vector(data.teleportCursor.x + data.teleportCursor.width*0.5,data.teleportCursor.y + data.teleportCursor.height*0.5)
		
		local distance = vector(
			playerCenter.x - cursorCenter.x,
			playerCenter.y - cursorCenter.y
		)
		if math.abs(distance.x) >= 40 or math.abs(distance.y) >= 40 then
			local img = fog.settings.cursorDistanceMarkerIMG
			for i = 1, 4 do
				Graphics.drawImageToSceneWP(
					img,
					(playerCenter.x - (distance.x * (i * 0.2))) - img.width*0.5,
					(playerCenter.y - (distance.y * (i * 0.2))) - img.height*0.5,
					0.5,
					-25 - 0.01
				)
			end
		end
		
		Graphics.drawImageToSceneWP(
			fog.settings.cursorIMG,
			cursorCenter.x - fog.settings.cursorIMG.width*0.5,
			cursorCenter.y - fog.settings.cursorIMG.height*0.5,
			0.6 + (0.15 * math.sin(lunatime.tick() / 10) * 0.5),
			-25 - 0.01
		)
		
		if not isValidTeleportSpot(p,data.teleportCursor,playerCenter,cursorCenter,distance) then
			Graphics.drawImageToSceneWP(
				fog.settings.cursorInvalidSpotIMG,
				cursorCenter.x - fog.settings.cursorInvalidSpotIMG.width*0.5,
				cursorCenter.y - fog.settings.cursorInvalidSpotIMG.height*0.5,
				-25 - 0.01
			)
		end
	end
end

return fog