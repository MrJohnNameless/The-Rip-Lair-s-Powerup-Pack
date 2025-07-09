--[[
		Wind Flower by DeviousQuacks23 (v.1.0)
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - Provided the template that I used for this powerup
        Mojang - I took most of the SFX from Minecraft
        Gate - The powerup sprite is a heavily modified version of the powerup of the same name from Gatete Mario Engine 9.
]]--

local cp = require("customPowerups")
local playeranim = require("playerAnim")

local windFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

local shootSFX = Misc.resolveFile("powerups/wind-shoot.ogg")
local shootLargeSFX = Misc.resolveFile("powerups/wind-shoot-large.ogg")
local prepareSFX = Misc.resolveFile("powerups/wind-prepare.ogg")
local scuttleSFX = Misc.resolveFile("powerups/scuttle.ogg")

windFlower.projectileID = 874
windFlower.largeProjectileID = 875
windFlower.forcedStateType = 1 -- 0 for instant, 2 for normal/flickering, 3 for poof/raccoon
windFlower.basePowerup = PLAYER_FIREFLOWER
windFlower.cheats = {"needawindflower","needsomewind","breezy","pacifist","pacifistmode","trickytrials","hurricane","woosh","rslashwoosh","foo","playablebreeze","fooexhaledotogg"}

windFlower.scuttleAnim = playeranim.Anim({37, 38, 47, -38, -37, 39, 48, -39}, 3)

-- runs when customPowerups is done initializing the library
function windFlower.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	windFlower.spritesheets = {
		windFlower:registerAsset(CHARACTER_MARIO, "mario-wind.png"),
		windFlower:registerAsset(CHARACTER_LUIGI, "luigi-wind.png"),
		--windFlower:registerAsset(CHARACTER_PEACH, "peach-wind.png"),
		--windFlower:registerAsset(CHARACTER_TOAD,  "toad-wind.png"),
		--windFlower:registerAsset(CHARACTER_LINK,  "link-wind.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	windFlower.iniFiles = {
		windFlower:registerAsset(CHARACTER_MARIO, "mario-wind.ini"),
		windFlower:registerAsset(CHARACTER_LUIGI, "luigi-wind.ini"),
		--windFlower:registerAsset(CHARACTER_PEACH, "peach-wind.ini"),
		--windFlower:registerAsset(CHARACTER_TOAD,  "toad-wind.ini"),
		--windFlower:registerAsset(CHARACTER_LINK,  "link-wind.ini"),
	}
end

local animFrames = {11, 11, 12, 12, 12, 12, 11, 11} -- the animation frames for shooting a fireball

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {30, 30, 30, 30, 30}
local largeProjectileTimerMax = {85, 85, 85, 85, 85}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
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
        and not p:mem(0x12E, FIELD_BOOL) -- ducking
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

-- runs once when the powerup gets activated, passes the player
function windFlower.onEnable(p)	
	p.data.windFlower = {
		projectileTimer = 0,
		largeProjectileTimer = 0,
		canSpinCharge = true,
		canLargeCharge = false,
                largeCharging = false,
                hasCharged = false,
                canPlayChargeSFX = false,
                chargeSFX = nil,
		canScuttle = false,
                isScuttling = false,
                canPlayScuttleSFX = false,
                scuttleSFX = nil,
		hasPlayed = false
	}
end

-- runs once when the powerup gets deactivated, passes the player
function windFlower.onDisable(p)	
	if p.data.windFlower.scuttleSFX then stopSFX(p.data.windFlower.scuttleSFX) end
	windFlower.scuttleAnim:stop(p)
	p.data.windFlower = nil
end

-- runs when the powerup is active, passes the player
function windFlower.onTickPowerup(p) 
	if not p.data.windFlower then return end -- check if the powerup is currenly active
	local data = p.data.windFlower

	-- GENERAL PROJECTILES
	
    	data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    	if p.mount < 2 then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        	p:mem(0x160, FIELD_WORD, 2)
    	end

   	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
    	if p:mem(0x50, FIELD_BOOL) and isOnGround(p) then return end -- if spinjumping while on the ground
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    	if (p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) then
		
		-- spawns the projectile itself
        	local v = NPC.spawn(
		windFlower.projectileID,
		p.x + p.width/2 + (p.width/2 + 16) * p.direction + p.speedX,
		p.y + p.height/2 + p.speedY, p.section, false, true)	

		if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
			v.speedY = -6
		end	
	
		v.isProjectile = true
		v.direction = p.direction

		SFX.play(shootSFX)
			
        	data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
        	data.hasCharged = false
    	end

	-- MID-AIR JUMP

    	if isOnGround(p) and canPlayShootAnim(p) and (p.mount == 0) then
    		data.canSpinCharge = true
    	end

    	if not isOnGround(p) and data.canSpinCharge then
       		if (p.keys.altJump == KEYS_PRESSED and not p:mem(0x50, FIELD_BOOL)) then
        		local v = NPC.spawn(
			windFlower.projectileID,
			p.x + p.width/2,
			p.y + p.height + 8, p.section, false, true)		
	
			v.isProjectile = true
			v.direction = p.direction
                        v.speedY = 6

			SFX.play(shootSFX)
                        SFX.play(1)

                        p.speedY = -12
                        Effect.spawn(10, (p.x), (p.y + p.height*0.5)) 
                        data.canSpinCharge = false
       		end
   	end

	-- 'SCUTTLING' 

    	if (not isOnGround(p)) and (p.speedY > 0) and (not p:mem(0x50, FIELD_BOOL)) and (canPlayShootAnim(p)) and (p.mount == 0) then
    		data.canScuttle = true
    	else
    		data.canScuttle = false
    	end

    	if data.canScuttle and p.keys.jump then
    		data.isScuttling = true
    		p.speedY = p.speedY - (Defines.player_grav - 0.1)
    	else
    		data.isScuttling = false
    	end

    	if data.isScuttling then
        	if not data.canPlayScuttleSFX then
        		data.scuttleSFX = SFX.play(scuttleSFX,1,0)
        		data.canPlayScuttleSFX = true
        	end

		if lunatime.tick() % 8 == 0 then
        		local e = Effect.spawn(10, p.x + p.width * 0.5,p.y)
        		e.x = e.x - e.width * 0.5
        		e.y = e.y - e.height * 0.5
			e.speedX = -p.speedX
			e.speedY = -5
		end
		if RNG.randomInt(1, 2) == 1 then
        		local e = Effect.spawn(74, p.x + p.width * 0.5,p.y + p.height)
        		e.x = e.x - e.width * 0.5
        		e.y = e.y - e.height * 0.5
			e.speedX = RNG.random(-6, 6)
			e.speedY = RNG.random(-4, -8)
		end
   	else
         	stopSFX(data.scuttleSFX)
         	data.canPlayScuttleSFX = false
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
       		if data.largeProjectileTimer%2 == 0 then
       			Defines.earthquake = 2
       		end

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

		if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
			v.speedY = -12
		end		

		v.isProjectile = true
		v.direction = p.direction

    		SFX.play(shootLargeSFX)

    		data.largeProjectileTimer = 0
    		data.largeCharging = false
    		data.hasCharged = true

    		Defines.earthquake = 8

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
	if not p.data.windFlower then return end -- check if the powerup is currently active
	
	local data = p.data.windFlower
	
	-- put your own code here!
	
    	local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    	local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    	if data.projectileTimer > 0 and canPlay and curFrame and (p.mount == 0) then
        	p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    	end

    	if (data.canScuttle) and (p.keys.jump) and (not p:mem(0x12E, FIELD_BOOL)) and (p:mem(0x146, FIELD_WORD) ~= 2) and (p.mount == 0) then
		if not data.hasPlayed then
       			windFlower.scuttleAnim:play(p)
			data.hasPlayed = true
		end
	else
		windFlower.scuttleAnim:stop(p)
		data.hasPlayed = false
    	end
end

function windFlower.onDrawPowerup(p)
	if not p.data.windFlower then return end -- check if the powerup is currently active
	local data = p.data.windFlower
	-- put your own code here!
end

return windFlower