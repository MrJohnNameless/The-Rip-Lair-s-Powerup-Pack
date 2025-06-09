local cp = require("customPowerups")
local ninja = {}

function ninja.onInitPowerupLib()
	ninja.spritesheets = {
		ninja:registerAsset(1, "ninja-mario.png"),
		ninja:registerAsset(2, "ninja-luigi.png"),
	}

	ninja.iniFiles = {
		ninja:registerAsset(1, "ninja-mario.ini"),
		ninja:registerAsset(2, "ninja-luigi.ini"),
	}
end

ninja.settings = {
	aliases = {"ninjiwannabe","kickbackturnaroundandspin","hiyah"},
}

ninja.basePowerup = PLAYER_FIREFLOWER
ninja.projectileID = 764
ninja.items = {}
ninja.forcedStateType = 2

ninja.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

local activePlayer

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12} -- the animation frames for shooting a fireball

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

-- jump heights for mario, luigi, peach, toad, & link respectively
local jumpheights = {20,25,20,15,20}

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
		and not p.data.ninja.isNinjaClimbing
    )
end

-- runs once when the powerup gets activated, passes the player
function ninja.onEnable(p)	
	p.data.ninja = {
		projectileTimer = 0, -- don't remove this
		isNinjaClimbing = false,
		wallClingTimer = 0,
		wallCollider = 0,
		currentDir = 0,
		currentX = 0
	}
	
	if aw then aw.disable(p) end
end

-- runs once when the powerup gets deactivated, passes the player
function ninja.onDisable(p)	
	p.data.ninja = nil
	local ps = p:getCurrentPlayerSetting()
	ps.hitboxDuckHeight = 32
	
	if not p.data.noWallJumpByDefault then
		if aw then aw.enable(p) end
	end
end

registerEvent(ninja, "onExit", "onExit")

function ninja.onExit()
	if activePlayer then
		local ps = activePlayer:getCurrentPlayerSetting()
		activePlayer.hitboxDuckHeight = 32
		if aw then aw.enable(activePlayer) end
	end
end

-- runs when the powerup is active, passes the player
function ninja.onTickPowerup(p)

	if cp.getCurrentPowerup(p) ~= ninja or not p.data.ninja then return end -- check if the powerup is currenly active
	
	local data = p.data.ninja
	
	activePlayer = p
	
	if data.wallCollider == 0 then
		data.wallCollider = Colliders.Box(p.x, p.y, 16, 48)
	else
		data.wallCollider.x = p.x - 8 + ((p.direction + 1) * 12)
		data.wallCollider.y = p.y
	end
	
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
		
		-- reverses the direction the projectile goes when the player is spinjumping to make it be shot """in front""" of the player 
		if p:mem(0x50, FIELD_BOOL) and p.holdingNPC == nil then
			dir = p.direction * -1
		end
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			ninja.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
			-- this sets the npc to be held by the player
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			SFX.play(18)
			
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
			v.speedX = NPC.config[v.id].speed * dir
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			SFX.play(18)
		end
        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
	
	--Start grabbing a wall
	if (p:mem(0x148, FIELD_WORD) == 2 or p:mem(0x14C, FIELD_WORD) == 2) and not p:isOnGround() and p.data.ninja.wallClingTimer <= 0 and (p:mem(0x34, FIELD_WORD) == 0 and not p:isClimbing() and p.mount == 0) then
		data.isNinjaClimbing = true
		data.currentDir = p.direction
		data.currentX = p.x
	end
end

function ninja.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= ninja or not p.data.ninja then return end -- check if the powerup is currently active
	
	local data = p.data.ninja
	local ps = p:getCurrentPlayerSetting()
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

	if not p.data.ninja.isNinjaClimbing then
		if data.projectileTimer > 0 and canPlay and curFrame then
			p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
		end
		p.data.ninja.wallClingTimer = p.data.ninja.wallClingTimer - 1
		ps.hitboxDuckHeight = 32
	else
		--Frames for when climbing a wall
		if math.abs(p.speedY) <= 0.1 then
			p.frame = 32
			p.data.ninja.wallClingTimer = 0
		else
			p.data.ninja.wallClingTimer = p.data.ninja.wallClingTimer + 1
			p.frame = math.floor(p.data.ninja.wallClingTimer / 6) % 4 + 32
		end
		
		p.speedX = 0
		
		p.direction = p.data.ninja.currentDir
		p.x = p.data.ninja.currentX
		
		ps.hitboxDuckHeight = 56		
		
		--Control movement in regards to the wall
		if not p.keys.up and not p.keys.down then
			if p.character ~= 2 then
				p.speedY = -Defines.player_grav
			else
				p.speedY = -Defines.player_grav + 0.04
			end
		else
			if p.keys.up then
				p.speedY = -2
			else
				p.speedY = 2
			end
		end
		
		--End the ninja state if not on a wall anymore
		local tbl = Block.SOLID .. Block.PLAYER
		collidingBlocks = Colliders.getColliding {
			a = data.wallCollider,
			b = tbl,
			btype = Colliders.BLOCK
		}

		if #collidingBlocks == 0 or p.keys.jump == KEYS_PRESSED or p:isOnGround() or p.keys.altJump == KEYS_PRESSED or p:isClimbing() or p.mount ~= 0 or p:mem(0x34, FIELD_WORD) ~= 0 then --Not colliding with something
			data.isNinjaClimbing = false
			data.wallClingTimer = 16
			if p.speedY < 0 and not p.keys.jump then
				p.speedY = -6
			elseif p.keys.jump == KEYS_PRESSED and not p.keys.down then
				local finalHeight = 0 
				finalHeight = jumpheights[p.character]
				p:mem(0x11C,FIELD_WORD, finalHeight) -- sets the final jumpheight the player can have		
				SFX.play(1)
			end
		end
	end
end

return ninja