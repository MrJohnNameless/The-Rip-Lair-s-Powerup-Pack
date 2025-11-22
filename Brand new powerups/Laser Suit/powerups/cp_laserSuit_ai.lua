--[[

    Cape for anotherpowerup.lua
    by MrDoubleA

    Credit to JDaster64 for making a SMW physics guide and ripping SMA4 Mario/Luigi sprites
    Custom Toad and Link sprites by Legend-Tony980 (https://www.deviantart.com/legend-tony980/art/SMBX-Toad-s-sprites-Fourth-Update-724628909, https://www.deviantart.com/legend-tony980/art/SMBX-Link-s-sprites-Sixth-Update-672269804)
    Custom Peach sprites by Lx Xzit and Pakesho
    SMW Mario and Luigi graphics from AwesomeZack

	Tweaked to work with multiplayer by John Nameless

    Credit to FyreNova for generally being cool (oh and maybe working on a SMBX38A version of this, too)
	
	Turned into the Laser Suit, by MegaDood

]]

local playerManager = require("playerManager")

local apt = {}


local MOUNT_NONE     = 0
local MOUNT_BOOT     = 1
local MOUNT_CLOWNCAR = 2
local MOUNT_YOSHI    = 3

local colBox = Colliders.Box(0,0,0,0)

apt.screenShake = 0

--[[
	The following table variables below are supposed to be equivalents to "p.data.powerupName" values seen in other custom powerups.
	Unforunately, due to MDA's cape feather being initially designed for single player, I had to resort to either this or restructure the code entirely.
	I apologize if this method makes manipulating player data values of this powerup awful to work with, 
	because it absolutely is awful to work with.
		
	- John Nameless
--]]

apt.projectileID = 777

apt.flyingState = {}
apt.spinTimer = {}
apt.capeAnimation = {}
apt.capeAnimationTimer = {}
apt.capeAnimationSpeed = {}
apt.capeAnimationFinished = {}
apt.capeFrame = {}
apt.pSpeed = {}
apt.pSpeedSmokeTimer = {}
apt.usePSpeedFrames = {}
apt.pullingBack = {}
apt.catchingAirTimer = {}
apt.highestFlyingState = {}
apt.slidingFromFlight = {}
apt.walkingTimer = {}
apt.ascentTimer = {}
apt.sprite = {}
apt.laserAnim = {}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {12, 16, 24, 8, 24}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

-- Convenience functions
local function isOnGround(p)
    return (
        p:isOnGround(p)
        or (p.mount == MOUNT_BOOT and p:mem(0x10C,FIELD_BOOL)) -- Hopping in boot
        or p:mem(0x40,FIELD_WORD) > 0                               -- Climbing
        or p.mount == MOUNT_CLOWNCAR
    )
end
local function isOnGroundRedigit(p) -- isOnGround, except redigit
    return (
        p.speedY == 0
        or p.standingNPC ~= nil
        or p:mem(0x48,FIELD_WORD) > 0 -- On a slope
    )
end
local function getPlayerGravity(p)
    local gravity = Defines.player_grav
    if p:mem(0x34,FIELD_WORD) > 0 and p:mem(0x06,FIELD_WORD) == 0 then
        gravity = gravity*0.1
    elseif p:mem(0x3A,FIELD_WORD) > 0 then
        gravity = 0
    elseif playerManager.getBaseID(p.character) == CHARACTER_LUIGI then
        gravity = gravity*0.9
    end

    return gravity
end
local function isUnderwater(p)
    return (
        p:mem(0x36,FIELD_BOOL)          -- In a liquid
        and p:mem(0x06,FIELD_WORD) == 0 -- Not in quicksand
    )
end

-- "Requirement" functions
local function powerupAbilitiesDisabled(p)
    return (
        p.forcedState > 0 or p.deathTimer > 0 or p:mem(0x13C,FIELD_BOOL) -- In a forced state/dead
        or p:mem(0x40,FIELD_WORD) > 0 -- Climbing
        or p:mem(0x0C,FIELD_BOOL)     -- Fairy
        or p.mount == MOUNT_CLOWNCAR
    )
end
local function canFallSlowly(p)
    return (
        not powerupAbilitiesDisabled(p)
        and not isOnGround(p)
        and not p:mem(0x36,FIELD_BOOL) -- Not in a liquid
        and not p:mem(0x5C,FIELD_BOOL) -- Not ground pounding with a purple yoshi
        and apt.flyingState[p.idx] == nil
    )
end
local function canSpin(p)
    return (
        (not powerupAbilitiesDisabled(p)
        and not p:mem(0x12E,FIELD_BOOL) -- Ducking
        and not p:mem(0x3C,FIELD_BOOL)  -- Sliding
        and p.character ~= CHARACTER_LINK
        and p.mount == MOUNT_NONE
        and p.holdingNPC == nil
		and p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p.isDucking or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
		) or (apt.laserAnim[p.idx] and apt.laserAnim[p.idx] > 0)
    )
end
local function canBuildPSpeed(p)
    return (
        not powerupAbilitiesDisabled(p)
        and not p:mem(0x36,FIELD_BOOL) -- In a liquid
        and p.mount ~= MOUNT_CLOWNCAR
    )
end
local function canFly(p)
    return (
        canBuildPSpeed(p)
        and (p.keys.run or p.keys.altRun)
        and not p:mem(0x50,FIELD_BOOL) -- Spin jumping
        and p.mount == MOUNT_NONE
        and p.holdingNPC == nil
    )
end


local function isSlipping(p)
    return (
        p:mem(0x0A,FIELD_BOOL)                          -- On a slippery block
        and (not p.keys.left and not p.keys.right) -- Slip, sliding away
    )
end

local walkingFrames = {[CHARACTER_MARIO] = table.map{1,2,3,16,17,18},[CHARACTER_LINK] = table.map{1,2,3,4,16,17,18}}
local jumpingFrames = {[CHARACTER_MARIO] = table.map{4,5,19}        ,[CHARACTER_LINK] = table.map{5,3,19}          }
local function isInWalkingAnimation(p) -- Note: doesn't account for walking while holding an NPC
    local currentFrame = p:getFrame()

    return (
        (walkingFrames[p.character] or walkingFrames[CHARACTER_MARIO])[currentFrame]

        and ((p.forcedState == 0 and p.speedX ~= 0 and not isSlipping(p)) or p.forcedState == 3)
        and p.deathTimer == 0 and not p:mem(0x13C,FIELD_BOOL) -- Dead
        and not p:mem(0x50,FIELD_BOOL) -- Spin jumping
        and isOnGroundRedigit(p)

        and p.mount == MOUNT_NONE
    )
end
local function isInJumpingAnimation(p)
    local currentFrame = p:getFrame()

    return (
        (jumpingFrames[p.character] or jumpingFrames[CHARACTER_MARIO])[currentFrame]

        and p.deathTimer == 0 and not p:mem(0x13C,FIELD_BOOL) -- Dead
        and not isOnGroundRedigit(p)
        and not isUnderwater(p)

        and p.forcedState == 0
        and p.mount == MOUNT_NONE
    )
end

local invisibleStates = table.map{5,8,10}
local function canDrawCape(p)
    return (
        p.deathTimer == 0 and not p:mem(0x13C,FIELD_BOOL) -- Dead
        and not invisibleStates[p.forcedState] -- In a forced state that prevents rendering
        and p.powerup ~= PLAYER_SMALL          -- Small, from the "powering down" animation
        and not p:mem(0x142,FIELD_BOOL)        -- Flashing
        and not p:mem(0x0C,FIELD_BOOL)         -- Fairy
    )
end

-- Cape animation stuff
local findCapeAnimation
do
    apt.capeAnimations = {
        idle        = {1,           isIdle = true},
        idleOnYoshi = {14,          isIdle = true},
        duckOnYoshi = {1,           isIdle = true,priorityDifference = -0.02},

        walk        = {2,3,4,5,     loopPoint = 1},
        fall        = {2,3,6,7,8,9, loopPoint = 3},
        spin        = {1,     	    isIdle = true},
        rest        = {10,11},

        frontFacing = {12,          isIdle = true,priorityDifference = -0.01},
        backFacing  = {12,          isIdle = true,priorityDifference =  0.01},

        invisible = {0},
    }

    function apt.setCapeAnimation(name,forceRestart,idx)
        if apt.capeAnimations[name] == nil then
            error("Cape animation '".. tostring(name).. "' does not exist.")
        end


        if name == apt.capeAnimation[idx] and not forceRestart then return end
    
        apt.capeAnimation[idx] = name
        apt.capeAnimationTimer[idx] = 0
        apt.capeAnimationSpeed[idx] = 1
    
        apt.capeAnimationFinished[idx] = false
    end
    
	for i = 1,2 do
		apt.setCapeAnimation("idle",true,i)
		apt.capeFrame[i] = 1
	end

    local frontFrames = table.map{0,15}
    local backFrames = table.map{13,25,26}

    local function isSpinning(p)
        return (
            p:mem(0x50,FIELD_BOOL) -- Spin jumping
            or apt.spinTimer[p.idx] > 0        -- Spin attack
        )
    end
    local function isInFlight(p)
        return (
            apt.flyingState[p.idx] ~= nil
            or apt.slidingFromFlight[p.idx]
        )
    end

    local horizontalDirections = table.map{2,4}
    local function isUsingHorizontalPipe(p)
        local warp = Warp(p:mem(0x15E,FIELD_WORD)-1)

        return (
            p.forcedState == 3
            and (
                (p.forcedTimer == 0 and horizontalDirections[warp:mem(0x80,FIELD_WORD)])
                or (p.forcedTimer == 2 and horizontalDirections[warp:mem(0x82,FIELD_WORD)])
            )
        )
    end

    local function findCapeIdleAnimation(p)
        local animation = apt.capeAnimations[apt.capeAnimation[p.idx]]

        if (apt.capeAnimation[p.idx] == "rest" and apt.capeAnimationFinished[p.idx]) or (animation.isIdle) then
            if p.mount ~= MOUNT_YOSHI then
                return "idle"
            elseif not p:mem(0x12E,FIELD_BOOL) then
                return "idleOnYoshi"
            else
                return "duckOnYoshi"
            end
        else
            return "rest"
        end
    end

    function findCapeAnimation(p)
        local playerFrame = p:getFrame()


        if p.mount == MOUNT_CLOWNCAR then
            return findCapeIdleAnimation(p)
        end


        if (p.speedY > 0 or p:mem(0x1C,FIELD_WORD) > 0) and not isOnGround(p) and not isInFlight(p) then
            return "fall"
        end


        if isSpinning(p) then
            return "spin"
        end


        if isInFlight(p) then
            return "invisible"
        end


        if p.character ~= CHARACTER_LINK then
            if backFrames[playerFrame] then
                return "backFacing"
            elseif frontFrames[playerFrame] then
                return "frontFacing"
            end
        end


        if (isOnGround(p) and p.speedX ~= 0 or isUsingHorizontalPipe(p)) or (apt.ascentTimer[p.idx] ~= nil) then
            return "walk",math.max(0.2,math.abs(p.speedX)/Defines.player_runspeed)
        elseif p.forcedState == 0 and not isOnGround(p) and isUnderwater(p) then
            return "walk",0.4
        end


        return findCapeIdleAnimation(p)
    end
end


local ascentDisableKeys = {"down"}
local flightDisableKeys = {"left","right","down"}

local directionKeys = {[DIR_LEFT] = "left",[DIR_RIGHT] = "right"}


local function getCheatIsActive(name)
    if Cheats == nil or Cheats.get == nil then
        return false
    end

    local cheat = Cheats.get(name)

    return (cheat ~= nil and cheat.active)
end



local function capeHitNPCFilter(npc)
    return (
        Colliders.FILTER_COL_NPC_DEF(npc)
        and npc.despawnTimer > 0
        and npc:mem(0x138,FIELD_WORD) == 0 -- In a forced state
        and npc:mem(0x12C,FIELD_WORD) == 0 -- Being held
        and npc:mem(0x26,FIELD_WORD)  == 0 -- Tail/sword cooldown
    )
end

local invalidSpinBlocks = table.map{90,293,457}

local function spinAttack(p)
end


local characterSpeedMultipliers = {
    [CHARACTER_PEACH] = 0.93,
    [CHARACTER_TOAD ] = 1.07,
}
local function getPlayerMaxSpeed(p)
    return (Defines.player_runspeed*(characterSpeedMultipliers[playerManager.getBaseID(p.character)] or 1))
end

local smwCostumes = table.map{"SMW-MARIO","SMW-LUIGI"}
local function pSpeedRunningAnimation(p)
    local currentFrame = p:getFrame()


    -- Custom walk cycle stuff
    local isUsingSMWCostume = smwCostumes[p:getCostume()]
    local isLink = (p.character == CHARACTER_LINK)

    if (isUsingSMWCostume or isLink) and isInWalkingAnimation(p) then
        apt.walkingTimer[p.idx] = (apt.walkingTimer[p.idx] + math.max(1,math.abs(p.speedX)))%45

        local timer = math.floor(apt.walkingTimer[p.idx])
        if isUsingSMWCostume then
            timer = (45-timer)-1
        end

        currentFrame = math.floor(timer/15)+1
    elseif isLink and isInJumpingAnimation(p) then
        if p.speedY < 0 then
            currentFrame = 4
        else
            currentFrame = 5
        end
    else
        apt.walkingTimer[p.idx] = 0
    end


    if not isInWalkingAnimation(p) and not isInJumpingAnimation(p) then
        return
    end


    local runningFrameIndex = table.ifind(apt.flightSettings.runningFrames[p.character],currentFrame)
    local walkingFrameIndex = table.ifind(apt.flightSettings.normalFrames[p.character] ,currentFrame)



    if apt.usePSpeedFrames[p.idx] then
        if walkingFrameIndex ~= nil then
            p:setFrame(apt.flightSettings.runningFrames[p.character][walkingFrameIndex])
        end
    else
        if runningFrameIndex ~= nil then
            p:setFrame(apt.flightSettings.normalFrames[p.character][runningFrameIndex])
        elseif walkingFrameIndex ~= nil and isUsingSMWCostume then
            p:setFrame(currentFrame) -- Make sure that its P-speed animations don't happen
        end
    end
end


local function disableLinkJump(p)
    local baseCharacter = playerManager.getBaseID(p.character)

    if baseCharacter == CHARACTER_LINK and p:mem(0x12E,FIELD_BOOL) then
        local settings = PlayerSettings.get(baseCharacter,p.powerup)

        p.y = p.y+p.height-settings.hitboxHeight
        p.height = settings.hitboxHeight

        p:mem(0x12E,FIELD_BOOL,false)
    end
end


local function diveBombNPCFilter(npc)
    return (
        Colliders.FILTER_COL_NPC_DEF(npc)
        and npc.despawnTimer > 0
        and npc:mem(0x138,FIELD_WORD) == 0 -- In a forced state
        and npc:mem(0x12C,FIELD_WORD) == 0 -- Being held
        and npc.collidesBlockBottom
    )
end
local function flightDiveBomb(p)
    for _,npc in NPC.iterate() do
        if diveBombNPCFilter(npc) then
            -- Redigit stuff
            local block = Block(0)
            block.y = npc.y+npc.height


            npc:harm(HARM_TYPE_FROMBELOW)
        end
    end

    apt.screenShake = 8
    SFX.play(37)
end



function apt.onInitAPI()
    registerEvent(apt,"onCameraUpdate")
    registerEvent(apt,"onPlayerHarm")
end




local function resetSpinAttack(p)
    p:mem(0x164,FIELD_WORD,0)
    apt.spinTimer[p.idx] = 0
end

local function resetPSpeed(p)
    apt.pSpeed[p.idx] = 0
    apt.pSpeedSmokeTimer[p.idx] = 0
    apt.usePSpeedFrames[p.idx] = false
end
local function resetAscent(p)
    apt.ascentTimer[p.idx] = nil
end
local function resetFlight(p)
    apt.flyingState[p.idx] = nil
    apt.pullingBack[p.idx] = false
    apt.catchingAirTimer[p.idx] = 0

    apt.highestFlyingState[p.idx] = nil
end

local function resetState(p)
    resetSpinAttack(p)
    resetPSpeed(p)
    resetAscent(p)
    resetFlight(p)

    apt.slidingFromFlight[p.idx] = false

    apt.walkingTimer[p.idx] = 0 -- For the SMW-Mario costume and Link
end

local canSpinJumpCharacters = table.map{CHARACTER_MARIO,CHARACTER_LUIGI,CHARACTER_TOAD}
function apt.onPlayerHarm(eventObj,p)
    if not p or (apt.flyingState[p.idx] == nil or not canFly(p)) then return end

    p:mem(0x140,FIELD_WORD,150)
    eventObj.cancelled = true

    p:mem(0x50,FIELD_BOOL,canSpinJumpCharacters[p.idx])

    resetFlight(p)

    if apt.flightSettings.hitSFX ~= nil then
        SFX.play(apt.flightSettings.hitSFX)
    end
end



function apt.onEnable(library,p)
    resetState(p)
end

function apt.onDisable(library,p)
    resetState(p)
end


function apt.onTick(library,p)
    -- Make link... actually work
    if p.character == CHARACTER_LINK and (p:mem(0x14,FIELD_WORD) == 0 or p:mem(0x14,FIELD_WORD) < -7) then
        p:mem(0x160,FIELD_WORD,0)
    end
	
	apt.laserAnim[p.idx] = (apt.laserAnim[p.idx] or 0) - 1

	if apt.laserAnim[p.idx] > 0 then p:setFrame(11) end

    -- Slow falling
    if canFallSlowly(p) and (p.keys.jump or p.keys.altJump) and Level.winState() == 0 then
        p.speedY = math.min(p.speedY,apt.slowFallSettings.speed-getPlayerGravity(p))
    end

    -- Spin attack
	local flamethrowerActive = Cheats.get("flamethrower").active
    if ((not apt.laserAnim[p.idx] or apt.laserAnim[p.idx] <= 0) or flamethrowerActive) and Level.winState() == 0 then
	
		--[[if linkChars[p.character] then
			p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
			if p:mem(0x162,FIELD_WORD) > 2 then return end
		else
			if p:mem(0x160, FIELD_WORD) > 0 then return end
		end]]
	
		
		local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p.isSpinJumping) 
		
		if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
			tryingToShoot = true
		end
		
		--Edit this block of code to make it shoot the laser, MegaDood
        if p:mem(0x50,FIELD_BOOL) then -- Spin jumping
            resetSpinAttack(p)
            spinAttack(p)
        elseif (p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED) then
            SFX.play(apt.spinAttackSettings.sfx)
            apt.spinTimer[p.idx] = 1
            if apt.flyingState[p.idx] ~= nil then
                p.direction = -p.direction
            end
			
			-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
			if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
				local dir = p.direction
				
				-- spawns the projectile itself
				local v = NPC.spawn(
					apt.projectileID,
					p.x + p.width/2 + (p.width/2) * dir + p.speedX,
					p.y + 4 + p.height/2 + p.speedY, p.section, false, true
				)
				v.direction = dir
				v.speedX = ((NPC.config[v.id].speed) * dir) + p.speedX/3.5
				
				apt.laserAnim[p.idx] = projectileTimerMax[p.character]
			end
        end

        if apt.spinTimer[p.idx] > apt.spinAttackSettings.length then
            resetSpinAttack(p)
        elseif apt.spinTimer[p.idx] > 0 then
            apt.spinTimer[p.idx] = apt.spinTimer[p.idx] + 1
            spinAttack(p)
        end
    else
        resetSpinAttack(p)
    end

    -- P-Speed
    if canBuildPSpeed(p) then
        if math.abs(p.speedX) >= getPlayerMaxSpeed(p) and isOnGround(p) then
            apt.pSpeed[p.idx] = math.min(apt.flightSettings.neededRunTime[p.character],apt.pSpeed[p.idx] + 1)

            apt.usePSpeedFrames[p.idx] = (apt.pSpeed[p.idx] >= apt.flightSettings.neededRunTime[p.character])
        elseif (math.abs(p.speedX) < getPlayerMaxSpeed(p) and isOnGroundRedigit(p)) then -- changed this line & added an elseif statement
            apt.pSpeed[p.idx] = math.max(0,apt.pSpeed[p.idx] - 0.5)

            apt.usePSpeedFrames[p.idx] = (apt.usePSpeedFrames[p.idx] and not isOnGround(p))
        end

        if apt.usePSpeedFrames[p.idx] and isOnGround(p) then
            apt.pSpeedSmokeTimer[p.idx] = apt.pSpeedSmokeTimer[p.idx] + 1

            if apt.pSpeedSmokeTimer[p.idx]%4 == 0 then
                local effect = Effect.spawn(74,p.x+(p.width/2)-(8*p.direction),p.y+p.height)

                effect.x = effect.x-(effect.width /2)
                effect.y = effect.y-(effect.height/2)
            end
        end
    else
        resetPSpeed(p)
    end

    -- Ascent
    if canBuildPSpeed(p) and Level.winState() == 0 then
        if (apt.pSpeed[p.idx] >= apt.flightSettings.neededRunTime[p.character] or getCheatIsActive("wingman")) and p:mem(0x11C,FIELD_WORD) > 0 then
            -- Start ascent
            p:mem(0x11C,FIELD_WORD,0) -- Stop the jump force

            apt.ascentTimer[p.idx] = apt.flightSettings.maximumAscentTime
            apt.usePSpeedFrames[p.idx] = true
        end

        if apt.ascentTimer[p.idx] ~= nil then
            apt.ascentTimer[p.idx] = math.max(0,apt.ascentTimer[p.idx]-1)

            -- This isn't exactly accurate to SMW, but it's the best I could do without it feeling like a soggy bag of potatoes. The default numbers are pretty much accurate, though.
            if apt.ascentTimer[p.idx] > 0 and (p.keys.jump or p.keys.altJump) or (apt.flightSettings.maximumAscentTime-apt.ascentTimer[p.idx]) < apt.flightSettings.minimumAscentTime then
                p.speedY = math.max(apt.flightSettings.ascentMaxSpeed,p.speedY+apt.flightSettings.ascentAcceleration)-getPlayerGravity(p)
            else
                apt.ascentTimer[p.idx] = 0
            end

            if p.speedY > 0 or p:mem(0x14A,FIELD_WORD) > 0 then
                if canFly(p) then
                    resetFlight(p)
                    apt.flyingState[p.idx] = 1

                    apt.usePSpeedFrames[p.idx] = false
                end

                resetAscent(p)
            end


            for _,name in ipairs(ascentDisableKeys) do
                p.keys[name] = false
            end
        end
    else
        resetAscent(p)
    end

    -- Flight
    if canFly(p) and not isOnGround(p) and apt.flyingState[p.idx] ~= nil and Level.winState() == 0 then
        local holdingForward   = p.keys[directionKeys[ p.direction]]
        local holdingBackwards = p.keys[directionKeys[-p.direction]]

        local stateChangeSpeed = apt.flightSettings.stateChangeSpeed


        if p:mem(0x11C,FIELD_WORD) > 0 then -- Bounced on an enemy or something
            p:mem(0x11C,FIELD_WORD,0) -- Stop the jump force

            apt.pullingBack[p.idx] = true
        end

        p:mem(0x18,FIELD_BOOL,false) -- Stop Peach's hover



        if apt.pullingBack[p.idx] then
            local fromDiveBomb = (apt.highestFlyingState[p.idx] >= 6)

            if fromDiveBomb then
                stateChangeSpeed = -apt.flightSettings.stateChangeSpeedFast
            else
                stateChangeSpeed = -stateChangeSpeed
            end


            if apt.flyingState[p.idx] < 2 then
                apt.flyingState[p.idx] = 1
                apt.pullingBack[p.idx] = false

                if apt.highestFlyingState[p.idx] >= 3 and (p.speedX*p.direction) > 0 then
                    if fromDiveBomb then
                        apt.catchingAirTimer[p.idx] = apt.flightSettings.catchAirTimeLong
                    else
                        apt.catchingAirTimer[p.idx] = apt.flightSettings.catchAirTime
                    end

                    p.speedY = 0

                    SFX.play(apt.flightSettings.catchAirSFX)
                end
            end
        elseif apt.catchingAirTimer[p.idx] > 0 then
            apt.catchingAirTimer[p.idx] = apt.catchingAirTimer[p.idx] - 1

            p.speedY = p.speedY + apt.flightSettings.catchAirSpeed

            stateChangeSpeed = -stateChangeSpeed
        elseif holdingBackwards then
            apt.pullingBack[p.idx] = true

            stateChangeSpeed = 0
        elseif p.speedY < -1 then
            stateChangeSpeed = 0
        elseif holdingForward then
            p.speedX = p.speedX + (apt.flightSettings.acceleration*p.direction)
        else
            stateChangeSpeed = stateChangeSpeed*math.sign(3-apt.flyingState[p.idx])
        end



        if apt.flyingState[p.idx] == 1 then
            apt.highestFlyingState[p.idx] = 1
        else
            apt.highestFlyingState[p.idx] = math.max(apt.flyingState[p.idx],apt.highestFlyingState[p.idx] or 1)
        end

        if stateChangeSpeed ~= 0 then
            apt.flyingState[p.idx] = math.clamp(apt.flyingState[p.idx] + (1/stateChangeSpeed),1,6)
        end
        

        local gravity = (apt.flightSettings.gravity*apt.flyingState[p.idx])
        local terminalVelocity = (apt.flightSettings.maxDownwardsSpeed*apt.flyingState[p.idx])

        p.speedY = math.clamp(p.speedY-getPlayerGravity(p)+gravity,apt.flightSettings.maxUpwardsSpeed,terminalVelocity)


        for _,name in ipairs(flightDisableKeys) do
            p.keys[name] = false
        end
        

        --Text.print(apt.flyingState[p.idx],32,32)
        --Text.print(apt.highestFlyingState[p.idx],32,64)
        --Text.print(apt.catchingAirTimer[p.idx],32,96)
    elseif canFly(p) and apt.flyingState[p.idx] ~= nil then
        if apt.flyingState[p.idx] >= 5 then
            flightDiveBomb(p)
			resetPSpeed(p)
        else
            p:mem(0x3C,FIELD_BOOL,true)
            apt.slidingFromFlight[p.idx] = true
        end

        p:mem(0x18,FIELD_BOOL,false) -- Give back Peach's hover

        resetFlight(p)
    else
        resetFlight(p)
    end


    -- Sliding after flight
    apt.slidingFromFlight[p.idx] = (apt.slidingFromFlight[p.idx] and p:mem(0x3C,FIELD_BOOL))
end


function apt.onTickEnd(library,p)
    -- Find player frame
    local currentFrame = p:getFrame()

    if canSpin(p) and apt.spinTimer[p.idx] > 0 then
        local frameIndex = (apt.spinTimer[p.idx]%#apt.spinAttackSettings.frames)+1

        p:setFrame(apt.spinAttackSettings.frames[frameIndex])
    elseif (canFly(p) and apt.flyingState[p.idx] ~= nil) or (p:mem(0x3C,FIELD_BOOL) and apt.slidingFromFlight[p.idx]) then
        local frameIndex = 1

        if apt.flyingState[p.idx] ~= nil then
            frameIndex = math.floor(apt.flyingState[p.idx])
        elseif apt.slidingFromFlight[p.idx] then
            local slopeBlock = Block(p:mem(0x48,FIELD_WORD))
            if slopeBlock.idx == 0 or not slopeBlock.isValid then
                slopeBlock = nil
            end


            if slopeBlock ~= nil then
                local config = Block.config[slopeBlock.id]
                local againstPlayer = (p.direction ~= config.floorslope)


                frameIndex = math.floor(slopeBlock.width/slopeBlock.height)

                if not againstPlayer then
                    frameIndex = #apt.flightSettings.frames[p.character]-frameIndex
                end
            elseif isOnGround(p) then
                frameIndex = 3
            elseif p.speedY < 0 then
                frameIndex = 1
            else
                frameIndex = 2
            end
        end


        frameIndex = math.clamp(frameIndex,1,#apt.flightSettings.frames[p.character])

        p:setFrame(apt.flightSettings.frames[p.character][frameIndex])
    else
        -- P-Speed frames
        pSpeedRunningAnimation(p)
    end

    -- Janky, janky, here comes the redigit
    if apt.usePSpeedFrames[p.idx] or apt.flyingState[p.idx] ~= nil then
        disableLinkJump(p)
    end

    
    -- Find the cape's animation
    local name,speed = findCapeAnimation(p)

    if name ~= nil then
        apt.setCapeAnimation(name,nil,p.idx)
    end
    apt.capeAnimationSpeed[p.idx] = speed or apt.capeAnimationSpeed[p.idx]


    -- Actually handle the animation
    local animation = apt.capeAnimations[apt.capeAnimation[p.idx]]
    local frameIndex = math.floor(apt.capeAnimationTimer[p.idx]/(animation.frameDelay or 4))+1

    apt.capeAnimationTimer[p.idx] = apt.capeAnimationTimer[p.idx] + apt.capeAnimationSpeed[p.idx]

    if frameIndex > #animation then -- Finished the animation
        if animation.loopPoint ~= nil then
            local loopingFrames = (#animation-animation.loopPoint)+1

            frameIndex = (frameIndex%loopingFrames)+animation.loopPoint
        else
            apt.capeAnimationFinished[p.idx] = true
            frameIndex = #animation
        end
    end

    apt.capeFrame[p.idx] = animation[frameIndex]
end


-- Drawing
do
    local capeImageSize = 100

    local starmanShader = Shader()
    starmanShader:compileFromFile(nil,Misc.multiResolveFile("starman.frag","shaders/npc/starman.frag"))


    local function round(value)
        if value%1 < 0.5 then
            return math.floor(value)
        else
            return math.ceil(value)
        end
    end

    local clownCarOffsets = {
        [CHARACTER_MARIO] = {[PLAYER_SMALL] = 24,[PLAYER_BIG] = 36},
        [CHARACTER_LUIGI] = {[PLAYER_SMALL] = 24,[PLAYER_BIG] = 38},
        [CHARACTER_PEACH] = {[PLAYER_SMALL] = 24,[PLAYER_BIG] = 30},
        [CHARACTER_TOAD]  = {[PLAYER_SMALL] = 24,[PLAYER_BIG] = 30},
        [CHARACTER_LINK]  = {[PLAYER_SMALL] = 30,[PLAYER_BIG] = 30},
    }
    local characterOffsets = {
        [CHARACTER_PEACH] = -4,
        [CHARACTER_LINK]  = -8,
    }

    local function getPosition(p)
        local baseCharacter = playerManager.getBaseID(p.character)

        local settings = PlayerSettings.get(baseCharacter,p.powerup)
        local animation = apt.capeAnimations[apt.capeAnimation[p.idx]]

        local position = vector(p.x+(p.width/2),p.y+p.height)

        if p.mount == MOUNT_CLOWNCAR then
            local clownCarOffset = clownCarOffsets[baseCharacter]
            clownCarOffset = clownCarOffset[p.powerup] or clownCarOffset[PLAYER_BIG]

            position.y = p.y-clownCarOffset+settings.hitboxHeight
        elseif p.mount == MOUNT_YOSHI then
            position.x = position.x - (4*p.direction)

            position.y = position.y + p:mem(0x10E,FIELD_WORD) + 2
            position.y = position.y-p.height+settings.hitboxHeight
        end

        if not animation.isIdle then
            position.y = position.y+(characterOffsets[p.character] or 0)
        end


        position.y = position.y-(capeImageSize/2)+32

        position = vector(round(position.x),round(position.y))


        return position
    end

    local function getCapePriority(p)
        local animation = apt.capeAnimations[apt.capeAnimation[p.idx]]

        local priority = -25
        if p.forcedState == 3 then
            priority = -70
        elseif p.mount == MOUNT_CLOWNCAR then
            priority = -35
        end

        priority = priority+(animation.priorityDifference or -0.01)
        if p.mount == MOUNT_YOSHI then
            priority = priority+0.01
        end

        return priority
    end


    local function drawCape(spritesheets,position,priority,sceneCoords,target,p)
        local texture = apt:getAsset(p.character, spritesheets[p.character])

        if texture == nil then
            texture = apt:getAsset(CHARACTER_MARIO, spritesheets[CHARACTER_MARIO])
        end

        if texture == nil then return end

        if apt.sprite[p.idx] == nil or apt.sprite[p.idx].texture ~= texture then
            apt.sprite[p.idx] = Sprite{texture = texture,frames = texture.height/capeImageSize,pivot = vector(0.5,0.5)}
        end


        local direction = p.direction
        if p:getFrame() < 0 then
            direction = -direction
        end

        local shader,uniforms
        local color = Color.white
        if p.hasStarman then
            shader = starmanShader
            uniforms = {time = lunatime.tick()*2}
        elseif Defines.cheat_shadowmario then
            color = Color.black
        end

        

        --local position = getPosition()
        --position = vector(round(position.x),round(position.y))


        apt.sprite[p.idx].texpivot = vector((-direction+1)*0.5,0)
        apt.sprite[p.idx].width = texture.width*direction

        apt.sprite[p.idx].position = position or getPosition(p)

        apt.sprite[p.idx]:draw{
            frame = apt.capeFrame[p.idx] or 1,
            color = color,shader = shader,uniforms = uniforms,
            priority = priority or getCapePriority(p),sceneCoords = (sceneCoords ~= false),target = target,
        }
    end

    apt.drawCape = drawCape -- why not, I guess


    local pipeCutoffRules = {}

    -- Moving up on entrance/moving down on exit
    pipeCutoffRules[1] = (function(position,sourcePosition,sourceSize,warpPosition,warpSize)
        sourcePosition.y = math.max(0,warpPosition.y-position.y)
        sourceSize.y = (sourceSize.y - sourcePosition.y)

        position.y = math.max(position.y,warpPosition.y)

        return position,sourcePosition,sourceSize
    end)

    -- Moving left on entrance/moving right on exit
    pipeCutoffRules[2] = (function(position,sourcePosition,sourceSize,warpPosition,warpSize)
        sourcePosition.x = math.max(0,warpPosition.x-position.x)
        position.x = math.max(position.x,warpPosition.x)

        return position,sourcePosition,sourceSize
    end)

    -- Moving down on entrance/moving up on exit
    pipeCutoffRules[3] = (function(position,sourcePosition,sourceSize,warpPosition,warpSize)
        sourceSize.y = math.max(0,(warpPosition.y+warpSize.y)-position.y)

        return position,sourcePosition,sourceSize
    end)

    -- Moving right on entrance/moving left on exit
    pipeCutoffRules[4] = (function(position,sourcePosition,sourceSize,warpPosition,warpSize)
        sourceSize.x = math.max(0,(warpPosition.x+warpSize.x)-position.x)

        return position,sourcePosition,sourceSize
    end)


    function apt.onDraw(library,p)
        if not canDrawCape(p) or (apt.capeFrame[p.idx] ~= nil and apt.capeFrame[p.idx] < 1) then return end
        
		local capeBuffer = Graphics.CaptureBuffer(capeImageSize,capeImageSize)
		
        local bufferSize = vector(capeBuffer.width,capeBuffer.height)

        -- First, draw the cape to a buffer
        capeBuffer:clear(-100)

        drawCape(library.capeSpritesheets,bufferSize/2,-100,false,capeBuffer,p)

        -- Then draw that to the screen (but cut off if going through a pipe)
        local position = getPosition(p)-(bufferSize/2)
        local priority = getCapePriority(p)

        local sourcePosition = vector.zero2
        local sourceSize = vector(capeBuffer.width,capeBuffer.height)


        if p.forcedState == 3 then
            local warp = Warp(p:mem(0x15E,FIELD_WORD)-1)

            if p.forcedTimer == 0 then
                local warpPosition = vector(warp.entranceX    ,warp.entranceY     )
                local warpSize     = vector(warp.entranceWidth,warp.entranceHeight)

                position,sourcePosition,sourceSize = pipeCutoffRules[warp:mem(0x80,FIELD_WORD)](position,sourcePosition,sourceSize,warpPosition,warpSize)
            elseif p.forcedTimer == 2 then
                local warpPosition = vector(warp.exitX    ,warp.exitY     )
                local warpSize     = vector(warp.exitWidth,warp.exitHeight)

                position,sourcePosition,sourceSize = pipeCutoffRules[warp:mem(0x82,FIELD_WORD)](position,sourcePosition,sourceSize,warpPosition,warpSize)
            elseif p.forcedTimer == 1 or p.forcedTimer >= 100 then
                sourceSize = vector.zero2
            end            
        end

        
        local x1 = ((sourcePosition.x             )/capeBuffer.width )
        local x2 = ((sourcePosition.x+sourceSize.x)/capeBuffer.width )
        local y1 = ((sourcePosition.y             )/capeBuffer.height)
        local y2 = ((sourcePosition.y+sourceSize.y)/capeBuffer.height)

        Graphics.drawBox{
            texture = capeBuffer,priority = priority,sceneCoords = true,
            x = position.x,y = position.y,width = sourceSize.x,height = sourceSize.y,
            textureCoords = {
                x1,y1,
                x2,y1,
                x2,y2,
                x1,y2,
            },
        }
    end
end


-- Camera stuff
do
    apt.cameraY = nil
    apt.cameraMovementStartSection = nil

    function apt.onCameraUpdate()
		local p = player
        if apt.cameraMovementStartSection ~= nil and apt.cameraMovementStartSection ~= p.section then
            -- Stop the custom camera stuff if the player changed sections
            apt.cameraY = nil
            apt.cameraMovementStartSection = nil
        elseif apt.flyingState[p.idx] ~= nil and not apt.flightSettings.normalFlyingCamera and Player.count() <= 1 then
            -- Stop the camera from going higher during flight
            if apt.cameraY == nil then
                apt.cameraY = camera.y
                apt.cameraMovementStartSection = p.section
            end

            apt.cameraY = math.max(apt.cameraY,p.y+p.height-(camera.height/2))
        elseif apt.cameraY ~= nil then
            -- Return the camera to its normal position
            local distance = (camera.y-apt.cameraY)

            apt.cameraY = apt.cameraY+(math.sign(distance)*math.min(math.abs(distance),12))

            if apt.cameraY == camera.y then
                apt.cameraY = nil
                apt.cameraMovementStartSection = nil
            end
        end


        if apt.cameraY ~= nil then
            local bounds = p.sectionObj.boundary
            apt.cameraY = math.clamp(apt.cameraY,bounds.top,bounds.bottom-camera.height)

            camera.y = apt.cameraY
        end

        -- Custom screenshake effect
        if apt.screenShake > 0 then
            apt.screenShake = apt.screenShake - 1

            camera.renderY = (apt.screenShake*((math.sign(apt.screenShake%2)*2)-1))
        end
    end
end

do
    local function dropItem(id)
        if isOverworld then return end

        if Graphics.getHUDType(player.character) == Graphics.HUD_ITEMBOX then
            player.reservePowerup = id
        else
            local config = NPC.config[id]
            local npc = NPC.spawn(id,camera.x+(camera.width/2)-(config.width/2),camera.y+32,player.section)

            npc:mem(0x138,FIELD_WORD,2)
        end
    end

    function apt.register(library)
        -- Cheats
        if library.cheats ~= nil and Cheats ~= nil and Cheats.register ~= nil then
            local aliases = table.iclone(library.cheats)
            table.remove(aliases,1)

            Cheats.register(library.cheats[1],{
                onActivate = (function() 
                    dropItem(library.items[1])
                    return true
                end),
                activateSFX = 12,
                aliases = aliases,
            })
        end
    end
end

-- Tools
--[[do
    function _G.convertSMWFrameCount(value)
        return (value/60)*Misc.GetEngineTPS()
    end
    function _G.convertSMWSpeed(value,accountForDoubleSize,accountForFramerate)
        if accountForDoubleSize == nil then
            accountForDoubleSize = true
        end
        if accountForFramerate == nil then
            accountForFramerate = true
        end


        local inHex = bit.tohex(value)
        --inHex = inHex:sub(inHex:find("[^0]"),#inHex)
        inHex = inHex:sub(5,#inHex)

        local blocks       = tonumber("0x".. inHex:sub(1,1))
        local pixels       = tonumber("0x".. inHex:sub(2,2))
        local subpixels    = tonumber("0x".. inHex:sub(3,3))
        local subsubpixels = tonumber("0x".. inHex:sub(4,4))

        local final = (blocks*16)+(pixels)+(subpixels/16)+(subsubpixels/256)

        if accountForDoubleSize then
            final = final*2
        end
        if accountForFramerate then
            final = (final/Misc.GetEngineTPS())*60
        end


        return final
    end
end]]



-- SETTINGS

local defaults = {
	runTime = 35,
	runFrames = {16,17,18,19,19},
	normalFrames = {1 ,2 ,3 ,4 ,5 },
	flightFrames = {37,38,39,47,48,49},
}


apt.slowFallSettings = {
    -- How fast the player falls when holding jump.
    speed = 1.872,
}

apt.spinAttackSettings = {
    -- The series of frames used when doing a spin attack. Note that this will loop until the attack is over.
    frames = {11},
    -- How many frames it takes to complete a full spin attack.
    length = 18,
    -- The width/height of the spin attack's hitbox.
    hitboxSize = vector(72,24),

    -- The sound effect played when using the spin attack.
    sfx = 18,
}

apt.flightSettings = {
    -- How long the player needs to run at full speed in order to get P-Speed.
    neededRunTime = {
		[CHARACTER_MARIO] = 35,
		[CHARACTER_LUIGI] = 40,
		[CHARACTER_PEACH] = 50,
		[CHARACTER_TOAD]  = 50,
		[CHARACTER_LINK]  = 10,
		[CHARACTER_WARIO] = 35,
	},
    
    -- The frames used when running with and without P-Speed. The frames go: walking 1, walking 2, walking 3, jumping, and falling.
    runningFrames = {
		[CHARACTER_MARIO] = defaults.runFrames,
		[CHARACTER_LUIGI] = defaults.runFrames,
		[CHARACTER_PEACH] = defaults.runFrames,
		[CHARACTER_TOAD]  = defaults.runFrames,
		[CHARACTER_LINK]  = defaults.runFrames,
		[CHARACTER_WARIO] = defaults.runFrames,
	},
    normalFrames = {
		[CHARACTER_MARIO] = defaults.normalFrames,
		[CHARACTER_LUIGI] = defaults.normalFrames,
		[CHARACTER_PEACH] = defaults.normalFrames,
		[CHARACTER_TOAD]  = defaults.normalFrames,
		[CHARACTER_LINK]  = defaults.normalFrames,
		[CHARACTER_WARIO] = defaults.normalFrames,
	},

    -- The longest and shortest times that the player can ascend for.
    maximumAscentTime = 84,
    minimumAscentTime = 16,

    -- How fast the player accelerates upwards while ascending.
    ascentAcceleration = -0.351,
    -- The maximum speed the player will move up at while ascending.
    ascentMaxSpeed = -6.552,

    -- How much gravity the player feels while flying. Note that this is multiplied by the current 'flying state'.
    gravity = 0.117,
    -- The maximum downwards Y speed when flying. Note that this is also affected by the current 'flying state'.
    maxDownwardsSpeed = 1.872,
    -- The maximum upwards Y speed when flying.
    maxUpwardsSpeed = -6.552,

    -- How quickly the player accelerates when flying and holding forwards.
    acceleration = 0.47,

    -- How quickly the player changes between states/sprites.
    stateChangeSpeed = 8,
    stateChangeSpeedFast = 2,

    -- The speed that the player gets when "catching air".
    catchAirSpeed = -1.654,
    -- How long the player will be catching air for after pulling back.
    catchAirTime = 3,
    catchAirTimeLong = 12,


    -- The frames used when flying.
    frames = {
		[CHARACTER_MARIO] = defaults.flightFrames,
		[CHARACTER_LUIGI] = defaults.flightFrames,
		[CHARACTER_PEACH] = defaults.flightFrames,
		[CHARACTER_TOAD]  = defaults.flightFrames,
		[CHARACTER_LINK]  = defaults.flightFrames,
		[CHARACTER_WARIO] = defaults.flightFrames,
	},
	
    -- The sound played when catching air.
    catchAirSFX = SFX.open(Misc.resolveSoundFile("powerups/cp_cape_fly")),


    -- The sound played when hit while flying.
    hitSFX = 35,

    -- If true, the camera will not be restricted when flying.
    normalFlyingCamera = false,
}


return apt
