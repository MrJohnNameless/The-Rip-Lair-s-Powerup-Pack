local cp = require("customPowerups")

local spikeball = {}

function spikeball.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	spikeball.spritesheets = {
		spikeball:registerAsset(1, "spikeball-mario.png"),
		spikeball:registerAsset(2, "spikeball-luigi.png"),
	}
end

spikeball.projectileID = 844
spikeball.basePowerup = PLAYER_HAMMER

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {12, 12, 12, 12, 11, 11, 11, 11} -- the animation frames for shooting a fireball


-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

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

-- runs once when the powerup gets activated, passes the player
function spikeball.onEnable(p)	
	p.data.spikeball = {
		projectileTimer = 0, -- don't remove this
	}
end

-- runs once when the powerup gets deactivated, passes the player
function spikeball.onDisable(p)	
	p.data.spikeball = nil
end

-- runs when the powerup is active, passes the player
function spikeball.onTickPowerup(p) 
	if not p.data.spikeball then return end -- check if the powerup is currenly active
	local data = p.data.spikeball
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

   if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end -- if spinjumping while on the ground
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			spikeball.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.speedY, p.section, false, true
        )
		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun then
			-- this sets the npc to be held by the player
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			SFX.play(25)
			
			-- put your own code here!
			
		elseif linkChars[p.character] then -- handles shooting as link/snake/samus
			if p:mem(0x12E,FIELD_BOOL) then -- if ducking, have the npc not rise higher
				v.speedY = -2
			else
				v.speedY = -5
			end
			v.x = v.x + (16 * dir) -- adjust the npc a bit to look like it's being shot out of link's sword
			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
			
			-- put your own code here!
			
			SFX.play(82)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			else
				v.speedY = -2
			end

			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
			v.direction = dir
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			
			-- put your own code here!
			
			SFX.play(25)
		end
        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
end

function spikeball.onTickEndPowerup(p)
	if not p.data.spikeball then return end -- check if the powerup is currently active
	
	local data = p.data.spikeball
	
	-- put your own code here!
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

function spikeball.onDrawPowerup(p)
	if not p.data.spikeball then return end -- check if the powerup is currently active
	local data = p.data.spikeball
	-- put your own code here!
end

return spikeball