
--[[
				Projectile Powerup template by MrNameless
				
			A customPowerups template script that helps to
		streamline the process of making projectile throwing powerups
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local frogSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function frogSuit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	frogSuit.spritesheets = {
		frogSuit:registerAsset(1, "mario-frogSuit.png"),
		frogSuit:registerAsset(2, "luigi-frogSuit.png"),
	}

	-- needed to align the sprites relative to the player's hurtbox
	frogSuit.iniFiles = {
		frogSuit:registerAsset(1, "mario-frogSuit.ini"),
		frogSuit:registerAsset(2, "luigi-frogSuit.ini"),
	}
end


frogSuit.projectileID = 839
frogSuit.basePowerup = PLAYER_FIREFLOWER
frogSuit.cheats = {"needafrogsuit", "iamthegreat"}


-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 11, 11, 11, 11} -- the animation frames for shooting a fireball



-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {6, 6, 6, 6, 6}
local cooldown = 45

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
        and p.mount == 0
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


function frogSuit.onInitAPI()
	-- register your events here!
	registerEvent(frogSuit,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function frogSuit.onEnable(p)	
	p.data.frogSuit = {
		projectileTimer = 0, -- don't remove this

		shotCount = 0,
		cooldown = 0,
		coolingdown = false,
		timer = 0,
		shooting = false
	}
end

-- runs once when the powerup gets deactivated, passes the player
function frogSuit.onDisable(p)	
	p.data.frogSuit = nil
end

-- runs when the powerup is active, passes the player
function frogSuit.onTickPowerup(p) 
	if cp.getCurrentPowerup(p) ~= frogSuit or not p.data.frogSuit then return end -- check if the powerup is currenly active
	local data = p.data.frogSuit
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end
	
	-- Text.print(data.shotCount, 10, 10)
	-- Text.print(data.cooldown, 10, 30)
	
	data.timer = data.timer + 1
	if data.timer >= 30 then
		data.shotCount = 0
	end

   if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end


    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end -- if spinjumping while on the ground
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) and data.shotCount <= 8 and data.cooldown <= 0 and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2 then
		if not data.shooting then
			data.shooting = true
		end
	end
	
	if data.shooting then
        local dir = p.direction
		
		-- reverses the direction the projectile goes when the player is spinjumping to make it be shot """in front""" of the player 
		if p:mem(0x50, FIELD_BOOL) and p.holdingNPC == nil then
			dir = p.direction * -1
		end
		
		
		data.shooting = true
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			frogSuit.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY,
			p.section,
			false,
			true
        )
		v:mem(0x1C,FIELD_BOOL,true) -- this is needed to work around a bug with the nowaterphysics config not working properly whenever the npc enters water
		data.shotCount = data.shotCount + 1
		data.timer = 0
		v.direction = dir
		v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir + (math.sin(lunatime.tick() * 0.2) * 2)
		
		if p.keys.up == KEYS_DOWN then -- sets the projectile upwards if you're holding up while shooting
			local speedYMod = p.speedY * 0.1 -- adds extra vertical speed depending on how fast you were going vertically
			if p.standingNPC then
				speedYMod = p.standingNPC.speedY * 0.1
			end
			v.speedY = -10 + speedYMod - (math.cos(lunatime.tick() * 0.2) * 2)
			v.speedX = v.speedX / 2
		else
			v.speedY = -8 - (math.cos(lunatime.tick() * 0.2) * 2)
		end
		
		SFX.play(18)
        data.projectileTimer = projectileTimerMax[p.character] or projectileTimerMax[1] -- sets the projectileTimer/cooldown upon shooting
    end
	
	if data.shotCount == 4 and not data.coolingdown then
		data.cooldown = cooldown
		data.coolingdown = true
		data.shooting = false
	end
	
	if data.coolingdown then
		if data.cooldown == 0 then
			data.coolingdown = false
			data.shotCount = 0
		end
	end
	
	data.cooldown = data.cooldown - 1
	if data.cooldown <= 0 then
		data.cooldown = 0
	end
end

function frogSuit.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= frogSuit or not p.data.frogSuit then return end -- check if the powerup is currently active
	
	local data = p.data.frogSuit
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

function frogSuit.onDrawPowerup(p)
end

return frogSuit