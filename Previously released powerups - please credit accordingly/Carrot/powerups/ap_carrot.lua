--[[
    Carrot for customPowerup.lua 
    -----------------------
    By MegaDood


]]

local carrot = {}

-- Variable "name" is reserved
-- variable "registerItems" is reserved

carrot.basePowerup = PLAYER_FIREFLOWER

carrot.items = {}

carrot.aliases = {"whatsupdoc","fallingwithstyle"}

carrot.forcedStateType = 2

carrot.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

carrot.settings = {
	canSuperJump = true,
}

function carrot.onInitPowerupLib()
	carrot.spritesheets = {
		carrot:registerAsset(1, "mario-ap_carrot.png"),
		carrot:registerAsset(2, "luigi-ap_carrot.png"),
		carrot:registerAsset(3, "peach-ap_carrot.png"),
		carrot:registerAsset(4, "toad-ap_carrot.png"),
		carrot:registerAsset(5, "link-ap_carrot.png"),
	}
	
	carrot.iniFiles = {
		carrot:registerAsset(1, "mario-ap_carrot.ini"),
		carrot:registerAsset(2, "luigi-ap_carrot.ini"),
		carrot:registerAsset(3, "peach-ap_carrot.ini"),
		carrot:registerAsset(4, "toad-ap_carrot.ini"),
		carrot:registerAsset(5, "link-ap_carrot.ini"),
	}
end

--------------------
--Delay before you can hover again
carrot.hoverTimer = 0
carrot.hoverTimerMax = {
    8,
    8,
    8,
    8,
	8
}
--------------------

--Frames that show when the ears flap
local animFrames = {
    11,11,11,11,11,12,12,12,12,12,
}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

-- If you wish to have global onTick etc... functions, you can register them with an alias like so:
-- registerEvent(carrot, "onTick", "onPersistentTick")

local function canHover(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and not p:isUnderwater()
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

-- Runs when player switches to this powerup. Use for setting stuff like global Defines.
function carrot.onEnable(p)
	Effect.spawn(131,p.x,p.y)
	carrot.hoverTimer = 55
end

-- Runs when player switches to this powerup. Use for resetting stuff from onEnable.
function carrot.onDisable(p)
end

local function ducking(p)
    return p:mem(0x12E, FIELD_BOOL)
end

-- Detects if the player is on the ground, the redigit way. Function by MrDoubleA
local function isOnGround(p)
	return (
		p.speedY == 0 -- "on a block"
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local canBigJump = false
local bigJumpTimer = 0
local bigJumpTimerActual = 0

-- No need to register. Runs only when powerup is active.
function carrot.onTickPowerup(p)

	if p.character ~= 5 then
		p:mem(0x160, FIELD_WORD, 2)
	else
		p:mem(0x162, FIELD_WORD, 2)
	end

    carrot.hoverTimer = carrot.hoverTimer - 1
    
	carrot.iniCustom = ""
	
    if not canHover(p) then return end

	--Make the player hover
    if (p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED) and not isOnGround(p) then
		SFX.play(33)
		carrot.hoverTimer = carrot.hoverTimerMax[p.character]
    end
	
	bigJumpTimerActual = bigJumpTimerActual - 1
	
	--Perform a big jump
	if math.abs(p.speedX) > 5.58 and isOnGround(p) and carrot.settings.canSuperJump then
		bigJumpTimer = bigJumpTimer + 1
		if bigJumpTimer >= 34 then
			if bigJumpTimer % 8 == 0 then
				Effect.spawn(10,p.x,p.y)
			end
			bigJumpTimerActual = 24
		end
	else
		if bigJumpTimerActual > 0 and math.abs(p.speedX) > 4 then
			p:mem(0x11C,FIELD_WORD,math.max(p:mem(0x11C,FIELD_WORD),14))
		end
		bigJumpTimer = 0
	end
end

-- No need to register. Runs only when powerup is active.
function carrot.onTickEndPowerup(p)

	if p.character == CHARACTER_PEACH or p.character == CHARACTER_TOAD then
	
		animFrames = {
		47,47,47,47,47,48,48,48,48,48,
		}
	
	end
	
	if animFrames[carrot.hoverTimerMax[p.character] - carrot.hoverTimer] then
		p.speedY = math.min(0.01 - Defines.player_grav, p.speedY)
	else
		--Stuff that keeps the player in the air when hovering
		if not canHover(p) then return end
		if (p.keys.jump == KEYS_DOWN or p.keys.altJump == KEYS_DOWN) and p.speedY > 0 and not isOnGround(p) then
			p.speedY = Defines.player_grav * 1.5 * p.speedY
			if p.mount ~= MOUNT_YOSHI then
				if not ducking(p) and p.holdingNPC == nil and not p:mem(0x50, FIELD_BOOL) then
					if p.character ~= CHARACTER_PEACH and p.character ~= CHARACTER_TOAD then
						p.frame = math.floor((lunatime.tick() / 5) % 2 + 11)
					else
						p.frame = math.floor((lunatime.tick() / 5) % 2 + 48)
					end
				elseif p.holdingNPC ~= nil then
					if not ducking(p) and (p.character == CHARACTER_PEACH or p.character == CHARACTER_TOAD) then
						p.frame = math.floor((lunatime.tick() / 5) % 2 + 46)
					end
				end
			else
				p.frame = math.floor((lunatime.tick() / 5) % 2 + 48)
			end
		end
	end
	if animFrames[carrot.hoverTimerMax[p.character] - carrot.hoverTimer] then	
		if p.mount ~= MOUNT_YOSHI then
			if not ducking(p) and p.holdingNPC == nil and not p:mem(0x50, FIELD_BOOL) then
				p.frame = animFrames[carrot.hoverTimerMax[p.character] - carrot.hoverTimer]
			elseif p.holdingNPC ~= nil then
				if not ducking(p) and (p.character == CHARACTER_PEACH or p.character == CHARACTER_TOAD) then
					p.frame = math.floor((lunatime.tick() / 5) % 2 + 46)
				end
			end
		else
			p.frame = math.floor((lunatime.tick() / 5) % 2 + 48)
		end
	end
	
end

return carrot