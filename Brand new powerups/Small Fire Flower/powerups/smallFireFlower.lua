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
local animFrames = {12, 12, 12, 12, 11, 11, 11, 11}
local projectileTimerMax = {30, 35, 40, 25, 25}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
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

   	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
    	if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end
	
	-- handles spawning the projectile if the player is pressing either run button or spinjumping
   	if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL))) or player:mem(0x14, FIELD_WORD) == 2 then
		-- spawns the projectile itself
        	local v = NPC.spawn(
			smallFireFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * p.direction + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        	)
		v.ai1 = p.character		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
			-- this sets the npc to be held by the player
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			else
				v.speedY = 4
			end
			v.isProjectile = true
			v.speedX = 4.5 * p.direction
		end
        	data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
		SFX.play(18)
    	end
end

function smallFireFlower.onTickEndPowerup(p)
	if not p.data.smallFireFlower then return end
	local data = p.data.smallFireFlower
	
    	local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    	local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    	if data.projectileTimer > 0 and canPlay and curFrame then
        	p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    	end
end

function smallFireFlower.onDrawPowerup(p)
	if not p.data.smallFireFlower then return end
	local data = p.data.smallFireFlower
end

return smallFireFlower