--[[

	Super Acorn
	by Cpt. Mono
	
	Credits:
	SMB3 Flying Squirrel Mario: Krusper Butter (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/84423/)
	SMW Flying Squirrel Mario, Luigi, Toad, and Toadette: Nintendo, GlacialSiren484, AwesomeZack, MauricioN64, Jamestendo64, LinkStormZ, and TheMushRunt (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/161073/)
	
	MrDoubleA for creating stuff that I could learn general workflow and take bits and bobs from. If it wasn't for his work, I would've never been able to gain the knowledge I needed to finish this~
	
	If you look into this code, you're probably going to find that it's incredibly messy. No, like, REALLY, REALLY messy.
	I actually started work on this before my SMM2 Playables, so I had... a LOT to learn as I was making this.
	I plan on cleaning up the code before starting work on my next powerup, however, so you've at least got that to look forwards to!
	Anyways, if it hasn't already ended, I implore you to go and answer the poll that I put up. Making powerups takes time, you know!
	
]]
-- Variable "name" is reserved
-- variable "registerItems" is reserved

local apt = {}

local playerManager = require("playerManager")
local cp = require("customPowerups")

local characterList = {"mario", "luigi", "toad", "peach", "link"}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

-- how to register:
-- local cp = require("customPowerups")
-- local myPowerup = cp.addPowerup("My Powerup", "apt", [optional itemID/list of item IDs])

-- calls in Emral's anotherwalljump if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

apt.spritesheets = {
    Graphics.sprites.mario[4].img,
    Graphics.sprites.luigi[4].img,
    Graphics.sprites.peach[4].img,
    Graphics.sprites.toad[4].img,
    Graphics.sprites.link[4].img
}

apt.iniFiles = {
	Misc.resolveFile("mario-ap_acorn.ini"),
	Misc.resolveFile("luigi-ap_acorn.ini"),
}

apt.basePowerup = PLAYER_FIREFLOWER
apt.items = {}
apt.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

apt.aliases = {"needaacorn","stockupforwinter"}

apt.acornSettings = {
	glideConstant = 1, --A constant used to determine how quickly you fall while moving at your maximum speed. The higher it is, the faster your descent will be.
	glideRounding = 1, --A constant used to determine how quickly you slow down while gliding. The higher it is, the quicker you'll snap to your gliding speed.
	glideFloor = 3, --Used to determine the fastest speed that you can fall at, which is equal to your terminal velocity (Defines.gravity) divided by this number. The higher it is, the slower you'll drop.
	spinJumpConstant = 16, --A constant used to determine how much higher spin jumps go. The higher it is, the higher you'll jump!
	glideCurveX = 3,
	glideCurveY = 8,
	boostDuration = 51,
	hoverConstant = 5,
	--{Glide, GlideHolding, Boost1, Boost2, BoostFlap1, BoostFlap2, BoostFlap3}
	normalFrameList = {11, 11, 44, 44, 42, 43, 44},
	SMM2FrameList = {11, 12, 56, 58, 59, 60, 61},
	}

local altFrames = false
local SMM2Costumes = {"SMM2-MARIO", "SMM2-LUIGI", "SMM2-TOAD", "SMM2-TOADETTE", "SMM2-YELLOWTOAD"}
apt.items = {800} -- Items that can be collected.

--Here's a bunch of functions that I'm gonna use! Totally didn't take the idea of "Convenience Functions" from MrDoubleA or anything.

local function ducking() --Crouching function I stole from the Gold Flower example Enjl made because it's super nice to have.
    return player:mem(0x12E, FIELD_BOOL)
end

local function holding() --Item holding function that's derivative of a trick I learned while sifting through MrDoubleA's SMW Costume code.
	return player:mem(0x154,FIELD_WORD) > 0
end

local function canGlide() --A function that deals with a list of circumstances under which you can't do anything with the Super Acorn no matter what. Renamed from abilitiesEnabled for ease of typing.
	return not player:mem(0x5C,FIELD_BOOL) --Purple Yoshi Ground Pound (Downwards motion)
	and not player:mem(0x5E,FIELD_BOOL) --Purple Yoshi Ground Pound (Rebound)
	and not player:mem(0x13C,FIELD_BOOL) --If you're dead, you can't do anything. lol
	and player:mem(0x122,FIELD_WORD) <= 0 --If you're in the middle of a forced animation, trying to interrupt it would be a bad idea.
	and player:mem(0x108,FIELD_WORD) <= 0 --If you're on any mount, then the Super Acorn just doesn't do anything. I'm glad I don't really have to think about this one.
	and player:mem(0x40,FIELD_WORD) <= 0 --Not even Knuckles can glide and climb simultaneously.
	and not player:mem(0x36,FIELD_BOOL)	--I like underwater levels, but the Super Acorn sure doesn't...
	and not player:mem(0x44,FIELD_BOOL)	--I don't even want to think about trying to glide without getting off of a shell.
	and not player:mem(0x3C,FIELD_BOOL)--No sliding and gliding allowed!
	and player:mem(0x06,FIELD_WORD) <= 0--Gliding in quicksand doesn't work, either.
	and not player:isOnGround() --You can't glide if you're not in the air, silly.
end

--You see that code up there? That's a function that I wrote, like, when I JUST started using LunaLua. It makes me nostalgic, looking at it and also just how flowery the comments are.


--Funnily enough, the abilitiesEnabled function actually seems to detail all of the circumstances under which you refresh your air boost besides stomping on an enemy. Lucky me!
	
local function canGlideDeprecated() --Just rename canGlide() to abilitiesEnabled() to be able to use this again.
	return abilitiesEnabled()
	and not player:isOnGround()
	and not ducking()
end
	
local spinJumpLastFrame = false --I still need to rewrite the spin jump override code so that this variable isn't needed.
local boostInputReady = false
local boostTimer = 0
local boostDirection = 1
local boostAnimationTimer = 0
local forceBoostTimer = nil
local forceBoostTimer2 = 0
local wallJumpTimer = 0

local function spinJumpCheck()
	if not spinJumpLastFrame and player:mem(0x50,FIELD_BOOL) then
		return true
	else 
		return false
	end
end
	
local function boostInputCheck()
	if not canGlide() then
		boostInputReady = false
	elseif not boostInputReady and not player.keys.altJump then
		boostInputReady = true
	end
end
	
local animationData = {}

-- Runs when player switches to this powerup. Use for setting stuff like global Defines.
function apt.onEnable(p)
	spinJumpLastFrame = false
	p:mem(0x46, FIELD_WORD, 800)
	apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(characterList[p.character].."-ap_acorn.png"))
end

-- If you wish to have global onTick etc... functions, you can register them with an alias like so:
-- registerEvent(apt, "onTick", "onPersistentTick")
-- No need to register. Runs only when powerup is active.

registerEvent(apt, "onPlayerKill", "onPlayerKill")

local previousCostume

-- runs when the powerup is active, passes the player
function apt.onTickPowerup(p)
	if p.character ~= 5 then
		p:mem(0x160, FIELD_WORD, 2)
	else
		p:mem(0x162, FIELD_WORD, 2)
	end
	if table.ifind(SMM2Costumes, p:getCostume()) then
		if lunatime.tick() == 1 or p:getCostume() ~= previousCostume then
			if altFrames then
				apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_acornb.png"))
			else
				apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_acorn.png"))
			end
		end
		animationData = apt.acornSettings.SMM2FrameList
	else
		apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(characterList[p.character].."-ap_acorn.png"))
		animationData = apt.acornSettings.normalFrameList
	end
	previousCostume = p:getCostume()
end

-- runs when the powerup is active, passes the player
function apt.onTickEndPowerup(p) --This part of the code is the messiest, since it's what I did first. Definitely coming back so that I can clean it up a bit later on.
	local glideSpeed = math.min(Defines.player_walkspeed*apt.acornSettings.glideConstant/math.min(Defines.player_walkspeed,math.abs(p.speedX)),Defines.gravity/apt.acornSettings.glideFloor) --Glide speed is dependent on how fast you're moving, and gets capped out at your terminal velocity/3.
	boostInputCheck()
	if boostTimer > 1 then
	p.speedX = apt.acornSettings.glideCurveX*boostDirection
	p.speedY = -boostTimer*apt.acornSettings.glideCurveY/apt.acornSettings.boostDuration+1
	boostTimer = boostTimer - 1
		if p.keys.down == KEYS_PRESSED then
			p.speedX = 0
			p.speedY = 0
			boostTimer = 1 --1 indicates that you're in the "hovering" state.
		end
		if not canGlide() then
			boostTimer = 0
		end
	elseif boostTimer == 1 then
		local hoverSpeed = Defines.gravity/apt.acornSettings.hoverConstant
		if p.speedX >= Defines.player_walkspeed then --Cap player's X speed if they're moving right.
			p.speedX = Defines.player_walkspeed
		elseif p.speedX <= -Defines.player_walkspeed then --Cap player's X speed if they're moving left.
			p.speedX = -Defines.player_walkspeed
		end
		if p.speedY >= hoverSpeed then --Cap player's Y speed so that they don't sink like a rock.
			p.speedY = hoverSpeed
		end
		boostAnimationTimer = boostAnimationTimer + 1
		if boostAnimationTimer == 16 then
			boostAnimationTimer = 0
		end
		if not canGlide() or p.speedY <= 0 then
			boostTimer = 0
			p:mem(0x04,FIELD_BOOL,false)
		end
	elseif canGlide() then
		if p.keys.altJump and boostInputReady and not p:mem(0x50,FIELD_BOOL) and p.holdingNPC == nil then --Boost code; takes priority over gliding.
			boostTimer = apt.acornSettings.boostDuration
			boostDirection = p.direction
			p:mem(0x11C,FIELD_WORD,0)
			Audio.playSFX(33)
		elseif p.keys.jump and p.speedY >= glideSpeed and not ducking() then --Regular gliding code.
			p.speedY = math.max(p.speedY-apt.acornSettings.glideRounding,glideSpeed)
			p:mem(0x50,FIELD_BOOL,false)
		end
	else
		boostTimer = 0
	end
	if p.forcedState ~= 0 then
		p:mem(0x04,FIELD_BOOL,false)
		boostTimer = 0
	end
	if spinJumpCheck() then --Something tells me that I can do something with keys.pressed instead of the caveman method that past me used, but I'm just gonna leave it for now.
	p:mem(0x11C,FIELD_WORD,p:mem(0x11C,FIELD_WORD)+apt.acornSettings.spinJumpConstant)
	end
	spinJumpLastFrame = p:mem(0x50,FIELD_BOOL)

	--Let the player cling to the wall, if enjl's wall jump script is enabled
	if aw then
		if aw.isWallSliding(p) ~= 0 then
			if boostTimer ~= 0 then
				forceBoostTimer = 1
			end
			wallJumpTimer = wallJumpTimer + 1
			if wallJumpTimer <= 80 then
				if p.character ~= 2 then
					p.speedY = -Defines.player_grav
				else
					p.speedY = -Defines.player_grav + 0.04
				end
			end
		elseif aw.isWallSliding(p) == 0 then
			forceBoostTimer2 = forceBoostTimer2 - 1
			if forceBoostTimer2 <= 0 then
				forceBoostTimer = nil
			end
			wallJumpTimer = math.max(wallJumpTimer - 1, 0)
		end
		if p:isOnGround() then
			forceBoostTimer = nil
			forceBoostTimer2 = 0
			wallJumpTimer = 0
		end
	end
	
	if (aw and aw.isWallSliding(p) ~= 0) then
		if boostTimer ~= 0 then boostTimer = 1 end
	end
	
	if forceBoostTimer ~= nil then boostTimer = 1 forceBoostTimer2 = 2 end
end

-- runs when the powerup is active, passes the player

function apt.onDrawPowerup(p)
    if p.forcedState == 0 then
		if canGlide() and p.keys.jump and p.speedY >= 0 and not ducking() and not p:mem(0x50, FIELD_BOOL) then
			if p.holdingNPC ~= nil then
				p.frame = animationData[2] --Gliding, holding
			else
				p.frame = animationData[1] --Gliding
			end
		end
		if boostTimer > 0 then
			p:mem(0x04,FIELD_WORD, 1)
			if boostTimer >= apt.acornSettings.boostDuration/2 then
				p.frame = animationData[3] --Boost, moving up
				p.direction = boostDirection
			elseif boostTimer > 1 then
				p.frame = animationData[4] --Boost, near peak
				p.direction = boostDirection
			else
				if boostAnimationTimer <= 3 then
					p.frame = animationData[5] --Arms up, hovering
				elseif boostAnimationTimer <= 7 then
					p.frame = animationData[6] --Arms midway down, hovering
				elseif boostAnimationTimer <= 11 then
					if boostAnimationTimer == 11 then
					playSFX(10) --Arms down, hovering
					end
					p.frame = animationData[7]
				else
					p.frame = animationData[6] --Arms midway down, hovering
				end
			end
		end
	end
	if table.ifind(SMM2Costumes, p:getCostume()) then
		if math.abs(p.frame) >= 51 and p.forcedState == 0 then
				if altFrames == false then
					apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_acornb.png"))
					altFrames = true
				end
		elseif altFrames == true or p.forcedState ~= 0 then
			apt.spritesheets[p.character] = Graphics.loadImage(Misc.resolveFile(p:getCostume().."-ap_acorn.png"))
			altFrames = false
		end
	end
end

local characterDeathEffects = {
	[CHARACTER_MARIO] = 3,
	[CHARACTER_LUIGI] = 5,
	[CHARACTER_PEACH] = 129,
	[CHARACTER_TOAD]  = 130,
}

function apt.onPlayerKill(o,p)
	local deathEffect = characterDeathEffects[player.character]
	if table.ifind(SMM2Costumes, player:getCostume()) and player:mem(0x46, FIELD_WORD) == 800 then
		Graphics.sprites.effect[deathEffect].img = Graphics.loadImage(Misc.resolveFile(player:getCostume().."-ap_acornmiss.png"))
	end
end

return apt