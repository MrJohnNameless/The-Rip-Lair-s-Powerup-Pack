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

function hammaFlower.onEnable(p)	
	p.data.hammaFlower = {
		projectileTimer = 0
	}
end

function hammaFlower.onDisable(p)	
	p.data.hammaFlower = nil
end

function hammaFlower.onTickPowerup(p) 
	if not p.data.hammaFlower then return end
	local data = p.data.hammaFlower
	
    	data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown

    	if p.mount < 2 then -- disables shooting fireballs 
        	p:mem(0x160, FIELD_WORD, 2)
   	end

   	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
    	if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end
	
	-- handles spawning the projectile if the player is pressing either run button or spinjumping
   	if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL))) or player:mem(0x14, FIELD_WORD) == 2 then
		-- spawns the projectile itself
        	local v = NPC.spawn(
			hammaFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * p.direction + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        	)	
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
				v.speedX = 2 * p.direction
				v.speedY = -10 + speedYMod
			else
				v.speedX = 5 * p.direction
				v.speedY = -6
			end
		end
        	data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
		SFX.play(25)
    	end
end

function hammaFlower.onTickEndPowerup(p)
	if not p.data.hammaFlower then return end
	local data = p.data.hammaFlower
	
    	local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    	local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    	if data.projectileTimer > 0 and canPlay and curFrame then
        	p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    	end
end

function hammaFlower.onDrawPowerup(p)
	if not p.data.hammaFlower then return end
	local data = p.data.hammaFlower
end

return hammaFlower