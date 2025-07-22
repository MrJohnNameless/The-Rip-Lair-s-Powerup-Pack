local superBallFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

superBallFlower.projectileID = 958
superBallFlower.basePowerup = PLAYER_FIREFLOWER
superBallFlower.cheats = {"needasuperball","ricochet","wowsoretro"}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

function superBallFlower.onInitPowerupLib()
    superBallFlower.spritesheets = {
        superBallFlower:registerAsset(1, "mario-ap-superball.png"),
        superBallFlower:registerAsset(2, "luigi-ap-superball.png"),
        superBallFlower:registerAsset(3, "peach-ap-superball.png"),
        superBallFlower:registerAsset(4, "toad-ap-superball.png"),
    }

    superBallFlower.iniFiles = {
        superBallFlower:registerAsset(1, "mario-ap-superball.ini"),
        superBallFlower:registerAsset(2, "luigi-ap-superball.ini"),
        superBallFlower:registerAsset(3, "peach-ap-superball.ini"),
        superBallFlower:registerAsset(4, "toad-ap-superball.ini"),
    }

    superBallFlower.gpImages = {
        superBallFlower:registerAsset(CHARACTER_MARIO, "superball-groundPound-1.png"),
        superBallFlower:registerAsset(CHARACTER_LUIGI, "superball-groundPound-2.png"),
    }
end

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12}
local projectileTimerMax = {30, 35, 40, 25, 40}
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



function superBallFlower.onEnable(p)
    lastDirection[p.idx] = p.direction * -1
end

function superBallFlower.onDisable(p)
end


function superBallFlower.onTickPowerup(p)
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

    if p.isSpinJumping and p.holdingNPC == nil then
		p:mem(0x160, FIELD_WORD,1) -- also needed to prevent a base powerup's projectile from shooting while spinjumping for this particular powerup reason
        if p:isOnGround() then
            return
        end
    end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then

		local dir = p.direction

		if p.isSpinJumping and projectileTimerMax[p.character] % 2 ~= 0 then
			if p:mem(0x52,FIELD_WORD) % 2 == 0 then
				dir = p:mem(0x54,FIELD_WORD) * -1
			else
				dir = p:mem(0x54,FIELD_WORD)
			end
		end
		
		local v = NPC.spawn(
			superBallFlower.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
		)
		v.data.owner = p
		
		local speedYMod = p.speedY * 0.1
		local holdingUp = 0
		local xSlowDown = 0
		
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p:mem(0x12E,FIELD_BOOL) then
				v.y = v.y + 4
			else
				v.y = v.y - 14
			end
			v.x = v.x + (16 * dir)
			v.isProjectile = true
			v.speedX = ((NPC.config[v.id].speed + 4) + p.speedX/3.5) * dir
		else
			-- handles making the projectile be held if the player is a SMB2 character & pressed altRun 
			if smb2Chars[p.character] and p.holdingNPC == nil and p.keys.altRun then 
				v.speedY = 0
				v.heldIndex = p.idx
				p:mem(0x154, FIELD_WORD, v.idx+1)
			else -- handles normal shooting
			   speedYMod = speedYMod * 1.5
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				if p.keys.up then
					v.speedY = -6
				else
					v.speedY = 4
				end
				v.speedY = v.speedY + speedYMod + holdingUp
				v.ai1 = p.character
				v.speedX = dir * (6 + xSlowDown)
				v:mem(0x156, FIELD_WORD, 32)
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

function superBallFlower.onTickEndPowerup(p)
	if not p.isSpinJumping then
		lastDirection[p.idx] = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,lastDirection[p.idx]) -- prevents a base powerup's projectile from shooting while spinjumping
end

function superBallFlower.onDrawPowerup(p)
    --Text.print(superBallFlower.name,100,100)
end

return superBallFlower