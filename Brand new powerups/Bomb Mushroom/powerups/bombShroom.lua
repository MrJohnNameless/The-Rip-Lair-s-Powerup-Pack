local bombShroom = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function bombShroom.onInitPowerupLib()
    bombShroom.spritesheets = {
        bombShroom:registerAsset(1, "bombShroom_mario.png"),
        bombShroom:registerAsset(2, "bombShroom_luigi.png"),
    }

    bombShroom.iniFiles = {
        bombShroom:registerAsset(1, "bombShroom_mario.ini"),
        bombShroom:registerAsset(2, "bombShroom_luigi.ini"),
    }
end

bombShroom.projectileID = 841
bombShroom.cheats = {"needabombshroom","bombsaway"}
bombShroom.basePowerup = PLAYER_FIREFLOWER

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local projectileTimerMax = {64, 64, 64, 64, 70}
local lastDirection = {}

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

function bombShroom.onEnable(p)
	lastDirection[p.idx] = p.direction * -1
end

function bombShroom.onDisable(p)
end

function bombShroom.onTickPowerup(p)
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end
	
    local count = 1

    if p.isSpinJumping and p.holdingNPC == nil then
		p:mem(0x160, FIELD_WORD,1) -- also needed to prevent a base powerup's projectile from shooting while spinjumping for this particular powerup reason

        if p:isOnGround() then
            return
        end
    end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED or (p:mem(0x50, FIELD_BOOL) and p:mem(0x11C, FIELD_WORD) == 0)
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        for i = 1, count do
			local dir = p.direction

			if p:mem(0x50, FIELD_BOOL) then
				dir = math.sign(i - 1.5)
			end

			local v = NPC.spawn(
				bombShroom.projectileID,
				p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
				p.y + p.height/2 + p.speedY, p.section, false, true
			)
			
			local speedYMod = p.speedY * 0.1
			local holdingUp = 0

			v.speedX = (4 + p.speedX/3.5) * dir
			
			-- handles shooting as link/snake/samus
			if linkChars[p.character] then 
				-- shoot less higher when ducking
				if p:mem(0x12E,FIELD_BOOL) then
					v.speedY = 2
				else
					v.speedY = 4
				end
				v.x = v.x + (16 * dir)
				v.isProjectile = true
				
			else
				-- handles making the projectile be held if the player is a SMB2 character & pressed altRun 
				if smb2Chars[p.character] and p.holdingNPC == nil and p.keys.altRun then 
					v.speedY = 0
					v.heldIndex = p.idx
					p:mem(0x154, FIELD_WORD, v.idx+1)
					break
				else -- handles normal shooting
					if p.keys.up then
					   speedYMod = speedYMod * 1.5
						if p.standingNPC then
							speedYMod = p.standingNPC.speedY * 0.1
						end
					   holdingUp = -7
					end
					v.speedY = -2 + speedYMod + holdingUp
					v.ai1 = p.character
					v:mem(0x156, FIELD_WORD, 32)
				end
			end
        end
		if linkChars[p.character] then 
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
		else
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
			SFX.play(18)
			if not p.isSpinJumping then
				p:mem(0x118, FIELD_FLOAT,110)
			end
			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
    end
end

function bombShroom.onTickEndPowerup(p)
	if not p.isSpinJumping then
		lastDirection[p.idx] = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,lastDirection[p.idx]) -- prevents a base powerup's projectile from shooting while spinjumping
end

return bombShroom
