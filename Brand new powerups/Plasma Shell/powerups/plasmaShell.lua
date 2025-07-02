local plasmaShell = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "iniFiles",
-- "cheats", "registerAsset", "getAsset", "pathFormat", "costumePathFormat", "forcedStateType"

-- everything except "name", "id", "registerAsset" and "getAsset" can be safely modified


plasmaShell.projectileID = 880
plasmaShell.basePowerup = PLAYER_FIREFLOWER
plasmaShell.cheats = {"needaplasmashell"}

function plasmaShell.onInitPowerupLib()
    plasmaShell.spritesheets = {
        plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-mario.png"),
        plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-luigi.png"),
        plasmaShell:registerAsset(CHARACTER_PEACH, "plasmaShell-toad.png"),	-- placeholder
        plasmaShell:registerAsset(CHARACTER_TOAD,  "plasmaShell-toad.png"),
    }

    plasmaShell.iniFiles = {
        plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-mario.ini"),
        plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-luigi.ini"),
        plasmaShell:registerAsset(CHARACTER_PEACH, "plasmaShell-toad.ini"),	-- placeholder
        plasmaShell:registerAsset(CHARACTER_TOAD,  "plasmaShell-toad.ini"),
    }

    plasmaShell.gpImages = {
        --plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-groundPound-1.png"),
        --plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-groundPound-2.png"),
    }
end


local animFrames = {1, 1, 1, 13, 13, 13, -1, -1 , -1, 15, 15, 15, 11, 11, 12, 12}
local projectileTimerMax = {50, 50, 60, 40, 40}
local projectileTimer = {}

local linkChars = table.map{5,12,16}

local GP
pcall(function() GP = require("GroundPound") end)

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
        and (not p.isDucking or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function plasmaShell.onEnable(p)
	p.data.plasmaShell = {
		projectileTimer = 0,
		wasGrounded = p:isOnGround()
	}
end

function plasmaShell.onDisable(p)
	p.data.plasmaShell = nil
end

function plasmaShell.onTickPowerup(p)
	if not p.data.plasmaShell then return end
	local data = p.data.plasmaShell
    data.projectileTimer = math.max(data.projectileTimer - 1, 0)
    
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	
	if p:isOnGround() then 
		data.wasGrounded = true
	end
	
	if p.isSpinJumping or (p.keys.altRun == KEYS_PRESSED and linkChars[p.character]) then
		p:mem(0x160,FIELD_WORD,2)
	end
	 
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
    if (tryingToShoot and (p.keys.altRun or not linkChars[p.character]) and data.wasGrounded) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		local v = NPC.spawn(
			plasmaShell.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
		)
		
		local speedYMod = p.speedY * 0.1
		if p.standingNPC then
			speedYMod = p.standingNPC.speedY * 0.1
		end
		
		if (p.keys.up and not linkChars[p.character]) then
			v.speedY = -9 + speedYMod
		end
		
		v.ai1 = p.character
		if p.keys.altRun == KEYS_PRESSED and data.wasGrounded then	-- if altRun was pressed, the player shall immediately explode upwards, starting a spinjump
			v.x = p.x + p.width * 0.5 - v.width * 0.5
			v.y = p.y + p.height * 0,5 - v.height * 0.5
			v:kill()										-- makes the shell immediately explode
			p.speedY = math.min(-10,p.speedY)				-- bounce the player up
			
			p:mem(0x18,FIELD_BOOL,false)					-- no hovering for Peach after bouncing up
			p:mem(0x1C,FIELD_WORD,0)						-- stop hovering when bouncing up
			p:mem(0x11C,FIELD_WORD,0)						-- stop jumping
			
			if p.character ~= 3 and not linkChars[p.character] then	-- make characters spinjump (not peach and Link since they usually can't)
				p:mem(0x50,FIELD_BOOL,true)
			end
			
			data.wasGrounded = false
		end
		v.speedX = NPC.config[v.id].thrownSpeed * dir + p.speedX/3.5
		v:mem(0x156, FIELD_WORD, 32)	-- I frames
	
		if linkChars[p.character] and not p.keys.altRun then
			if p.isDucking then
				v.y = v.y + 6
				v.speedY = -4 + speedYMod
			else
				v.y = v.y - 16
				v.speedY = -7 + speedYMod
			end
			v.x = v.x + (16 * dir)
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
		else
			p.speedY = math.min(-3,p.speedY)
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
			data.projectileTimer = projectileTimerMax[p.character]
			SFX.play(18)

			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
	end
end

function plasmaShell.onTickEndPowerup(p)
	if not p.data.plasmaShell then return end
	local data = p.data.plasmaShell
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer]
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end

return plasmaShell