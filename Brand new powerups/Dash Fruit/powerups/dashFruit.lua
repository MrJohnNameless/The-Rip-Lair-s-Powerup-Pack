
--[[
	Dash Fruit by Deltomx3
				
	A power-up based off Celeste that lets the player dash mid-air and wall-climb
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrDoubleA - borrowed direction code from the Madeline playable
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local dashFruit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

dashFruit.forcedStateType = 2 -- 0 for instant, 2 for normal/flickering, 3 for poof/raccoon
dashFruit.basePowerup = PLAYER_FIREFLOWER
dashFruit.cheats = {"needadashfruit", "transrights", "itsameceleste", "takeahike", "thisisntcanonisit"}
dashFruit.settings = {
	--For settings like cooldown or stamina, the default FPS in SMBX is 64/65
	dashSpeed = 12, --How fast the dash is (12 by default)
	cooldown = 1, --How long the dash cooldown is in frames (1  by default)
	dashes = 1, --The default amount of available dashes the player has (1 by default)
	freezeTime = 3, --How long the freeze frame when dashing is (3 by default)
	dashSound = "powerups/dashFruit-dash.ogg", --The sound when the dash is used
	dashSound2 = "powerups/dashFruit-dash2.ogg", --The sound when the 2nd (or more) dash is used
	dashVisual = false, --If text shows up above the player with how many dashes they have left (false by default)
	
	canClimb = true, --If you can climb up walls (true by default)
	stamina = 192, --How much stamina you have when climbing up walls in frames (192 by default)
	
	disableScreenShake = false, --Disables the screen shake (false by default)
}

-- runs when customPowerups is done initializing the library
function dashFruit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	dashFruit.spritesheets = {
		dashFruit:registerAsset(CHARACTER_MARIO, "mario-dashFruit.png"),
		dashFruit:registerAsset(CHARACTER_LUIGI, "luigi-dashFruit.png"),
		dashFruit:registerAsset(CHARACTER_PEACH, "peach-dashFruit.png"),
		dashFruit:registerAsset(CHARACTER_TOAD,  "toad-dashFruit.png"),
		dashFruit:registerAsset(CHARACTER_LINK,  "link-dashFruit.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	dashFruit.iniFiles = {
		dashFruit:registerAsset(CHARACTER_MARIO, "mario-dashFruit.ini"),
		dashFruit:registerAsset(CHARACTER_LUIGI, "luigi-dashFruit.ini"),
		dashFruit:registerAsset(CHARACTER_PEACH, "peach-dashFruit.ini"),
		dashFruit:registerAsset(CHARACTER_TOAD,  "toad-dashFruit.ini"),
		dashFruit:registerAsset(CHARACTER_LINK,  "link-dashFruit.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the dashFruit powerup
	dashFruit.gpImages = {
		dashFruit:registerAsset(CHARACTER_MARIO, "dashFruit-groundPound-1.ini"),
		dashFruit:registerAsset(CHARACTER_LUIGI, "dashFruit-groundPound-2.ini"),
	}
	--]]
end


-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- The IDs of any spring-like NPCs/Blocks. Feel free to add any custom springs you have in your level.
local springNPCs = {26, 455, 457, 458} --All basegame springs
local springBlocks = {55} --Just the SMB3 Noteblock

local springLib = require("npcs/ai/springs")

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function unOccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and not p:mem(0x50,FIELD_BOOL) -- not spinjumping
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        -- and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function isOnGroundRedigit() -- isOnGround, but the redigit way. (perhaps surprisingly) is sometimes more reliable than :isOnGround()
    return (
        player.speedY == 0 -- """on a block"""
        or player:mem(0x48,FIELD_WORD) > 0 -- on a slope
        or player:mem(0x176,FIELD_WORD) > 0 -- on an NPC
    )
end

local function isTouchingWall(p)
	local data = p.data.dashFruit
	local touched = false
	local offset = 0
	if p.direction == -1 then
		offset = offset - 1
	else
		offset = offset + 1
	end
	for i,b in Block.iterateIntersecting((p.x + offset),p.y,(p.x + p.width + offset),p.y + p.height) do
		if not b.isHidden and Block.SOLID_MAP[b.id] and not Block.SLOPE_MAP[b.id] and not Block.SEMISOLID_MAP[b.id]
		and not Block.LAVA_MAP[b.id] and not Block.PLAYER_MAP[b.id] then
			data.climbingOn = b
			touched = true
			break
		end
	end
	return touched
end

local function canClimb(p)
	return (
		dashFruit.settings.canClimb
		and unOccupied(p)
		and isTouchingWall(p)
		and (p:mem(0x11C, FIELD_WORD) <= 0 or p.speedY > 0)
		and not p:mem(0x36,FIELD_BOOL) -- not underwater
		-- and not p:mem(0x12E,FIELD_BOOL)
		and (p:mem(0x48,FIELD_WORD) ~= 0 or not isOnGroundRedigit(p))
	)
end

local function resetDash(p)
	local data = p.data
	data.dashTimer = 0
	data.canDash = true
	data.dashing = false
	data.cooldown = 0
	data.dashAmount = 1
	data.dashSpeed = vector(0, 0)
end

function dashFruit.onInitAPI()
	-- register your events here!
	--registerEvent(dashFruit,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function dashFruit.onEnable(p)	
	p.data.dashFruit = {
		--dash related
		dashDirection = vector.zero2,
		dashTimer = 0,
		canDash = true,
		dashing = false,
		baseRunSpeed = Defines.player_runspeed,
		timerThingy = 0,
		cooldown = 0,
		dashAmount = 1,
		dashSpeed,
		dashUsedUp = 0,
		lastDashAmount = dashFruit.settings.dashes,
		moreThanOneDash = false,
		
		--climb related
		climbing = false,
		climbingOn,
		climbStamina = dashFruit.settings.stamina,
		
		--unrelated
		candoFX = false,
		freezeTimer = 0,
		springCheckCollider = Colliders.Box(p.x, p.y, p.width + 32, p.height + 16),
	}
	-- p.data.dashFruit.springCheckCollider:Debug(true)
end

-- runs once when the powerup gets deactivated, passes the player
function dashFruit.onDisable(p)	
	if p.data.dashFruit.freezeTimer > 0 then
		Misc.unpause()
	end
	resetDash(p)
	
	p.data.dashFruit = nil
end

--borrowed from MDA's Madeline playable
local function getDirection()
	local direction = vector.zero2

	if player.keys.left then
		direction.x = -1
	elseif player.keys.right then
		direction.x = 1
	end

	if player.keys.up then
		direction.y = -1
	elseif player.keys.down then
		direction.y = 1
	end

	if direction == vector.zero2 then -- If still 0, set to the current direction
		direction.x = player.direction
	end

	direction = direction:normalise()

	return direction
end

function dashFruit.freezeFrame(p, time)
	local data = p.data.dashFruit
	
	data.freezeTimer = time
	Misc.pause(true)
end

function dashFruit.spawnSparkles1(p)
	local e = Effect.spawn(80, p.x, p.y)
	e.x = p.x + (p.width / 2) - (e.width / 2)
	e.y = p.y + (p.height / 2) - (e.height / 2)
	e.speedX = -1.5
	e.speedY = -1.5
	
	local e2 = Effect.spawn(80, p.x, p.y)
	e2.x = p.x + (p.width / 2) - (e2.width / 2)
	e2.y = p.y + (p.height / 2) - (e2.height / 2)
	e2.speedX = 1.5
	e2.speedY = -1.5
	
	local e3 = Effect.spawn(80, p.x, p.y)
	e3.x = p.x + (p.width / 2) - (e3.width / 2)
	e3.y = p.y + (p.height / 2) - (e3.height / 2)
	e3.speedX = 1.5
	e3.speedY = 1.5
	
	local e4 = Effect.spawn(80, p.x, p.y)
	e4.x = p.x + (p.width / 2) - (e4.width / 2)
	e4.y = p.y + (p.height / 2) - (e4.height / 2)
	e4.speedX = -1.5
	e4.speedY = 1.5
end

function dashFruit.spawnSparkles2(p)
	local e = Effect.spawn(80, p.x, p.y)
	e.x = p.x + (p.width / 2) - (e.width / 2)
	e.y = p.y + (p.height / 2) - (e.height / 2)
	e.speedX = -2
	
	local e2 = Effect.spawn(80, p.x, p.y)
	e2.x = p.x + (p.width / 2) - (e2.width / 2)
	e2.y = p.y + (p.height / 2) - (e2.height / 2)
	e2.speedY = -2
	
	local e3 = Effect.spawn(80, p.x, p.y)
	e3.x = p.x + (p.width / 2) - (e3.width / 2)
	e3.y = p.y + (p.height / 2) - (e3.height / 2)
	e3.speedX = 2
	
	local e4 = Effect.spawn(80, p.x, p.y)
	e4.x = p.x + (p.width / 2) - (e4.width / 2)
	e4.y = p.y + (p.height / 2) - (e4.height / 2)
	e4.speedY = 2
end

local function spawnSparkleTrail(p)
	local e = Effect.spawn(74, p.x, p.y)
	e.x = p.x + (p.width / 2) - (e.width / 2) + RNG.random(-8, 8)
	e.y = p.y + (p.height / 2) - (e.height / 2) + RNG.random(-8, 8)
	e.speedX = (-p.speedX / 4)
	e.speedY = (-p.speedY / 4)
end

local function spawnDust(p)
	local e = Effect.spawn(74, p.x, p.y)
	e.x = p.x + (p.width / 2) - (e.width / 2) + (16 * p.direction) + RNG.random(-4, 4)
	e.y = p.y + (p.height / 2) - (e.height / 2) + RNG.random(-16, 16)
end

local function spawnDashlessDust(p)
	-- local e = Effect.spawn(74, p.x, p.y)
	-- e.x = p.x + (p.width / 2) - (e.width / 2) + RNG.random(-16, 16)
	-- e.y = p.y + (p.height / 2) - (e.height / 2) + RNG.random(-16, 16) - 16
	-- e.speedY = RNG.random(-1, -3)
	
	local e2 = Effect.spawn(80, p.x, p.y)
	e2.x = p.x + (p.width / 2) - (e2.width / 2) + RNG.random(-16, 16)
	e2.y = p.y + (p.height / 2) - (e2.height / 2) + RNG.random(-16, 16) - 16
	e2.speedY = RNG.random(-0.1, -1)
end

-- runs when the powerup is active, passes the player
function dashFruit.onTickPowerup(p) 
	if not p.data.dashFruit then return end -- check if the powerup is currenly active
	local data = p.data.dashFruit
	
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end
	
	if p.keys.altRun == KEYS_PRESSED and data.canDash and data.cooldown == 0 and not data.climbing then
		data.dashTimer = 1
		data.timerThingy = 0
		data.canDash = false
		data.dashing = true
		p:mem(0x120, FIELD_BOOL, false)
		p:mem(0x11C, FIELD_WORD, 0)
		data.cooldown = dashFruit.settings.cooldown
		
		local poof = Effect.spawn(131, p.x, p.y)
		poof.x = p.x + (p.width / 2) - (poof.width / 2)
		poof.y = p.y + (p.height / 2) - (poof.height / 2)
		dashFruit.spawnSparkles1(p)
		dashFruit.spawnSparkles2(p)
		
		dashFruit.freezeFrame(p, dashFruit.settings.freezeTime)
	end
	
	if isOnGroundRedigit() and not data.dashing then
		data.canDash = true
		data.dashing = false
		data.dashTimer = 0
		if data.moreThanOneDash then
			data.dashAmount = data.lastDashAmount
		else
			data.dashAmount = dashFruit.settings.dashes
		end
		data.dashUsedUp = 0
		data.timerThingy = 0
		data.climbing = false
		data.climbStamina = dashFruit.settings.stamina
	end
	
	if data.cooldown == 0 and data.candoFX then
		data.candoFX = false
		dashFruit.spawnSparkles1(p)
	end
	
	data.springCheckCollider.x = (p.x - 16 - p.width * 0.5) + (p.speedX * 2)
	data.springCheckCollider.y = p.y + (p.speedY * 2)
	
	-- DASH STUFF --
	if data.dashing then
		if data.dashTimer > 0 then
			if data.dashDirection ~= vector(0, -1) and not isOnGroundRedigit() then
				p.speedY = p.speedY - Defines.player_grav - 0.00001
			end
		end
		
		if data.dashTimer == 1 then
			if data.dashUsedUp < 1 then
				SFX.play(dashFruit.settings.dashSound, 0.7)
			elseif data.dashUsedUp >= 1 then
				SFX.play(dashFruit.settings.dashSound2, 0.7)
			end
			data.dashDirection = getDirection(p.keys)
			data.dashSpeed = data.dashDirection * dashFruit.settings.dashSpeed	
			Defines.player_runspeed = math.abs(dashFruit.settings.dashSpeed)
			data.dashAmount = data.dashAmount - 1
			data.dashUsedUp = data.dashUsedUp + 1
			
			if data.moreThanOneDash then
				data.moreThanOneDash = false
			end
			
			if not dashFruit.settings.disableScreenShake then
				Defines.earthquake = 4
			end

			if data.dashSpeed.x ~= 0 then
				p.direction = math.sign(data.dashSpeed.x)
			end
			
			if data.dashSpeed.y < 0 then
				p:mem(0x176, FIELD_WORD, 0)
			end
		end
		
		if data.dashTimer < 10 then
			data.dashTimer = data.dashTimer + 1
			spawnSparkleTrail(p)
			p.speedX = data.dashSpeed.x
			p.speedY = data.dashSpeed.y
		else
			data.dashDirection = vector.zero2
			data.dashTimer = 0
			data.dashing = false
			if data.dashAmount == 0 then
				data.canDash = false
			else
				data.canDash = true
				data.cooldown = 0
			end
			p.speedY = p.speedY / 1.2
			p.speedX = p.speedX / 1.2
		end
	else
		data.timerThingy = data.timerThingy + 0.02
		Defines.player_runspeed = math.lerp(Defines.player_runspeed, data.baseRunSpeed, data.timerThingy)
		if data.cooldown > 0 and isOnGroundRedigit(p) then
			data.cooldown = data.cooldown - 1
			data.candoFX = true
		end
	end
	
	if data.dashAmount == 0 then
		if lunatime.tick() % 6 == 0 then
			spawnDashlessDust(p)
		end
		
		--Checking for spring-like NPCs or Blocks
		for _,n in NPC.iterate(springNPCs) do
			if not n.friendly and n.heldIndex == 0 and not n.isHidden then
				if Colliders.collide(data.springCheckCollider, n) then
					if springLib.ids[n.id] == springLib.TYPE.SIDE then
						p.direction = -math.sign(p.x - n.x)
						p.speedX = p.speedX * -math.sign(p.x - n.x)
						SFX.play(24)
					else
						data.dashAmount = dashFruit.settings.dashes
						data.cooldown = 0
						data.candoFX = true
						data.canDash = true
						data.dashUsedUp = 0
					end
				end
			end
		end
		
		for _,b in Block.iterate(springBlocks) do
			if Colliders.collide(data.springCheckCollider, b) then
				data.dashAmount = dashFruit.settings.dashes
				data.cooldown = 0
				data.candoFX = true
				data.canDash = true
				data.dashUsedUp = 0
			end
		end
	end
	
	-- CLIMB STUFF --
	if canClimb(p) and not data.climbing then	
		if p.direction == 1 then
			if p.keys.right == KEYS_DOWN then
				data.climbing = true		
				SFX.play(3)
				p.keys.down = nil
			end
		elseif p.direction == -1 then
			if p.keys.left == KEYS_DOWN then
				data.climbing = true
				SFX.play(3)
				p.keys.down = nil
			end
		end
		
		data.wallDirection = p.direction
	end
	
	if dashFruit.settings.canClimb then
		if data.climbing and canClimb(p) then
			data.dashing = false
			data.dashTimer = 0
			p:mem(0x11C, FIELD_WORD, 0)
			p:mem(0x164, FIELD_WORD, -1)
			Defines.player_grav = 0
			if not data.canDash then
				data.cooldown = dashFruit.settings.cooldown
			end
			
			data.climbStamina = data.climbStamina - 1
			
			if p.keys.up and data.climbStamina > 0 then
				p.speedY = math.min(p.speedY - (Defines.player_grav - 0.5), (-2 + (data.climbingOn.speedY)))
				if lunatime.tick() % 10 == 0 then
					SFX.play(71)
				end
			elseif p.keys.down and data.climbStamina > 0 then
				p.speedY = math.min(p.speedY - (Defines.player_grav - 0.5), ((data.climbingOn.speedY)) + 2)
				if lunatime.tick() % 10 == 0 then
					SFX.play(71)
				end
			else
				if data.climbStamina > 0 then
					p.speedY = -0.00000000000000001 + data.climbingOn.speedY
				elseif data.climbStamina <= 0 then
					p.speedY = p.speedY + 0.2
					if lunatime.tick() % 3 == 0 then
						spawnDust(p)
					end
				end
			end
			
			p.keys.right = false
			p.keys.left = false
			
			if p.keys.jump == KEYS_PRESSED then
				SFX.play(1)
				SFX.play(2)
				local e = Effect.spawn(75, p.x, p.y)
				e.x = p.x + (p.width / 2) - (e.width / 2)
				e.y = p.y + (p.height / 2)
				p.speedX = -5 * data.wallDirection + (data.climbingOn.speedX * 1.5)
				p.speedY = -9 + (data.climbingOn.speedY * 1.5)
				data.climbing = false
				p.direction = -data.wallDirection
			end
		else
			Defines.player_grav = 0.4
			if p:mem(0x164, FIELD_WORD) == -1 then
				p:mem(0x164, FIELD_WORD, 0)
			end
		end
	
		if not isTouchingWall(p) then
			data.climbing = false
		end
	end
end

function dashFruit.onTickEndPowerup(p)
	if not p.data.dashFruit then return end -- check if the powerup is currently active
	local data = p.data.dashFruit


    if data.climbing then
        if (p.keys.up or p.keys.down) and data.climbStamina > 0 then
			if lunatime.tick() % 19 < 10 then
				p:setFrame(32)
			elseif lunatime.tick() % 19 < 20 then
				p:setFrame(33)
			end
		else
			if data.climbStamina > 0 then
				p:setFrame(32)
			else
				p:setFrame(34)
			end
		end
    end
end

function dashFruit.onDrawPowerup(p)
	if not p.data.dashFruit then return end -- check if the powerup is currently active
	local data = p.data.dashFruit
	
	if dashFruit.settings.dashVisual then
		Text.print(data.dashAmount, p.x - camera.x - 16, p.y - camera.y - 16)
	end
	
	-- debug
	-- Text.print(data.dashUsedUp, 10, 10)
	-- Text.print("cd: "..data.cooldown, 10, 60)
	-- Text.print("dir: "..data.dashDirection, 10, 110)
	
    if data.freezeTimer > 0 and Misc.isPausedByLua() then
        data.freezeTimer = data.freezeTimer - 1

        if data.freezeTimer <= 0 then
            Misc.unpause()
        end
    end
end

return dashFruit