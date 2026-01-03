--[[
		Wind Flower by DeviousQuacks23 (v.2.0)
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - Provided the template that I used for this powerup
        Mojang - I took most of the SFX from Minecraft
        Gate - The powerup sprite is a heavily modified version of the powerup of the same name from Gatete Mario Engine 9.
]]--

local cp = require("customPowerups")
local playeranim = require("playerAnim")

local windFlower = {}

local shootSFX = Misc.resolveFile("powerups/wind-shoot.ogg")
local shootLargeSFX = Misc.resolveFile("powerups/wind-shoot-large.ogg")
local prepareSFX = Misc.resolveFile("powerups/wind-prepare.ogg")
local scuttleSFX = Misc.resolveFile("powerups/scuttle.ogg")

windFlower.projectileID = 874
windFlower.largeProjectileID = 875
windFlower.forcedStateType = 1 
windFlower.basePowerup = PLAYER_FIREFLOWER
windFlower.cheats = {"needawindflower","needsomewind","breezy","pacifist","pacifistmode","trickytrials","hurricane","woosh","rslashwoosh","foo","playablebreeze","fooexhaledotogg"}

windFlower.scuttleAnim = playeranim.Anim({37, 38, 47, -38, -37, 39, 48, -39}, 2)

function windFlower.onInitPowerupLib()
	windFlower.spritesheets = {
		windFlower:registerAsset(CHARACTER_MARIO, "mario-wind.png"),
		windFlower:registerAsset(CHARACTER_LUIGI, "luigi-wind.png"),
		--windFlower:registerAsset(CHARACTER_PEACH, "peach-wind.png"),
		--windFlower:registerAsset(CHARACTER_TOAD,  "toad-wind.png"),
		--windFlower:registerAsset(CHARACTER_LINK,  "link-wind.png"),
	}
	
	windFlower.iniFiles = {
		windFlower:registerAsset(CHARACTER_MARIO, "mario-wind.ini"),
		windFlower:registerAsset(CHARACTER_LUIGI, "luigi-wind.ini"),
		--windFlower:registerAsset(CHARACTER_PEACH, "peach-wind.ini"),
		--windFlower:registerAsset(CHARACTER_TOAD,  "toad-wind.ini"),
		--windFlower:registerAsset(CHARACTER_LINK,  "link-wind.ini"),
	}
end

local animFrames = {11, 11, 12, 12, 12, 12, 11, 11} 

local projectileTimerMax = {30, 30, 30, 30, 30}
local largeProjectileTimerMax = {65, 65, 65, 65, 65}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount < 2
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p.isDucking -- ducking
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p:isGroundTouching() -- on a block
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function stopSFX(sfx)
	if not sfx then return end
	if not sfx.isValid or not sfx:isplaying() then return end
	sfx:stop()
end

local function doCoolCircleEffect(v, id, amount, speedX, speedY)
	for b = 1, amount do
		local e = Effect.spawn(id, v.x + v.width * 0.5, v.y + v.height * 0.5)
        	e.x = e.x - e.width * 0.5
        	e.y = e.y - e.height * 0.5
		e.speedX = -speedX * math.sin(b * 2 * math.pi / amount)
		e.speedY = speedY * math.cos(b * 2 * math.pi / amount)
	end
end

function windFlower.onEnable(p)	
	p.data.windFlower = {
		projectileTimer = 0,
		largeProjectileTimer = 0,
		canLargeCharge = false,
                largeCharging = false,
                hasCharged = false,
                canPlayChargeSFX = false,
                chargeSFX = nil,
                isScuttling = false,
                scuttleSFX = nil,
		hasPlayed = false
	}
end

function windFlower.onDisable(p)
	if p.data.windFlower then
		if p.data.windFlower.scuttleSFX then stopSFX(p.data.windFlower.scuttleSFX) end
		windFlower.scuttleAnim:stop(p)
	end
	p.data.windFlower = nil
end

function windFlower.onTickPowerup(p) 
	if not p.data.windFlower then return end 
	local data = p.data.windFlower

	-- GENERAL PROJECTILES
	
    	data.projectileTimer = math.max(data.projectileTimer - 1, 0) 
    
    	if p.mount < 2 then 
        	p:mem(0x160, FIELD_WORD, 2)
    	end

   	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
    	if p:mem(0x50, FIELD_BOOL) and isOnGround(p) then return end 
	
    	if (p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) then
		
		-- spawns the projectile itself
        	local v = NPC.spawn(
		windFlower.projectileID,
		p.x + p.width/2 + (p.width/2 + 16) * p.direction + p.speedX,
		p.y + p.height/2 + p.speedY, p.section, false, true)	
	
		v.direction = p.direction
		v.speedX = p.speedX + (6 * v.direction)
		v.speedY = p.speedY
		v.y = v.y + v.speedY

		if p.keys.up then
			v.speedX = p.speedX
			v.speedY = -6
		end

		if not isOnGround(p) and p.speedY > 0 then
			v.x = p.x + p.width/2 - v.width/2
			v.y = p.y + p.height
			v.speedY = 6
			p.speedY = -3
		end

		SFX.play(shootSFX)
		doCoolCircleEffect(v, 10, 5, 2, 3)
			
        	data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
        	data.hasCharged = false

    		if p:mem(0x148, FIELD_WORD) ~= 2 or p:mem(0x14C, FIELD_WORD) ~= 2 then
         		if isOnGround(p) then
         			p.speedX = -1.5 * p.direction
         		else
         			p.speedX = -3 * p.direction
         		end
    		end
    	end

	-- 'SCUTTLING' 

    	if not isOnGround(p) and p.speedY > 0 and not p:mem(0x50, FIELD_BOOL) and canPlayShootAnim(p) and p.mount == 0 and not p:isUnderwater() and p.keys.jump then
		if not data.scuttleSFX then data.scuttleSFX = SFX.play(scuttleSFX) end
    		data.isScuttling = true
    	else
    		data.isScuttling = false
         	stopSFX(data.scuttleSFX)
    	end
		
    	if data.isScuttling then
		p.speedY = p.speedY - (Defines.player_grav - 0.1)
		if data.scuttleSFX and not data.scuttleSFX:isplaying() then data.scuttleSFX = SFX.play(scuttleSFX) end

		p:mem(0x140, FIELD_WORD, 4)
		if p.forcedState == 0 and not p:mem(0x142, FIELD_BOOL) then
			p:mem(0x142, FIELD_BOOL, false)
		end

		if lunatime.tick() % 8 == 0 then
        		local e = Effect.spawn(10, p.x + p.width * 0.5,p.y)
        		e.x = e.x - e.width * 0.5
        		e.y = e.y - e.height * 0.5
			e.speedX = -p.speedX
			e.speedY = -5
		end
		if RNG.randomInt(1, RNG.randomInt(1, 4)) == 1 then
        		local e = Effect.spawn(74, p.x + p.width * 0.5,p.y + p.height)
        		e.x = e.x - e.width * 0.5
        		e.y = e.y - e.height * 0.5
			e.speedX = RNG.random(-6, 6)
			e.speedY = RNG.random(-4, -8)
		end
    	end

	-- LARGE WIND CHARGING

    	if data.projectileTimer < projectileTimerMax[p.character] then
    		data.canLargeCharge = true
    	else
    		data.canLargeCharge = false
    	end
 
    	if data.canLargeCharge and p.keys.run and not data.hasCharged then
    		data.largeProjectileTimer = math.max(data.largeProjectileTimer + 1, 0)
    		data.largeCharging = true
    	else
    		data.largeProjectileTimer = 0
    		data.largeCharging = false
    	end

    	if data.largeCharging then
       		if data.largeProjectileTimer % 2 == 0 then
       			Defines.earthquake = math.max(Defines.earthquake, 2)
       		end

		local e = Effect.spawn(74, 0, 0)
		e.x = p.x + RNG.random(0, p.width) - e.width * 0.5
		e.y = p.y + RNG.random(0, p.height) - e.height * 0.5

        	if not data.canPlayChargeSFX then
         		data.chargeSFX = SFX.play(prepareSFX)
         		data.canPlayChargeSFX = true
         	end
    	else
         	stopSFX(data.chargeSFX)
         	data.canPlayChargeSFX = false
    	end

    	if data.largeProjectileTimer > largeProjectileTimerMax[p.character] then
        	local v = NPC.spawn(
		windFlower.largeProjectileID,
		p.x + p.width/2 + (p.width/2 + 16) * p.direction + p.speedX,
		p.y + p.height/2 + p.speedY, p.section, false, true)	
	
		v.direction = p.direction
		v.speedX = p.speedX + (6 * v.direction)
		v.speedY = p.speedY
		v.y = v.y + v.speedY

		if p.keys.up then
			v.speedX = p.speedX
			v.speedY = -6
		end

		if not isOnGround(p) and p.speedY > 0 then
			v.x = p.x + p.width/2 - v.width/2
			v.y = p.y + p.height
			v.speedY = 6
			p.speedY = -3
		end

    		SFX.play(shootLargeSFX)
		doCoolCircleEffect(v, 10, 12, 3, 6)

    		data.largeProjectileTimer = 0
    		data.largeCharging = false
    		data.hasCharged = true

    		Defines.earthquake = math.max(Defines.earthquake, 8)

    		if isOnGround(p) then
    			p.speedY = -6
    		else
    			p.speedY = -8
    		end

    		if p:mem(0x148, FIELD_WORD) ~= 2 or p:mem(0x14C, FIELD_WORD) ~= 2 then
         		if isOnGround(p) then
         			p.speedX = -3 * p.direction
         		else
         			p.speedX = -6 * p.direction
         		end
    		end
    	end
end

function windFlower.onTickEndPowerup(p)
	if not p.data.windFlower then return end 
	local data = p.data.windFlower
	
    	local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] 
    	local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    	if data.projectileTimer > 0 and canPlay and curFrame and (p.mount == 0) then
        	p:setFrame(curFrame)
    	end

    	if data.isScuttling and canPlay then
		if not data.hasPlayed then
       			windFlower.scuttleAnim:play(p)
			data.hasPlayed = true
		end
	else
		windFlower.scuttleAnim:stop(p)
		data.hasPlayed = false
    	end
end

return windFlower