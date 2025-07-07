--[[
	Small Fire Flower by DeviousQuacks23
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - made the powerup template which I used for this script
	Soap - made the powerup sprite
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local smallFireFlower = {}

smallFireFlower.projectileID = 13
smallFireFlower.forcedStateType = 1 
smallFireFlower.basePowerup = PLAYER_SMALL
smallFireFlower.cheats = {"needasmallfireflower"}
smallFireFlower.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

function smallFireFlower.onInitPowerupLib()
	smallFireFlower.spritesheets = {
		smallFireFlower:registerAsset(CHARACTER_MARIO, "mario-smallFire.png"),
		smallFireFlower:registerAsset(CHARACTER_LUIGI, "luigi-smallFire.png"),
	}
	
	smallFireFlower.iniFiles = {
		smallFireFlower:registerAsset(CHARACTER_MARIO, "mario-smallFire.ini"),
		smallFireFlower:registerAsset(CHARACTER_LUIGI, "luigi-smallFire.ini"),
	}
end

local smb2Chars = table.map{3,4,6,9,10,11,16}
local linkChars = table.map{5,12,16}
local animFrames = {12, 12, 12, 12, 11, 11, 11, 11}
local projectileTimerMax = {30, 35, 40, 25, 40}
local projectileVariant = {
	[CHARACTER_MARIO] = 1,
	[CHARACTER_LUIGI] = 2,
	[CHARACTER_PEACH] = 3,
	[CHARACTER_TOAD] = 4,
	[CHARACTER_LINK] = 5,
	[CHARACTER_MEGAMAN] = 4,
	[CHARACTER_WARIO] = 1,
	[CHARACTER_BOWSER] = 2,
	[CHARACTER_KLONOA] = 4,
	[CHARACTER_NINJABOMBERMAN] = 3,
	[CHARACTER_ROSALINA] = 3,
	[CHARACTER_SNAKE] = 5,
	[CHARACTER_ZELDA] = 2,
	[CHARACTER_ULTIMATERINKA] = 4,
	[CHARACTER_UNCLEBROADSWORD] = 1,
	[CHARACTER_SAMUS] = 5
}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and (p.mount == 0 or p.mount == MOUNT_BOOT)
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

function smallFireFlower.onEnable(p)	
	p.data.smallFireFlower = {
		projectileTimer = 0
	}
end

function smallFireFlower.onDisable(p)	
	p.data.smallFireFlower = nil
end

function smallFireFlower.onTickPowerup(p) 
	if not p.data.smallFireFlower then return end
	local data = p.data.smallFireFlower
	
	data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
	
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if p.isSpinJumping and p:isOnGround() then return end
	 
	if linkChars[p.character] then
		if p:mem(0x162,FIELD_WORD) > 0 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p.isSpinJumping) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		if p.isSpinJumping and projectileTimerMax[p.character] % 2 ~= 0 then
			if p:mem(0x52,FIELD_WORD) % 2 == 0 then
				dir = p:mem(0x54,FIELD_WORD) * -1
			else
				dir = p:mem(0x54,FIELD_WORD)
			end
		end
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			smallFireFlower.projectileID,
			p.x + p.width/2 + (p.width/2) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		v.direction = dir
		v.ai1 = projectileVariant[p.character]
		v.speedX = (5 + math.abs(p.speedX)/3.5) * dir
		
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p.isDucking then
				v.y = v.y + 4
			else
				v.y = v.y - 14
			end
			v.x = v.x + (16 * dir)
			v.speedY = 0
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,0)
			end
			return
		end
		-- handles making the projectile be held if the player is a SMB2 character & pressed altRun 
		if smb2Chars[p.character] and p.holdingNPC == nil and p.keys.altRun then 
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1 -- adds extra vertical speed depending on how fast you were going vertically
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			else
				v.speedY = 20
			end
			p:mem(0x118, FIELD_FLOAT,110) -- set the player to do the shooting animation
		end
		p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
		data.projectileTimer = projectileTimerMax[p.character]
		SFX.play(18)
    end
end

function smallFireFlower.onDrawPowerup(p)
	if not p.data.smallFireFlower then return end
	local data = p.data.smallFireFlower

	local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
	local canPlay = canPlayShootAnim(p) and not p.isSpinJumping

	if data.projectileTimer > 0 and canPlay and curFrame then
		p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
	end
end

return smallFireFlower