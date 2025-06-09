
--[[
			chickenSuit.lua by MrNameless & Sleepy
				
			A customPowerups chickenSuit script that helps to
		streamline the process of making projectile throwing powerups
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
						 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	Sleepy - Created the sprites for the chicken suit for Mario & Luigi, & Link.
	Sara/DeltomX3 - Created the up/down thrust sprites for Link.
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local chickenSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

chickenSuit.projectileID = 807
chickenSuit.forcedStateType = 2 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
chickenSuit.basePowerup = PLAYER_FIREFLOWER
chickenSuit.cheats = {"needachicken","chickenrun","chickenbutt","hotwings","buckaroo","freebirds","hotdogandbaloney","isayisayboywhatyougotcookingupinhere"}
chickenSuit.collectSounds = {
    upgrade = 34,
    reserve = 12,
}
chickenSuit.settings = {
	loseInWater = true, -- should the player lose the chicken suit upon touching any source of water? (true by default)
	matildaJumpHeight = -12, -- how high should the player rise when egg-bomb jumping? (-12 by default)
	matildaJumpSFX = Misc.resolveSoundFile("powerups/chickenSuit-pop.ogg")
}

-- runs when customPowerups is done initializing the library
function chickenSuit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	chickenSuit.spritesheets = {
		chickenSuit:registerAsset(CHARACTER_MARIO, "mario-chickenSuit.png"),
		chickenSuit:registerAsset(CHARACTER_LUIGI, "luigi-chickenSuit.png"),
		false, --chickenSuit:registerAsset(CHARACTER_PEACH, "peach-chickenSuit.png"),
		false, --chickenSuit:registerAsset(CHARACTER_TOAD,  "toad-chickenSuit.png"),
		chickenSuit:registerAsset(CHARACTER_LINK,  "link-chickenSuit.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	chickenSuit.iniFiles = {
		chickenSuit:registerAsset(CHARACTER_MARIO, "mario-chickenSuit.ini"),
		chickenSuit:registerAsset(CHARACTER_LUIGI, "luigi-chickenSuit.ini"),
		false, --chickenSuit:registerAsset(CHARACTER_PEACH, "peach-chickenSuit.ini"),
		false, --chickenSuit:registerAsset(CHARACTER_TOAD,  "toad-chickenSuit.ini"),
		chickenSuit:registerAsset(CHARACTER_LINK,  "link-chickenSuit.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the chickenSuit powerup
	chickenSuit.gpImages = {
		chickenSuit:registerAsset(CHARACTER_MARIO, "chickenSuit-groundPound-1.png"),
		chickenSuit:registerAsset(CHARACTER_LUIGI, "chickenSuit-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12} -- the animation frames for shooting a fireball

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {60, 60, 60, 65, 50}

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

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

function chickenSuit.onInitAPI()
	-- register your events here!
	--registerEvent(chickenSuit,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function chickenSuit.onEnable(p)	
	p.data.chickenSuit = {
		projectileTimer = 0, -- don't remove this unless you know what you're doing
		matildaTimer = 0, -- projectileTimer again but for the egg double jump
		touchedGround = true,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function chickenSuit.onDisable(p)
	p.data.chickenSuit = nil
end

-- runs when the powerup is active, passes the player
function chickenSuit.onTickPowerup(p) 
	if not p.data.chickenSuit then return end
	local data = p.data.chickenSuit
	local settings = chickenSuit.settings
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
	data.matildaTimer = math.max(data.matildaTimer - 1, 0) -- decrement the "Matilda" timer/cooldown
	
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end
	
	-- lose the powerup whenever the player touches water
	if p:mem(0x36,FIELD_BOOL) and settings.loseInWater then
		cp.setPowerup(2, p, false)
		SFX.play(5)
		chickenSuit.onDisable(p)
		return
	end

	if p:mem(0x50, FIELD_BOOL) then return end	
	
	if p.keys.jump == KEYS_PRESSED and not isOnGround(p) and p.mount ~= MOUNT_CLOWNCAR and data.touchedGround then
        local egg = NPC.spawn(
			chickenSuit.projectileID,
			p.x + p.width/2 + p.speedX,
			p.y + p.height/1.5 + p.speedY, p.section, false, true
        )
		egg.direction = p.direction
		egg.speedY = 6
		egg.data.bounces = 0
		egg.isProjectile = true
		p.speedY = settings.matildaJumpHeight
		SFX.play(settings.matildaJumpSFX)
		data.touchedGround = false --data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
		data.matildaTimer = projectileTimerMax[p.character]
		return
	elseif p:isOnGround(p) then
		data.touchedGround = true
	end

   if data.projectileTimer > 0 or not data.touchedGround or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED) and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		-- spawns the projectile itself
        local v = NPC.spawn(
			chickenSuit.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and not linkChars[p.character] and p.holdingNPC == nil and p.mount == 0 then
			-- this sets the npc to be held by the player
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			SFX.play(18)
		elseif linkChars[p.character] then -- handles shooting as link/snake/samus
			if p:mem(0x12E,FIELD_BOOL) then -- if ducking, have the npc not rise higher
				v.speedY = -2
			else
				v.speedY = -5
			end
			v.x = v.x + (24 * dir) -- adjust the npc a bit to look like it's being shot out of link's sword
			v.direction = -dir -- make it so that the egg keeps bouncing straight ahead at least once
			v.speedX = (NPC.config[v.id].speed * dir) + p.speedX/3.5
			SFX.play(82)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			else
				v.speedY = -4
			end
			v.direction = dir	
			v.speedX = (NPC.config[v.id].speed * dir) + p.speedX/2
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			SFX.play(18)
		end
        v.isProjectile = true
		data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
end

function chickenSuit.onTickEndPowerup(p)
	if not p.data.chickenSuit then return end
	local data = p.data.chickenSuit
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

	if p.speedY < -Defines.player_grav and data.touchedGround == false and data.matildaTimer > 0 then
		curFrame = 24
	end

    if (data.projectileTimer > 0 or data.matildaTimer > 0) and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

function chickenSuit.onDrawPowerup(p)
	return
end

return chickenSuit