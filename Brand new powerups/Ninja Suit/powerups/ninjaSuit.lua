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

local activePlayers = {}

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
		and (not p.data.ninjaSuit or not p.data.ninjaSuit.isNinjaClimbing)
    )
end

-- runs once when the powerup gets activated, passes the player
function ninja.onEnable(p)	
	local ps = p:getCurrentPlayerSetting()
	p.data.ninjaSuit = {
		lastDirection = p.direction * -1, -- don't remove this unless you know what you're doing
		originalDuckHeight = ps.hitboxDuckHeight,
		isNinjaClimbing = false,
		wallClingTimer = 0,
		wallCollider = 0,
		currentDir = 0,
		currentX = 0
	}
end

-- runs once when the powerup gets deactivated, passes the player
function ninja.onDisable(p)
	local ps = p:getCurrentPlayerSetting()
	ps.hitboxDuckHeight = p.data.ninjaSuit.originalDuckHeight
	p.data.ninjaSuit = nil
end

registerEvent(ninja, "onExit", "onExit")

function ninja.onExit()
	for i,p in ipairs(Player.get()) do
		if activePlayers[p.idx] and p.data.ninjaSuit then
			local ps = p:getCurrentPlayerSetting()
			ps.hitboxDuckHeight = p.data.ninjaSuit.originalDuckHeight
		end
	end
end

-- runs when the powerup is active, passes the player
function ninja.onTickPowerup(p)

	if cp.getCurrentPowerup(p) ~= ninja or not p.data.ninjaSuit then return end -- check if the powerup is currenly active
	
	if aw then aw.preventWallSlide(p) end
	
	local data = p.data.ninjaSuit
	
	activePlayers[p.idx] = true
	
	if data.wallCollider == 0 then
		data.wallCollider = Colliders.Box(p.x, p.y, 16, 48)
	else
		data.wallCollider.x = p.x - 8 + ((p.direction + 1) * 12)
		data.wallCollider.y = p.y
	end
	
	--Start grabbing a wall
	if (p:mem(0x148, FIELD_WORD) == 2 or p:mem(0x14C, FIELD_WORD) == 2) and not p:isOnGround() 
	and data.wallClingTimer <= 0 and (p:mem(0x34, FIELD_WORD) == 0 and not p:isClimbing() and p.mount == 0) then
		data.isNinjaClimbing = true
		data.currentDir = p.direction
		data.currentX = p.x
	end

	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if p.isSpinJumping and p:isOnGround() then return end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p.isSpinJumping) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			ninja.projectileID,
			p.x + p.width/2 + (p.width/2) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		v.direction = dir
		v.speedX = (NPC.config[v.id].speed * dir) + p.speedX/3.5
		v.speedY = 0
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p.isDucking then
				v.y = v.y + 6
			else
				v.y = v.y - 12
			end
			v.x = v.x + (16 * dir)
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
			return
		end
		-- handles making the projectile be held if the player is a SMB2 character & pressed altRun 
		if smb2Chars[p.character] and p.holdingNPC == nil and p.keys.altRun then 
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
		else
			p:mem(0x118, FIELD_FLOAT,110) -- set the player to do the shooting animation
		end
		p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
		SFX.play(18)

		if flamethrowerActive then
			p:mem(0x160, FIELD_WORD,30)
		end
    end
end

function ninja.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= ninja or not p.data.ninjaSuit then return end -- check if the powerup is currently active
	
	local data = p.data.ninjaSuit
	local ps = p:getCurrentPlayerSetting()
	
	if not p.isSpinJumping then
		data.lastDirection = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,data.lastDirection) -- prevents a base powerup's projectile from shooting while spinjumping
	
    local curFrame = nil
    local canPlay = canPlayShootAnim(p) and not p.isSpinJumping and not linkChars[p.character]

	if data.isNinjaClimbing then
		--Frames for when climbing a wall
		if math.abs(p.speedY) <= 0.1 then
			p.frame = 32
			data.wallClingTimer = 0
		else
			data.wallClingTimer = data.wallClingTimer + 1
			p.frame = math.floor(data.wallClingTimer / 6) % 4 + 32
		end
		
		p.speedX = 0
		
		p.direction = data.currentDir
		p.x = data.currentX
		
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
			ps.hitboxDuckHeight = p.data.ninjaSuit.originalDuckHeight
		end
	else
		data.wallClingTimer = math.max(data.wallClingTimer - 1, 0) -- decrement the projectile timer/cooldown
	end
end

return ninja