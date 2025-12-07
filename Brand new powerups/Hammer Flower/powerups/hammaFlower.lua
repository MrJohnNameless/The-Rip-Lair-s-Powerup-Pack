--[[
	Hammer Flower by DeviousQuacks23 and marioBrigade2018
	(This is based on the iteration of NewerSMBW)
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - made the powerup template which I used for this script
	marioBrigade2018 - made the projectile
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local hammaFlower = {}

hammaFlower.projectileID = 877
hammaFlower.forcedStateType = 2 
hammaFlower.basePowerup = PLAYER_HAMMER
hammaFlower.cheats = {"needahammerflower"}
hammaFlower.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

function hammaFlower.onInitPowerupLib()
	hammaFlower.spritesheets = {
		hammaFlower:registerAsset(CHARACTER_MARIO, "hammaFlowa-mario.png"),
		hammaFlower:registerAsset(CHARACTER_LUIGI, "hammaFlowa-greenStache.png"),
	}
	
	hammaFlower.iniFiles = {
		hammaFlower:registerAsset(CHARACTER_MARIO, "hammaFlowa-mario.ini"),
		hammaFlower:registerAsset(CHARACTER_LUIGI, "hammaFlowa-greenStache.ini"),
	}
end

local linkChars = table.map{5,12,16}
local smb2Chars = table.map{3,4,6,9,10,11,16}
local animFrames = {12, 12, 12, 12, 11, 11, 11, 11}
local projectileTimerMax = {30, 35, 40, 25, 40}

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

function hammaFlower.onEnable(p)
	p:mem(0x162, FIELD_WORD,2)
	p.data.hammaFlower = {}
end

function hammaFlower.onDisable(p)	
	p.data.hammaFlower = nil
end

function hammaFlower.onTickPowerup(p) 
	if not p.data.hammaFlower then return end
	local data = p.data.hammaFlower

	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if p.isSpinJumping and p:isOnGround() then return end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	-- handles spawning the projectile if the player is pressing either run button or spinjumping
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
			hammaFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
		)	
		v.direction = dir
		
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			v.x = v.x + (16 * dir)
			v.speedX = (5 * dir) + p.speedX/3
			-- shoot less higher when ducking
			if p.isDucking then
				v.speedY = -3
			else
				v.speedX = v.speedX/1.25
				v.speedY = -7
			end
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			SFX.play(90)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
			return
		end
		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedX = (2 * dir) + p.speedX/3
				v.speedY = -10 + speedYMod
			else
				v.speedX = (5 * dir) + p.speedX/3
				v.speedY = -6
			end
			p:mem(0x118, FIELD_FLOAT,110) -- set the player to do the shooting animation
		end
		p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character] or projectileTimerMax[1])
		SFX.play(25)
    end
end

function hammaFlower.onTickEndPowerup(p)
end

function hammaFlower.onDrawPowerup(p)
	if not p.data.hammaFlower then return end
	local data = p.data.hammaFlower
end

return hammaFlower