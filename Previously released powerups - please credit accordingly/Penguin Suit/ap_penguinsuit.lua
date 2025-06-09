--[[

	Penguin Suit
	by Cpt. Mono
	
	Credits:
	SMB3 Penguin Mario: Shikaternia (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=23949)
	SMW Penguin Mario, Luigi, Toad, and Toadette: Nintendo, GlacialSiren484, AwesomeZack, MauricioN64, Jamestendo64, LinkStormZ, and TheMushRunt (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/161073/)
	MrDoubleA for creating stuff that I could learn general workflow and take bits and bobs from. If it wasn't for his work, I would've never been able to gain the knowledge I needed to finish this.
	Enjl for allowing me to modify playerphysicspatch.lua to make the Penguin Suit immune to ice.
	
	I did it! I finally did it! The Penguin Suit is here!
	
	So, yeah. Let's just say that the Penguin Suit was much, much harder than the Super Acorn. I had to do things like learn how to use sprite rotation,
	overwrite hardcoded speed limits, and, worst of all, figure out slopes. They're... a lot harder to deal with than you might think. Anyways, I'm just glad
	to be done. Seriously, I put my heart and soul into this. Admittedly, there are some more things I'd like to add, but I'm already exhausted as-is, and
	I desperately need a break.
	
	Oh, and if you want to modify, use, or reuse anything that's here, go for it! Just give me credit if you can help it. All I ask is that you don't claim it entirely your own.
	
	Enjoy!
]]
-- Variable "name" is reserved
-- variable "registerItems" is reserved

local playerManager = require("playerManager")

local characterList = {"mario", "luigi", "peach", "toad", "link"}
local penguinDanceStep = 0 --To do the penguin dance, as SMM2 Mario, just press up and down a couple of times. It's fun!

local apt = {}

apt.spritesheets = {
    Graphics.sprites.mario[7].img,
    Graphics.sprites.luigi[7].img,
    Graphics.sprites.peach[7].img,
    Graphics.sprites.toad[7].img,
    Graphics.sprites.link[7].img
}

apt.iniFiles = {
	Misc.resolveFile("mario-ap_penguinsuit.ini"),
	Misc.resolveFile("luigi-ap_penguinsuit.ini"),
	Misc.resolveFile("toad-ap_penguinsuit.ini"),
	Misc.resolveFile("toad-ap_penguinsuit.ini"),
}

apt.basePowerup = PLAYER_ICEFLOWER
apt.items = {}
apt.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

registerEvent(apt, "onExit", "onExit")

function apt.onExit()
	for _,p in ipairs(Player.get()) do
		p.data.keepYPositionForSuit = nil
	end
end

apt.aliases = {"pingu","flightlessbird"}

apt.penguinSettings = {
	slideConstant = 1.5, --A constant used to determine how much you speed up upon starting to slide.
	slopeConstant = 0.1, --A constant used to determine your acceleration down and up slopes.
	waterAccelerationConstant = 1.5,
	waterDecelerationConstant = 0.25,
	slideMinimumSpeed = 3,
	--{Idle, Idle2, Horizontal1, Horizontal2, Horizontal3, Up1, Up2, Up3, Down1, Down2, Down3, HoldIdle1, HoldIdle2, HoldSwim1, HoldSwim2, HoldSwim3}
	normalFrameList = {28, 28, 29, 27, 28, 34, 32, 33, 35, 36, 37, 28, 28, 29, 27, 28},
	SMM2FrameList = {20, 39, 40, 43, 20, 56, 67, 58, 59, 60, 61, 62, 63, 64, 65, 62},
	animationList = {
		["swimIdle"] = {1, 2, frameDelay = 12},
		["swimHorizontal"] = {4, 3, 4, 5, 5, 5, 5, 5, 5, frameDelay = 4},
		["swimUp"] = {7, 6, 7, 8, 8, 8, 8, 8, 8, frameDelay = 4},
		["swimDown"] = {10, 9, 10, 11, 11, 11, 11, 11, 11, frameDelay = 4},
		["swimHold"] = {15, 14, 15, 16, 16, 16, 16, 16, 16, frameDelay = 4},
		["swimIdleHold"] = {12, 13, frameDelay = 12},
		["swimShoot"] = {3, 4, 4, frameDelay = 4},
		["penguinDanceOld"] = {68, -69, 68, 69, frameDelay = 6},
		["penguinDance"] = {68, 68, -69, -69, 68, 68, 69, 69, 68, 69, 70, 71, -70, -70, 71, 71, 70, 70, 71, -70, -69, 68, 68,
							74, 74, 83, 83, 82, 82, -82, -82, -83, -83, -74, -74, 74, 74, 83, 83, 82, 82, -82, -82, -83, -83,
							-74, -74, 74, 74, 68, 75, 75, 68, 68, 75, 75, 68, 76, 76, 87, 87, 76, 76, 68, 75, 75, 68, 68, 75,
							75, 68, -76, -76, -87, -87, -76, -76, 68, 75, 75, 68, 68, 75, 75, 68, 78, 99, 99, 99, 78, 68, 75,
							75, 68, 68, 75, 75, 68, -78, -99, -99, -99, -78, frameDelay = 4},
		},
	slideOffsets = {
		["SMM2-MARIO"] = 2,
		["SMM2-LUIGI"] = 3,
		["SMM2-TOAD"] = 1,
		["SMM2-TOADETTE"] = 1,
		["SMM2-YELLOWTOAD"] = 1,
		["mario"] = 4,
		["luigi"] = 0,
		["toad"] = 0,
		["peach"] = 0,
		["link"] = 0,
		},
	}

local function canShoot()
    return (
        (apt.projectileTimer <= 0 or apt.projectileTimer2 <= 0) and
		apt.kickTimer <= 0 and
        player.forcedState == 0 and
        player:mem(0x40, FIELD_WORD) == 0 and --climbing
        player.mount < 2 and
        player.holdingNPC == nil and
        player.deathTimer == 0 and
        player:mem(0x0C, FIELD_BOOL) == false and -- fairy
		not sliding and
		not player:mem(0x3C, FIELD_BOOL) and
		penguinDanceStep < 16
    )
end

local function canSlide()
	return (
		apt.kickTimer <= 0 and
		player.forcedState == 0 and
		player:isOnGround() and
		player.mount == 0 and
		player:mem(0x36, FIELD_WORD) == 0 and
		player.deathTimer == 0 and
		(player.speedX ~= 0 or player:mem(0x48, FIELD_WORD) ~= 0) and
		not player.holdingNPC and
		penguinDanceStep < 16
	)
end

local function canDance()
	return (
		player:getCostume() == "SMM2-MARIO" and
		apt.kickTimer <= 0 and
		player.forcedState == 0 and
		player.mount == 0 and
		player:isOnGround() and
		player.deathTimer == 0 and
		player.speedX == 0 and
		not sliding and
		not player.holdingNPC
	)
end

local function ducking()
    return player:mem(0x12E, FIELD_BOOL)
end

local function timerResetCheck(v)
	if v == apt.projectileWatcher then
		apt.projectileTimer = 0
	elseif v == apt.projectileWatcher2 then
		apt.projectileTimer2 = 0
	end
end

local function stopSlideCheck()
	local boxHeight = 24
	if Block.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) ~= nil then
		for _,currentBlock in Block.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) do
			if table.icontains(Block.SOLID, currentBlock.id) then
				return true
			end
		end
	end
	return false
end

local altFrames = false
local sliding = false
local slidespeed = 0
local slidedirection = 1
local SMM2Costumes = {"SMM2-MARIO", "SMM2-LUIGI", "SMM2-TOAD", "SMM2-TOADETTE", "SMM2-YELLOWTOAD"}
local defaultHeight = 0
local oldSlope = 0
local previousY = 0
local absoluteYSpeed = 0
local storedWalkSpeed = 3
local lastXSpeed

apt.items = {801} -- Items that can be collected.
apt.iniCustom = nil
--Here's a bunch of functions that I'm gonna use! Totally didn't take the idea of "Convenience Functions" from MrDoubleA or anything.

local currentBlock = nil
local blockHeight = 1
local blockWidth = 1

local animationData = {}

-- Runs when player switches to this powerup. Use for setting stuff like global Defines.
function apt.onEnable(player)
	player:mem(0x46, FIELD_WORD, 801)
	--apt.spritesheets[player.character] = Graphics.loadImage(Misc.resolveFile(characterList[player.character].."-ap_penguinsuit.png"))
	local playerSettings = player:getCurrentPlayerSetting()
	defaultHeight = playerSettings.hitboxHeight
end

-- Runs when player switches from this powerup. Use for resetting stuff from onEnable.
function apt.onDisable(player)
	sliding = false
	player.speedX = player.speedX - 1*math.sign(player.speedX)
	if stopSlideCheck() then
		player.keys.down = true
	end
	player.data.keepYPositionForSuit = nil
end

registerEvent(apt, "onInputUpdate", "onInputUpdate")
registerEvent(apt, "onPlayerKill", "onPlayerKill")
registerEvent(apt, "onTick", "onPersistentTick")
registerEvent(apt, "onPostNPCKill", "onPostNPCKill")
registerEvent(apt, "onPlayerHarm", "onPlayerHarm")

function apt.onPostNPCKill(killedNPC, harmType)
	timerResetCheck(killedNPC)
end

function apt.onPlayerHarm(eventToken, harmedPlayer)
	if sliding then
		for _,v in ipairs(NPC.getIntersecting(harmedPlayer.x, harmedPlayer.y, harmedPlayer.x+harmedPlayer.width,harmedPlayer.y+harmedPlayer.height)) do
			v:harm(HARM_TYPE_NPC)
		end
		eventToken.cancelled = true
	end	
end

-- If you wish to have global onTick etc... functions, you can register them with an alias like so:
-- registerEvent(apt, "onTick", "onPersistentTick")
-- No need to register. Runs only when powerup is active.

local previousCostume

apt.projectileTimer = 0
apt.projectileTimer2 = 0
apt.projectileWatcher = 0
apt.projectileWatcher2 = 0
apt.kickTimer = 0
local animationTimer = 1
apt.projectileTimerMax = 100
--------------------

local animFrames = {
    11,11,11,11,11,11,11,11,
}

function apt.onPersistentTick()
	if table.ifind(SMM2Costumes, player:getCostume()) and Misc.resolveFile(player:getCostume().."-ap_penguinsuit.png") then
		if lunatime.tick() == 1 or player:getCostume() ~= previousCostume then
			if altFrames then
				apt.spritesheets[player.character] = Graphics.loadImage(Misc.resolveFile(player:getCostume().."-ap_penguinsuitb.png"))
			else
				apt.spritesheets[player.character] = Graphics.loadImage(Misc.resolveFile(player:getCostume().."-ap_penguinsuit.png"))
			end
		end
	else
		apt.spritesheets[player.character] = Graphics.loadImage(Misc.resolveFile(characterList[player.character].."-ap_penguinsuit.png"))
	end
	previousCostume = player:getCostume()
end

local floatTimer = 0
local floatSlope = 0
local wasSwimming = false
local swimSpeedY = 0

--These two functions are taken from my SMM2 playables.
local function checkBlockAbove(player,speed)
	local boxHeight = (speed)
	if Block.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) ~= nil then
		for _,currentBlock in Block.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) do
			if table.icontains(Block.SOLID, currentBlock.id) then
				return true
			end
		end
	end
	for _,currentNPC in NPC.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) do
		if NPC.config[currentNPC.id].playerblock and currentNPC ~= player.holdingNPC then
			return true
		end
	end
	return false
end
local function checkBlockBelow(player,speed)
	local boxHeight = (speed)
	if Block.iterateIntersecting(player.x, player.y+player.height, player.x+player.width, player.y+player.height+speed) ~= nil then
		for _,currentBlock in Block.iterateIntersecting(player.x, player.y-boxHeight, player.x+player.width, player.y) do
			if table.icontains(Block.SOLID, currentBlock.id) then
				return true
			end
		end
	end
	for _,currentNPC in NPC.iterateIntersecting(player.x, player.y+player.height, player.x+player.width, player.y+player.height+speed) do
		if NPC.config[currentNPC.id].playerblock and currentNPC ~= player.holdingNPC then
			return true
		end
	end
	return false
end

local function handleSwimCrouch(player)
	local entranceList = Warp.getIntersectingEntrance(player.x, player.y, player.x+player.width, player.y+player.height)
	for k,v in ipairs(entranceList) do
		if not v.locked and v.warpType == 1 and v.entranceDirection == 3 and mem(0x00B251E0, FIELD_WORD) >= v.starsRequired then
			return
		end
	end
	local exitList = Warp.getIntersectingExit(player.x, player.y, player.x+player.width, player.y+player.height)
	for k,v in ipairs(exitList) do
		if not v.locked and v.warpType == 1 and v.exitDirection == 1 and mem(0x00B251E0, FIELD_WORD) >= v.starsRequired then
			return
		end
	end
	player.keys.down = false
	return
end

local swimQueuedJump = -1

-- runs when the powerup is active, passes the player
function apt.onTickPowerup(p)
	--local currentSlope
	--local previousY = previousY or p.y or 0
	
	--[[if p:mem(0x48, FIELD_WORD) ~= 0 and p:isOnGround() then
		local blockTable = Block.get()
		local currentOnTickBlock = blockTable[p:mem(0x48, FIELD_WORD)]
		currentSlope = Block.config[currentOnTickBlock.id].floorslope*(Block.config[currentOnTickBlock.id].height/Block.config[currentOnTickBlock.id].width) or 0
	else
		currentSlope = 0
	end]]
p:mem(0x160, FIELD_WORD, 2)
	
    apt.projectileTimer = apt.projectileTimer - 1
	apt.projectileTimer2 = apt.projectileTimer2 - 1
	apt.kickTimer = apt.kickTimer - 1
	
    if heldNPC ~= nil and p.holdingNPC == nil then
		apt.kickTimer = 16
	end
	
	heldNPC = p.holdingNPC
	
    if canShoot() then
		
		if (p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED) and not sliding and Level.endState() == 0 then
			if p.keys.altRun == KEYS_PRESSED and (p.character == 3 or p.character == 4) then
				if not ducking() and p.mount < 2 then
					local v = NPC.spawn(265, p.x, p.y - 800, p.section)
					v.ai1 = p.character
					p:mem(0x154, FIELD_WORD, v.idx+1)
					p:mem(0x62, FIELD_WORD, 42)
					SFX.play(18)
					if apt.projectileTimer <= 0 then
						apt.projectileTimer = apt.projectileTimerMax
						apt.projectileWatcher = v
					else
						apt.projectileTimer2 = apt.projectileTimerMax
						apt.projectileWatcher2 = v
					end
					p:mem(0x118,FIELD_FLOAT,110)
				end
			else
				local v
				if not ducking() then
					local yOffset
					local xOffset
					if p:mem(0x36, FIELD_BOOL) then
						xOffset = p.width + 4
						yOffset = 20
					else
						xOffset = p.width
						yOffset = p.height/2
					end
					v = NPC.spawn(265, p.x + 0.5 * xOffset + 0.5 * xOffset * p.direction, p.y + yOffset, p.section, false, true)
					v.speedY = 4
					if p.keys.up then
						local speedYMod = p.speedY * 0.1
						if p.standingNPC then
							speedYMod = p.standingNPC.speedY * 0.1
						end
						v.speedY = -8 + speedYMod
					end
					SFX.play(18)
					p:mem(0x118,FIELD_FLOAT,110)
				end
				if v then
					v.ai1 = p.character
					v.speedX = 4 * p.direction + 0.1 * p.speedX * 0.9
					if apt.projectileTimer <= 0 then
						apt.projectileTimer = apt.projectileTimerMax
						apt.projectileWatcher = v
					else
						apt.projectileTimer2 = apt.projectileTimerMax
						apt.projectileWatcher2 = v
					end
				end
			end
		end
	end
	
	if (not sliding and canSlide() and p.keys.down == KEYS_PRESSED) and math.abs(p.speedX) >= apt.penguinSettings.slideMinimumSpeed then
		sliding = true
		p.speedX = p.speedX + math.sign(p.speedX)*apt.penguinSettings.slideConstant
		slidespeed = p.speedX
		wasOnGround = true
		currentSlope = 0
		oldSlope = 0
	end
	
	if (p.forcedState ~= 0 or p.keys.up or (p:mem(0x148, FIELD_WORD) ~= 0 or p:mem(0x14C, FIELD_WORD) ~= 0)) and sliding then
		sliding = false
		p.speedX = p.speedX - 1*math.sign(p.speedX)
		if stopSlideCheck() then
			p.keys.down = true
		end
	end
	
	if p:mem(0x36, FIELD_BOOL) and p.mount == 0 then
		local liquid = Liquid.getIntersecting(p.x, p.y, p.x+p.width, p.y+p.height)
		if #liquid == 0 and not Section(p.section).isUnderwater then
			p:mem(0x36, FIELD_BOOL, false)
		elseif sliding then
			local liquidY
			for k,v in ipairs(liquid) do
				if not liquidY or v.y < liquidY then
					liquidY = v.y
				end
			end
			if p.y < liquidY then
				p.y = liquidY - p.height + Defines.player_grav
				p.speedY = -Defines.player_grav
				if p.keys.jump == KEYS_PRESSED then
					swimQueuedJump = 3
				end
			else
			sliding = false
			end
		else
			if not p.data.frogOrPenguinSuitDisableWater then
				p.speedY = p.speedY-(Defines.player_grav/10)
				if Level.endState() == 0 then
					local swimspeed
					if p.keys.run or p.keys.altRun then
						--swimspeed = Defines.player_runspeed
						swimspeed = 5
					else
						--swimspeed = Defines.player_walkspeed
						swimspeed = 2.5
					end
				
					if p.keys.right then
						p.speedX = math.min(p.speedX+apt.penguinSettings.waterAccelerationConstant,swimspeed)
					elseif p.keys.left then
						p.speedX = math.max(p.speedX-apt.penguinSettings.waterAccelerationConstant,-swimspeed)
					elseif p.keys.up or p.keys.down then
						if p.speedX > 0 then
							p.speedX = math.max(0, p.speedX-apt.penguinSettings.waterAccelerationConstant)
						else
							p.speedX = math.min(0, p.speedX+apt.penguinSettings.waterAccelerationConstant)
						end
					elseif p.speedX > 0 then
						p.speedX = math.max(0, p.speedX-apt.penguinSettings.waterDecelerationConstant)
					else
						p.speedX = math.min(0, p.speedX+apt.penguinSettings.waterDecelerationConstant)
					end
				
					if p.keys.up and p:mem(0x14A, FIELD_WORD) == 0 then
						swimSpeedY = math.max(swimSpeedY-apt.penguinSettings.waterAccelerationConstant,-swimspeed)
					elseif p.keys.down then
						swimSpeedY = math.min(swimSpeedY+apt.penguinSettings.waterAccelerationConstant,swimspeed)
					elseif p.keys.right or p.keys.left then
						if swimSpeedY > 0 then
							swimSpeedY = math.max(0, swimSpeedY-apt.penguinSettings.waterAccelerationConstant)
						else
							swimSpeedY = math.min(0, swimSpeedY+apt.penguinSettings.waterAccelerationConstant)
						end
					elseif swimSpeedY > 0 then
						swimSpeedY = math.max(0, swimSpeedY-apt.penguinSettings.waterDecelerationConstant)
					else
						swimSpeedY = math.min(0, swimSpeedY+apt.penguinSettings.waterDecelerationConstant)
					end
				
					p.speedY = swimSpeedY-(Defines.player_grav/10)
					p:mem(0x38, FIELD_WORD, 2)
					if p:mem(0x14E, FIELD_WORD) > 0 then	
						p.keys.down = false
					elseif (p.keys.down == KEYS_DOWN or p.keys.down == KEYS_PRESSED) and p:isOnGround() and p.holdingNPC ~= nil and (p.keys.run == KEYS_DOWN or p.keys.altRun == KEYS_DOWN) then
						handleSwimCrouch(p)
					end
				else
					if not p.data.keepYPositionForSuit then
						p.data.keepYPositionForSuit = p.y
					else
						p.y = p.data.keepYPositionForSuit
					end
				end
			end
		end
	elseif wasSwimming then
		Defines.player_runspeed = Defines.player_runspeed/2
		Defines.player_walkspeed = Defines.player_walkspeed/2
		wasSwimming = false
	end
	
	if sliding then
		if math.sign(p.speedX) == math.sign(slidespeed)*-1 then
			slidespeed = slidespeed*-1
		end
		
		
		
		p.speedX = slidespeed
		p.keys.down = false
		p.keys.left = false
		p.keys.right = false
		p.keys.run = false
		apt.iniCustom = "slide"
		local slideHitBox
		if p.direction == DIR_RIGHT then
			slideHitBox = p.x + p.width
		else
			slideHitBox = p.x + slidespeed
		end
		for k,v in Block.iterateIntersecting(slideHitBox, p.y, slideHitBox+math.abs(slidespeed), p.y+p.height) do
			--local hasStopped = false
			if not v.isHidden then
				if Block.MEGA_SMASH_MAP[v.id] and v.contentID == 0 then
					v:remove(true)
				elseif Block.SOLID_MAP[v.id] or Block.PLAYERSOLID_MAP[v.id] then
					v:hit(false, p)
					--[[if Block.SOLID[v.id] and not Block.SIZEABLE[v.id] and Block.MEGA_SMASH_MAP[v.id] and not hasStopped and false then
						p:mem(0x3C, FIELD_BOOL, false)
						apt.iniCustom = nil
						sliding = false
						Defines.player_runspeed = Defines.player_runspeed-apt.penguinSettings.slideConstant
						p.speedX = 0
						hasStopped = true
					end]]
				end
			end
		end
		if floatTimer > 0 then
			p.speedY = p.speedX*floatSlope
			floatTimer = floatTimer - 1
		end
		swimQueuedJump = swimQueuedJump - 1
		if swimQueuedJump == 0 then
			p:mem(0x11C, FIELD_WORD, 20)
		end
	else
		p:mem(0x3C, FIELD_BOOL, false)
		apt.iniCustom = nil
	end
	

	--Based off of Enjl's playerphysicspath.lua. Doesn't account for slopes yet.
	if not sliding and p:mem(0x0A, FIELD_BOOL) or (p.standingNPC and p.standingNPC.isValid and p.standingNPC.speedX == 0 and p.standingNPC.id == 263) then
			lastXSpeed = lastXSpeed or 0
			local xspeeddiff = p.speedX - lastXSpeed
            if not p:mem(0x3C, FIELD_BOOL) then
				local signChange = false
                if (not (p:isGroundTouching() and p:mem(0x12E, FIELD_BOOL))) then
                    if p.rightKeyPressing then
                        if p.speedX < 0 then
                            p.speedX = p.speedX + 0.21
							if p.speedX > 0 then
								signChange = true
							end
                        end
                    elseif p.leftKeyPressing then
                        if  p.speedX > 0 then
                            p.speedX = p.speedX - 0.21
							if p.speedX < 0 then
								signChange = true
							end
                        end
                    else
						p.speedX = p.speedX + xspeeddiff * 3
					end
                
            
					xspeeddiff = p.speedX - lastXSpeed

					if not signChange and not (p:mem(0x14C, FIELD_WORD) == 2 or p:mem(0x148, FIELD_WORD) == 2) and (p.keys.left or p.keys.right) and math.sign(p.speedX * xspeeddiff) == 1 and math.abs(p.speedX) < Defines.player_runspeed then
						p.speedX = p.speedX + xspeeddiff * 3
					end
				end
            end
    end
	
	if canDance() then
		if penguinDanceStep < 15 then
			if (penguinDanceStep % 2 == 0 and p.keys.up == KEYS_PRESSED) or (penguinDanceStep % 2 == 1 and p.keys.down == KEYS_PRESSED) then
			--if p.keys.up == KEYS_PRESSED then
				penguinDanceStep = penguinDanceStep + 1
			end
		else
			if penguinDanceStep == 15 and p.keys.down then
				penguinDanceStep = 16
				oldAnimation = "penguinDance"
				animationTimer = 1
			end
			p.keys.down = false
		end
	else
		penguinDanceStep = 0
	end
	
	lastXSpeed = p.speedX
end

-- runs when the powerup is active, passes the player
function apt.onTickEndPowerup(p)
	currentSlope = currentSlope or 0
	
	if p:mem(0x3C, FIELD_BOOL) and canSlide() then
		sliding = true
		--p.speedX = p.speedX + math.sign(p.speedX)*apt.penguinSettings.slideConstant
		slidespeed = p.speedX
		wasOnGround = true
		currentSlope = 0
		oldSlope = 0
		p:mem(0x3C, FIELD_BOOL, false)
	end
	
	for _,v in NPC.iterate(265,p.section) do --Stolen from ATWE by MrDoubleA. Just kills iceballs that are offscreen.
        if v.spawnId <= 0 then
            if not (v.x+v.width > camera.x and v.x < camera.x+camera.width and v.y+v.height > camera.y and v.y < camera.y+camera.height) then
                v:kill(HARM_TYPE_VANISH)
				timerResetCheck(v)
            end
        end
    end
	
	if p:mem(0x48, FIELD_WORD) ~= 0 then
		local blockTable = Block.get()
		currentBlock = blockTable[p:mem(0x48, FIELD_WORD)]
			
		_,blockHeight,blockWidth = Graphics.getPixelData(Graphics.sprites.block[currentBlock.id].img)
		blockHeight = Block.config[currentBlock.id].height or blockHeight
		blockWidth = Block.config[currentBlock.id].width or blockWidth
			
		currentSlope = Block.config[currentBlock.id].floorslope*(Block.config[currentBlock.id].height/Block.config[currentBlock.id].width)
		slidespeed = math.max(-(Defines.player_runspeed+apt.penguinSettings.slideConstant),(math.min(Defines.player_runspeed+apt.penguinSettings.slideConstant, slidespeed+apt.penguinSettings.slopeConstant*currentSlope)))
		--Make sure to optimize this ugh
		if p.y == previousY then
			currentSlope = 0
		end
	else
		currentSlope = 0
	end
	
	if sliding then
		
		if oldSlope*p.direction < currentSlope*p.direction and p:mem(0x3A, FIELD_WORD) == 0 and p:isOnGround() then
			--p.speedY = math.min(p.speedY,p.y - previousY)
			floatSlope = oldSlope
			floatTimer = ((p.speedX*floatSlope)*8/mem(0x00B2C6E8, FIELD_FLOAT))
		end
		
		p.speedX = slidespeed
		
		if math.sign(p.direction) == math.sign(slidespeed)*-1 then
			p.direction = math.sign(slidespeed)
		end
		
		if not p.isOnGround then
			p:mem(0x3C, FIELD_BOOL, false)
		end
	end
	
	if p.forcedState ~= 0 and sliding then
		sliding = false
	end
	
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
	oldSlope = currentSlope
end

local rotation = 0
local rotationtimer = 0
local rotationrate = 3.75
local currentAnimation = "swimIdle"
local oldAnimation = "swimIdle"
local swimSoundPlayed = false
local frametodisplay = 0

-- runs when the powerup is active, passes the player
function apt.onDrawPowerup(p)
   if p.forcedState == 0 then
   
		if penguinDanceStep == 16 then
			local animationData = apt.penguinSettings.animationList.penguinDance
			
			if (animationTimer/2) >= #animationData*animationData.frameDelay then
				animationTimer = 1
			end
			
			local frame = math.ceil((animationTimer/2)/animationData.frameDelay)
			
			p.frame = animationData[frame]
			frametodisplay = animationData[frame]
			
			if not Misc.isPaused() then
			
				if p:mem(0x36, FIELD_BOOL) then
					animationTimer = animationTimer + 1
				else
					animationTimer = animationTimer + 2
				end
				
			end
		
		elseif penguinDanceStep > 8 then
		
			if p.frame == 1 then
				p.frame = -69
			elseif p.frame == 32 then
				p.frame = 84
			end
			
		elseif sliding then
			--p.frame = 24
			--if p:mem(0x3C, FIELD_BOOL) then
			p.frame = 0
			
			rotationtimer = rotationtimer - 1
			if p:mem(0x48, FIELD_WORD) ~= 0 and p.y ~= previousY then
				--rotation = math.deg(math.atan(blockHeight/blockWidth)*math.sign(Block.config[currentBlock.id].floorslope))
				rotation = math.deg(math.atan(blockHeight/blockWidth)*math.sign(Block.config[currentBlock.id].floorslope))
			elseif floatTimer > 0 then
				rotation = math.deg(math.atan(floatSlope))
			elseif not p:isGroundTouching() and p:mem(0x11C, FIELD_WORD) == 0 then
				if rotation > 0 then 
					rotation = math.max(rotation - rotationrate, 0)
				else
					rotation = math.min(rotation + rotationrate, 0)
				end
			else
				rotation = 0
			end
			
			local ps = p:getCurrentPlayerSetting()
			
			local playerCostume
			
			if p:getCostume() then
				playerCostume = p:getCostume()
			else
				playerCostume = characterList[p.character]
			end
			
			local slideTexture = Graphics.loadImage(Misc.resolveFile(playerCostume.."-ap_penguinsuitslide.png"))
			local _,imagewidth,imageheight = Graphics.getPixelData(slideTexture)
			local y
			local yOffset = apt.penguinSettings.slideOffsets[p:getCostume()] or apt.penguinSettings.slideOffsets[characterList[p.character]]
			
			if p:mem(0x12E, FIELD_BOOL) then 
				y = p.y + p.height/2 - yOffset
			else
				y = p.y + p.height - ps.hitboxDuckHeight/2 - yOffset
			end

			Graphics.drawBox{x = p.x + p.width/2, y = y, texture = slideTexture,
			width = imagewidth*p.direction, height = imageheight, sourceHeight = imageheight, sourceWidth = imagewidth, sceneCoords = true,
			sourceX = 0, sourceY = 0, centered = true, color = Color.white, priority = -25, rotation = rotation}
			--end
		elseif p:mem(0x36, FIELD_BOOL) and p.mount == 0 then
			if not p.data.frogOrPenguinSuitDisableWater then
				if not Misc.isPaused() then

					if p.holdingNPC ~= nil then
						if p.keys.left or p.keys.right or p.keys.up or p.keys.down then
							currentAnimation = "swimHold"
						else
							currentAnimation = "swimIdleHold"
						end
					elseif p:mem(0x118,FIELD_FLOAT) >= 110 then
						currentAnimation = "swimShoot"
					elseif p.keys.left or p.keys.right then
						currentAnimation = "swimHorizontal"
					elseif p.keys.up then
						currentAnimation = "swimUp"
					elseif p.keys.down then
						currentAnimation = "swimDown"
					else
						currentAnimation = "swimIdle"
					end
					
				end
				
				if currentAnimation ~= oldAnimation then
					oldAnimation = currentAnimation
					animationTimer = 1
					swimSoundPlayed = false
				end
				
				local animationData = apt.penguinSettings.animationList[currentAnimation]
				
				frametodisplay = #animationData
				if animationTimer >= #animationData*animationData.frameDelay then
					animationTimer = 1
					swimSoundPlayed = false
				end
				
				local frame = math.ceil(animationTimer/animationData.frameDelay)
				local frameList
				
				if table.ifind(SMM2Costumes, p:getCostume()) then
					frameList = apt.penguinSettings.SMM2FrameList
				else
					frameList = apt.penguinSettings.normalFrameList
				end
				
				local frameIndex = animationData[frame]
				p.frame = frameList[frameIndex]
				
				if frame == 4 and not swimSoundPlayed then
					SFX.play(72)
					swimSoundPlayed = true
				end
				
				if not Misc.isPaused() then
					if currentAnimation ~= "swimIdle" and currentAnimation ~= "swimIdleHold" and currentAnimation ~= "swimShoot" and (p.keys.run or p.keys.altRun) then
						animationTimer = animationTimer + 2
					else
						animationTimer = animationTimer + 1
					end
				end
			end
		end
	end
	previousY = p.y or 0
	if table.ifind(SMM2Costumes, p:getCostume()) then
		if math.abs(p.frame) >= 51 and p.forcedState == 0 then
			if altFrames == false then
				apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_penguinsuitb.png"))
				altFrames = true
			end
		elseif altFrames == true or p.forcedState ~= 0 then
			apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_penguinsuit.png"))
			altFrames = false
		end
	end
	
	if not table.ifind(SMM2Costumes, p:getCostume()) and (p.character == 3 or p.character == 4) and p.keys.down and p.heldIndex ~= 0 and not p:mem(0x36, FIELD_BOOL) then
		p.frame = 38
	end
	
end

local characterDeathEffects = {
	[CHARACTER_MARIO] = 3,
	[CHARACTER_LUIGI] = 5,
	[CHARACTER_PEACH] = 129,
	[CHARACTER_TOAD]  = 130,
}

function apt.onPlayerKill(o,player)
	local deathEffect = characterDeathEffects[player.character]
	if table.ifind(SMM2Costumes, player:getCostume()) then
		Graphics.sprites.effect[deathEffect].img = Graphics.loadImage(Misc.resolveFile(player:getCostume().."-ap_penguinsuitmiss.png"))
	end
end

return apt