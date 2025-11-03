
--[[
				beetroot.lua by John Nameless
				
		A customPowerups script for Beta 5 that's made to be
	a successor to Tempest's original beetroot powerup script for Beta 3/4
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	Tempest - Made the original beetroot powerup & spritesheets which said spritesheets were used as a base (https://www.smbxgame.com/forums/viewtopic.php?t=17989)
	SleepyVA - created all of the sprites for Luigi.
	
	Version 2.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local beetroot = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function beetroot.onInitPowerupLib()
	-- gets the spritesheets of the respective powerups
	beetroot.spritesheets = {
		beetroot:registerAsset(1, "mario-beetroot.png"),
		beetroot:registerAsset(2, "luigi-beetroot.png"),
		beetroot:registerAsset(3, "peach-beetroot.png"),
		beetroot:registerAsset(4, "toad-beetroot.png"),
		beetroot:registerAsset(5, "link-beetroot.png"),
		false
		beetroot:registerAsset(7, "wario-beetroot.png"),
	}

	-- needed to align the sprites relative to the player's hurtbox
	beetroot.iniFiles = {
		beetroot:registerAsset(1, "mario-beetroot.ini"),
		beetroot:registerAsset(2, "luigi-beetroot.ini"),
		beetroot:registerAsset(3, "peach-beetroot.ini"),
		beetroot:registerAsset(4, "toad-beetroot.ini"),
		beetroot:registerAsset(5, "link-beetroot.ini"),
		false,
		beetroot:registerAsset(7, "wario-beetroot.png"),
	}
	
	beetroot.gpImages = {
        beetroot:registerAsset(CHARACTER_MARIO, "beetroot-groundPound-1.png"),
        beetroot:registerAsset(CHARACTER_LUIGI, "beetroot-groundPound-2.png"),
    }
end


beetroot.projectileID = 952
beetroot.basePowerup = PLAYER_FIREFLOWER
beetroot.cheats = {"needabeetroot","eatyourveggies","itshiptobeetsquare","beetsinmyhead"}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
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

-- runs once when the powerup gets activated, passes the player
function beetroot.onEnable(p)	
	p.data.beetroot = {
		lastDirection = p.direction * -1,
	}
end

function beetroot.onDisable(p)
	p.data.beetroot = nil
end

function beetroot.onTickPowerup(p)
	if not p.data.beetroot then return end
	local data = p.data.beetroot
	
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end
	 
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
			beetroot.projectileID,
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
			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
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
				v.isProjectile = true
				v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
				v.direction = dir
				p:mem(0x118, FIELD_FLOAT,110)
			end
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
			SFX.play(18)
	
			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
    end
end

function beetroot.onTickEndPowerup(p)
	if not p.data.beetroot then return end
	local data = p.data.beetroot
	if not p:mem(0x50, FIELD_BOOL) then
		data.lastDirection = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,data.lastDirection) -- prevents a base powerup's projectile from shooting while spinjumping
end

return beetroot