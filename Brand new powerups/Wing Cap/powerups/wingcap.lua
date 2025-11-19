local wingcap = {}
local cp = require("customPowerups")
local easing = require("ext/easing")

wingcap.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
wingcap.basePowerup = PLAYER_FIREFLOWER
wingcap.cheats = {"needawingcap","overtherainbow","sm63pilled"}
wingcap.collectSounds = {
    upgrade = "powerups/sm64_star.wav",
    reserve = 12,
}


wingcap.settings = {
	canSlowFall = true,	-- Allows the player to glide similar to using a raccoon leaf
	temporary = false,	-- If set to true, the powerup will last the duration set below, play music and disappear eventually.
	flightDelay = 64,	-- How many frames should the player have to recover before taking off again?
	duration = 30,	-- How long (in seconds) should the wing cap last for? If set to 0 or lower, it will play the music indefinitely but never disappear
	music = "powerups/powerfulMario.ogg",	-- The music file to play when the powerup is active
}



-- runs when customPowerups is done initializing the library
function wingcap.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	wingcap.spritesheets = {
		wingcap:registerAsset(CHARACTER_MARIO, "mario-wingcap.png"),
		wingcap:registerAsset(CHARACTER_LUIGI, "luigi-wingcap.png"),
		wingcap:registerAsset(CHARACTER_PEACH, "peach-wingcap.png"),
		wingcap:registerAsset(CHARACTER_TOAD,  "toad-wingcap.png"),
		wingcap:registerAsset(CHARACTER_LINK,  "link-wingcap.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	wingcap.iniFiles = {
		wingcap:registerAsset(CHARACTER_MARIO, "mario-wingcap.ini"),
		wingcap:registerAsset(CHARACTER_LUIGI, "luigi-wingcap.ini"),
		wingcap:registerAsset(CHARACTER_PEACH, "peach-wingcap.ini"),
		wingcap:registerAsset(CHARACTER_TOAD,  "toad-wingcap.ini"),
		wingcap:registerAsset(CHARACTER_LINK,  "link-wingcap.ini"),
	}
	
	wingcap.flyingSprites = {
		wingcap:registerAsset(CHARACTER_MARIO, "mario-wingcap_flying.png"),
		wingcap:registerAsset(CHARACTER_LUIGI, "luigi-wingcap_flying.png"),
		wingcap:registerAsset(CHARACTER_PEACH, "peach-wingcap_flying.png"),
		wingcap:registerAsset(CHARACTER_TOAD,  "toad-wingcap_flying.png"),
		wingcap:registerAsset(CHARACTER_LINK,  "link-wingcap_flying.png"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the wingcap powerup
	wingcap.gpImages = {
		wingcap:registerAsset(CHARACTER_MARIO, "wingcap-groundPound-1.png"),
		wingcap:registerAsset(CHARACTER_LUIGI, "wingcap-groundPound-2.png"),
	}
	--]]
end

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function isOnGround(p)
    return (
        p:isOnGround(p)
        or (p.mount == MOUNT_BOOT and p:mem(0x10C,FIELD_BOOL)) -- Hopping in boot
        or p:mem(0x40,FIELD_WORD) > 0                               -- Climbing
        or p.mount == MOUNT_CLOWNCAR
    )
end

local function canTakeOff(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p.isDucking or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function forceLanding(p)
	return (
		p.forcedState ~= 0
		or p.deathTimer ~= 0
		or p.climbing
		or p.mount ~= 0
		or p.holdingNPC
		or p.inLaunchBarrel
		or p.inClearPipe
		or p:isUnderwater()
		or p:mem(0x4A,FIELD_BOOL)
		or p:mem(0x0C, FIELD_BOOL)
		or (aw and aw.isWallSliding(p) ~= 0)
		or (GP and GP.isPounding(p))
		or p:mem(0x148, FIELD_WORD) == 2
		or p:mem(0x14C, FIELD_WORD) == 2
		or Level.endState() ~= 0
	)
end

local function canGlide(p)
	return (
	wingcap.settings.canSlowFall
	and not p.data.wingcap.isFlying
	and not p:isUnderwater()
	and p.speedY > 0
	and p:mem(0x1C, FIELD_WORD) == 0
	and p.forcedState == 0
    and p.deathTimer == 0 -- not dead
	and not isOnGround(p)
	and not p.climbing
	and not p.inLaunchBarrel
	and not p.inClearPipe
	and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
	and (not p.isDucking or linkChars[p.character]) -- ducking and is not link/snake/samus
	and not p:mem(0x3C,FIELD_BOOL) -- sliding
	and not p:mem(0x44,FIELD_BOOL) -- shell surfing
	and not p:mem(0x4A,FIELD_BOOL) -- statue
	and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
	and not p:mem(0x0C, FIELD_BOOL) -- fairy
	and (not GP or not GP.isPounding(p))
	and (not aw or aw.isWallSliding(p) == 0)
	)
end

local goalTape = require("npcs/AI/goalTape")

local function getPriority(p)
        local priority
        local info = goalTape.playerInfo[p.idx]

        if info and info.darkness > 0 then
          	priority = (info.pausesGame and 0.5) or -6
        elseif p.forcedState == 3 then
            	priority = -70	
	else
		priority = -25
        end

	return priority
end

function wingcap.onInitAPI()
	-- register your events here!
	--registerEvent(wingcap,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function wingcap.onEnable(p)	
	p.data.wingcap = {
		lastDirection = p.direction * -1,
		isFlying = false,
		lockXSpeed = 0,
		currentSpeed = lockXSpeed,
		lockXSpeedDirection = p.direction,
		gradualSlowDown = 1,
		aboutToEnd = false,
		endTimer = 0,
		endFrames = 2,
		vanishcapPowerupstartMusic = true,
		down = 0.0125,
		upBoostTimer = nil,
		upSpeed = 0,
		upSpeedActual = 0,
		resetFlight = nil,
		flightDelay = wingcap.settings.flightDelay,
		slow = 0,
		currentSlow = 0,
		speedDown = 0,
		reduce = 0,
		capTimer = 80,
		currentSpeedY = 0,
		canTurn = false
	}
	p:mem(0x162, FIELD_WORD,5) -- prevents link from accidentally shooting a base projectile when getting the powerup via a sword
end

-- runs once when the powerup gets deactivated, passes the player
function wingcap.onDisable(p)	
	p.data.wingcap = nil
end

-- runs when the powerup is active, passes the player
function wingcap.onTickPowerup(p) 
	if not p.data.wingcap then return end
	local data = p.data.wingcap
	
	if p.character ~= CHARACTER_LINK then
		p:mem(0x160, FIELD_WORD, 2)
	elseif p.mount < 2 then
		p:mem(0x162, FIELD_WORD, 2)
	end
	
	data.capTimer = data.capTimer + 1
	
	--Optional code to make the wingcap temporary
	if wingcap.settings.temporary then
		data.endTimer = data.endTimer + 1
		
		if data.endTimer == 1 and data.vanishcapPowerupstartMusic then
			Audio.SeizeStream(-1)
			Audio.MusicStopFadeOut(300)
			data.vanishcapPowerupstartMusic = false
		elseif data.endTimer == 30 then
			Audio.MusicOpen(wingcap.settings.music)
			Audio.MusicPlay()
		elseif data.endTimer == (lunatime.toTicks(wingcap.settings.duration) - 100) then
			if wingcap.settings.duration > 0 then
				Audio.MusicStopFadeOut(1000)
				data.aboutToEnd = true
			end
		elseif data.endTimer >= lunatime.toTicks(wingcap.settings.duration) then
			if wingcap.settings.duration > 0 then
				Audio.resetMciSections()
				Audio.MusicStopFadeOut(1000)
				p.data.wingcap = nil
				cp.setPowerup(2, p, true)
				return
			end
		end
		
	end
	
	--Take off if able to
	if not isOnGround(p) and canTakeOff(p) and not data.isFlying and p.keys.altRun == KEYS_PRESSED and data.capTimer >= 80 then
		if p.character == CHARACTER_LINK then p:mem(0x160, FIELD_WORD, 2) end
		data.isFlying = true
		data.currentSpeed = p.speedX
		if data.currentSpeed == 0 then data.currentSpeed = 0.1 * p.direction end
		data.lockXSpeed = 0
		data.upBoostTimer = nil
		data.resetFlight = nil
		data.upSpeedActual = 0
		if p.speedX ~= 0 then data.gradualSlowDown = math.abs(data.currentSpeed) end
		data.flightDelay = wingcap.settings.flightDelay
		data.slow = 0
		data.speedDown = 0
		data.reduce = 0
		data.capTimer = 0
		data.canTurn = false
	end
	
	p:mem(0x164, FIELD_WORD, 0)
	
	if isOnGround(p) or forceLanding(p) then data.capTimer = 80 end
	
	if data.isFlying then
		p.keys.run = KEYS_UP
		p:mem(0x164, FIELD_WORD, -1)
		p:mem(0x1C, FIELD_WORD, 0)
		
		--End the flight when the player lands
		if p:mem(0x14A, FIELD_WORD) ~= 2 then
			if isOnGround(p) or forceLanding(p) then
				data.isFlying = false
				data.capTimer = 80
			end
		end
		
		--Optionally, choose when to stop flying
		if (p.keys.altRun == KEYS_PRESSED and p.data.wingcap.capTimer >= 16) then
			data.isFlying = false
			data.capTimer = 0
		end
		
		--Movement logic
		data.down = 0.0125
		
		if p.keys.down == KEYS_DOWN then
			data.down = 0.2
		end
		
		data.flightDelay = data.flightDelay + 1
	
		p.speedY = math.clamp(p.speedY / data.gradualSlowDown, -12, 16)
		
		if p.speedY > 0 and not data.upBoostTimer and not data.resetFlight and data.flightDelay >= wingcap.settings.flightDelay then
			data.upSpeedActual = 0
			data.upSpeed = -math.abs(p.speedY / 1.5)
			if p.keys.up == KEYS_PRESSED and math.abs(p.speedX) > 3 then
				data.upBoostTimer = 0
				data.gradualSlowDown = 1
				data.resetFlight = true
				data.flightDelay = 0
				data.currentSlow = data.slow
				if data.upSpeed <= -6 and math.abs(p.speedX) >= 4 then SFX.play("powerups/wingcapWhoosh.wav") end
				data.reduce = data.reduce + (data.upSpeed * 0.05)
				data.currentSpeedY = p.speedY
			end
		end
		data.slow = math.clamp(data.slow + 0.02, 0, 9)
		--Speed up the player if falling
		if p.speedY >= 7 then
			data.speedDown = math.clamp(data.speedDown + 0.2, 0, 8)
			data.slow = data.slow - (p.speedY * 0.002)
		end
		
		if data.upBoostTimer then
		
			data.upBoostTimer = data.upBoostTimer + 1
			data.canTurn = true
			p.speedY = easing.inOutQuart(math.clamp(data.upBoostTimer, 0, 40), data.currentSpeedY / (math.clamp(3 + (data.currentSpeedY * 0.0625), 0, 3)), ((data.upSpeed * 0.6) - math.abs(p.speedX + 0.3 / 2)) + data.reduce + (7 - math.abs(data.upSpeed)), 40)
			data.slow = easing.linear(math.clamp(data.upBoostTimer, 0, 40), data.currentSlow, data.currentSlow - 1, 40)
			data.speedDown = math.clamp(data.speedDown - 0.025, 0, 5)
			if data.upBoostTimer >= 40 then
				data.upSpeedActual = 0
				data.upBoostTimer = nil
			end
			
			if data.upSpeed <= -6 and math.abs(p.speedX) >= 4 then
				if RNG.randomInt(1, 8) == 1 then
					local e = Effect.spawn(250, p.x + RNG.randomInt(0, p.width), p.y + RNG.randomInt(0, p.height))
					e.speedX = -p.speedX
					e.speedY = -p.speedY
					e.x = e.x - e.width * 0.5
					e.y = e.y - e.height * 0.5
				end
			end
			
		end
		
		if p.speedY < 0 and data.canTurn then
			--Turn around in midair
			if p.keys.altJump == KEYS_PRESSED then
				data.currentSpeed = -data.currentSpeed
				p.speedX = -p.speedX
				data.upBoostTimer = nil
				data.upSpeedActual = 0
				data.reduce = 0
				data.slow = data.slow - 1.5
				data.canTurn = false
			end
		end
		
		if p.speedY > 0 and data.resetFlight and not data.upBoostTimer then
			data.gradualSlowDown = ((-data.upSpeed) * 0.08) + 1
			data.reduce = data.reduce + 1
			data.resetFlight = nil
		end
		
		--Gradually slow down until you fall out of the sky
		data.gradualSlowDown = math.clamp(data.gradualSlowDown - data.down, 1, 2)
		
		p.speedX = math.clamp((data.currentSpeed - (2 * math.sign(data.currentSpeed))) + (math.abs(data.speedDown * 0.95) * math.sign(data.currentSpeed)) + data.lockXSpeed - (math.abs(data.slow / 1.5) * math.sign(data.currentSpeed)), -500 * (1 + math.sign(-data.currentSpeed)), 500 * (1 - math.sign(-data.currentSpeed)))
		
		--Control the player's X-Speed a bit with the left and right keys
		if p.keys.left == KEYS_DOWN then
			data.lockXSpeed = math.clamp(data.lockXSpeed - 0.125, -2.25, 2.25)
			data.lockXSpeedDirection = -1
		elseif p.keys.right == KEYS_DOWN then
			data.lockXSpeed = math.clamp(data.lockXSpeed + 0.125, -2.25, 2.25)
			data.lockXSpeedDirection = 1
		else
			--If nothing's pressed, gradually return to the original set speed
			if math.abs(data.lockXSpeed) <= 1 then
				data.lockXSpeed = 0
			else
				data.lockXSpeed = data.lockXSpeed - 0.125 * data.lockXSpeedDirection
			end
		end
	end
end

function wingcap.onTickEndPowerup(p)
	if not p.data.wingcap then return end
	local data = p.data.wingcap
	
	if not p.isSpinJumping then
		data.lastDirection = p.direction * -1
	end
	
	p:mem(0x54,FIELD_WORD,data.lastDirection) -- prevents a base powerup's projectile from shooting while spinjumping
	
	--Glide like a raccoon
	if canGlide(p) and (p.keys.jump == KEYS_DOWN or p.keys.altJump == KEYS_DOWN) then
		p.speedY = p.speedY * 0.75
		
		if RNG.randomInt(1, 8) == 1 then
			local e = Effect.spawn(80, p.x + RNG.randomInt(0, p.width), p.y + RNG.randomInt(0, p.height))
			e.speedX = RNG.random(1, 2) * -p.direction
			e.speedY = RNG.random(-2, 2)
			e.x = e.x - e.width * 0.5
			e.y = e.y - e.height * 0.5
        end
		
		if not p.isSpinJumping then
			if lunatime.tick() % 11 <= 5 then
				p:setFrame(14)
			else
				if p.character ~= CHARACTER_LINK then p:setFrame(5) end
			end
		end
	end
	
	--Hide the player if currently flying
	if data.isFlying then
		p:setFrame(50)
	end
	
	--Flash the player's frames when about to end
	if data.aboutToEnd then
		data.endFrames = 3
		if lunatime.tick() % 7 <= 3 then
			p:setFrame(50)
		end
	else
		data.endFrames = 2
	end
end

function wingcap.onDrawPowerup(p)
	if not p.data.wingcap then return end
	local data = p.data.wingcap
	
	if not data.isFlying then return end
	
	local flyingTexture = wingcap:getAsset(p.character, wingcap.flyingSprites[p.character])

	Graphics.drawBox{
		texture = flyingTexture,
		x = p.x + p.width/2,
		y = p.y + p.height/2,
		width = flyingTexture.width * math.sign(data.currentSpeed),
		height = flyingTexture.height / 3,
		sourceX = 0,
		sourceY = (math.floor(lunatime.tick() / (12 / data.endFrames)) % data.endFrames * flyingTexture.height / 3),
		sourceWidth = flyingTexture.width,
		sourceHeight = flyingTexture.height / 3,
		sceneCoords = true,
		centered = true,
		priority = getPriority(p),
		rotation = (p.speedY * 4) * math.sign(data.currentSpeed),
	}
end

-- handles drawing the powerup when the player is in the overworld
function wingcap.onDrawPowerupOverworld(p)
	-- put your own code here!
end

return wingcap