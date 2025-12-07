
--[[
				Aqua FLower by marioBrigade2018 & Sleepy Dee
				
			An original customPowerups script that lets the player
		shoot one big water ball that splits into several smaller ones
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
						 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	Sleepy Dee	- Conceptualized how the Aqua Flower would work.
				- Created the sprites for the Aqua Flower NPC & player sprites. 
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local aquaFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

aquaFlower.projectileID = 962
aquaFlower.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
aquaFlower.basePowerup = PLAYER_ICE
aquaFlower.cheats = {"needanaquaflower","needaaquaflower","firefighter","remembertohydrateyourself","eightsglassesaday","slipperywhenwet"}
aquaFlower.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
aquaFlower.settings = {
	enableSwimAccel = true,
	swimAcceleration = 0.075, -- When underwater, how much extra speed does the player get when swimming forward? (0.075 by default)
	-- put your own settings here!
}

-- runs when customPowerups is done initializing the library
function aquaFlower.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	aquaFlower.spritesheets = {
		aquaFlower:registerAsset(CHARACTER_MARIO, "mario-aqua.png"),
		aquaFlower:registerAsset(CHARACTER_LUIGI, "luigi-aqua.png"),
		aquaFlower:registerAsset(CHARACTER_PEACH, "peach-aqua.png"),
		aquaFlower:registerAsset(CHARACTER_TOAD,  "toad-aqua.png"),
		aquaFlower:registerAsset(CHARACTER_LINK,  "link-aqua.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	aquaFlower.iniFiles = {
		aquaFlower:registerAsset(CHARACTER_MARIO, "mario-aqua.ini"),
		aquaFlower:registerAsset(CHARACTER_LUIGI, "luigi-aqua.ini"),
		aquaFlower:registerAsset(CHARACTER_PEACH, "peach-aqua.ini"),
		aquaFlower:registerAsset(CHARACTER_TOAD,  "toad-aqua.ini"),
		aquaFlower:registerAsset(CHARACTER_LINK,  "link-aqua.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the aquaFlower powerup
	aquaFlower.gpImages = {
		aquaFlower:registerAsset(CHARACTER_MARIO, "aqua-groundPound-1.png"),
		aquaFlower:registerAsset(CHARACTER_LUIGI, "aqua-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12} -- the animation frames for shooting a fireball

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {60, 60, 60, 55, 50}

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
        and (p.mount == 0 or p.mount == MOUNT_BOOT)
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p:mem(0x12E, FIELD_BOOL) or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function aquaFlower.onInitAPI()
	-- register your events here!
	Misc.groupsCollide["aquaball"]["aquaball"] = false
end

-- runs once when the powerup gets activated, passes the player
function aquaFlower.onEnable(p)	
	p.data.aquaFlower = {
		lastDirection = p.direction * -1, -- don't remove this unless you know what you're doing
	}
end

-- runs once when the powerup gets deactivated, passes the player
function aquaFlower.onDisable(p)
	p.data.aquaFlower = nil
end

-- runs when the powerup is active, passes the player
function aquaFlower.onTickPowerup(p) 
	if not p.data.aquaFlower then return end
	
	local data = p.data.aquaFlower
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
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			aquaFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p:mem(0x12E,FIELD_BOOL) then
				v.speedY = -2
			else
				v.speedY = -5
			end
			v.x = v.x + (16 * dir)
			v.isProjectile = true
			v.speedX = ((NPC.config[v.id].speed + 1) * dir) + p.speedX/2.5
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
		else
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
					v.speedY = -4
				end
				v.direction = dir
				v.speedX = ((NPC.config[v.id].speed + 1) * dir) + p.speedX/2.5
				p:mem(0x118, FIELD_FLOAT,110)
			end
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character] or projectileTimerMax[1])
			SFX.play(18)
	
			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
    end

	-- handles giving the player a speed boost when underwater (Code taken from blueshell.lua)
	if p:mem(0x36,FIELD_BOOL) and aquaFlower.settings.enableSwimAccel then
		p:mem(0x38, FIELD_WORD, math.min(p:mem(0x38, FIELD_WORD), 5))
		if p.keys.left then
			p.speedX = p.speedX - aquaFlower.settings.swimAcceleration
		elseif p.keys.right then
			p.speedX = p.speedX + aquaFlower.settings.swimAcceleration
		end
	end
end

function aquaFlower.onTickEndPowerup(p)
	if not p.data.aquaFlower then return end
	
	local data = p.data.aquaFlower
	if not p.isSpinJumping then
		data.lastDirection = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,data.lastDirection) -- prevents a base powerup's projectile from shooting while spinjumping
end

return aquaFlower