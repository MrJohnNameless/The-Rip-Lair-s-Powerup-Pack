
--[[
	Poison Flower by Deltomx3
				
	A customPowerups poisonFlower script that helps to
	streamline the process of making projectile throwing powerups
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	SleepyVA - Sprites (Mario & Luigi)
	Deltomx3 - Sprites (Toad, Peach, & Link)
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the (first) link above! ^^^
]]--

local cp = require("customPowerups")

local poisonFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function poisonFlower.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	poisonFlower.spritesheets = {
		poisonFlower:registerAsset(1, "mario-poison.png"),
		poisonFlower:registerAsset(2, "luigi-poison.png"),
		poisonFlower:registerAsset(3, "peach-poison.png"),
		poisonFlower:registerAsset(4, "toad-poison.png"),
		poisonFlower:registerAsset(5, "link-poison.png"),
	}

	-- needed to align the sprites relative to the player's hurtbox
	poisonFlower.iniFiles = {
		poisonFlower:registerAsset(1, "mario-poison.ini"),
		poisonFlower:registerAsset(2, "luigi-poison.ini"),
		poisonFlower:registerAsset(3, "peach-poison.ini"),
		poisonFlower:registerAsset(4, "toad-poison.ini"),
		poisonFlower:registerAsset(5, "link-poison.ini"),
	}

	poisonFlower.gpImages = {
		poisonFlower:registerAsset(1, "poisonFlower-groundPound-mario.png"),
		poisonFlower:registerAsset(2, "poisonFlower-groundPound-luigi.png"),
	}
end

poisonFlower.projectileID = 865
poisonFlower.limit = 2 -- How many bubbles the player can have at once
poisonFlower.basePowerup = PLAYER_FIREFLOWER
poisonFlower.cheats = {"needapoisonflower", "foodpoisoning", "atleastthisdoesntkillyou", "imsorrymariobutyouhave7monthstolive", "wearenumberone", "wiiuera"}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12} -- the animation frames for shooting a fireball

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

function poisonFlower.onInitAPI()
	registerEvent(poisonFlower,"onNPCKill")
end

-- runs once when the powerup gets activated, passes the player
function poisonFlower.onEnable(p)	
	p.data.poisonFlower = {
		projectileTimer = 0, -- don't remove this
		playerBubbles = 0,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function poisonFlower.onDisable(p)	
	p.data.poisonFlower = nil
end

-- runs when the powerup is active, passes the player
function poisonFlower.onTickPowerup(p) 
	if cp.getCurrentPowerup(p) ~= poisonFlower or not p.data.poisonFlower then return end -- check if the powerup is currenly active
	local data = p.data.poisonFlower
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	
	if data.playerBubbles <= 0 then
		data.playerBubbles = 0
	end

    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end -- if spinjumping while on the ground
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2) and data.playerBubbles < poisonFlower.limit then
        local dir = p.direction
		
		-- reverses the direction the projectile goes when the player is spinjumping to make it be shot """in front""" of the player 
		if p:mem(0x50, FIELD_BOOL) and p.holdingNPC == nil then
			dir = p.direction * -1
		end
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			poisonFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		v.direction = dir
		v.speedX = ((NPC.config[v.id].speed + 4) + p.speedX/3.5) * dir

		if p:mem(0x50, FIELD_BOOL) and data.playerBubbles == 0 then
		       local v = NPC.spawn(
				poisonFlower.projectileID,
				p.x + p.width/2 + (p.width/2 + 0) * -dir + p.speedX,
				p.y + p.height/2 + p.speedY, p.section, false, true
			)
			v.direction = dir * -1
			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir * -1
		end
		
		if p:mem(0x50, FIELD_BOOL) and data.playerBubbles == 0 then
			data.playerBubbles = data.playerBubbles + 2
		else
			data.playerBubbles = data.playerBubbles + 1
		end
		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
			-- this sets the npc to be held by the player
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			SFX.play(18)
		elseif linkChars[p.character] then -- handles shooting as link/snake/samus
			v.x = v.x + (16 * dir) -- adjust the npc a bit to look like it's being shot out of link's sword
			SFX.play(82)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1 -- adds extra vertical speed depending on how fast you were going vertically
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -2 + speedYMod
			else
				--v.speedY = -4
			end
			
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			
			SFX.play(18)
		end
        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
end

function poisonFlower.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= poisonFlower or not p.data.poisonFlower then return end -- check if the powerup is currently active
	
	local data = p.data.poisonFlower
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end
function poisonFlower.onNPCKill(e, v, r)
	if v.id ~= poisonFlower.projectileID or not player.data.poisonFlower then return end
	
	player.data.poisonFlower.playerBubbles = player.data.poisonFlower.playerBubbles - 1
	SFX.play(91)
end

return poisonFlower