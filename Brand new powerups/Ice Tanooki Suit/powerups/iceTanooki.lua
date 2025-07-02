local leaf = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

leaf.basePowerup = PLAYER_TANOOKI
leaf.forcedStateType = 2

leaf.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

leaf.projectileID = 265

function leaf.onInitPowerupLib()
    leaf.spritesheets = {
        leaf:registerAsset(1, "icetanooki-mario.png"),
        leaf:registerAsset(2, "icetanooki-luigi.png"),
        leaf:registerAsset(3, "icetanooki-peach.png"),
        leaf:registerAsset(4, "icetanooki-toad.png"),
        leaf:registerAsset(5, "icetanooki-link.png"),
    }
end

local projectileTimerMax = {30, 60, 60, 25, 25}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
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
        and (not p:mem(0x12E, FIELD_BOOL) or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function leaf.onTickPowerup(p)
    if p.mount > MOUNT_BOOT then return end
    if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

	if linkChars[p.character] then
		if p:mem(0x162,FIELD_WORD) > 0 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

    if p.isSpinJumping and p:isOnGround() then return end

	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.run == KEYS_PRESSED and not p.keys.altRun) or p.isSpinJumping
	
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
			leaf.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
		)
		
		local speedYMod = p.speedY * 0.1

		v.speedX = (5 + math.abs(p.speedX)/3.5) * dir
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p:mem(0x12E,FIELD_BOOL) then
				v.y = v.y + 4
			else
				v.y = v.y - 14
			end
			v.x = v.x + (16 * dir)
			v.ai1 = 5
		else
			v.ai1 = 1
			speedYMod = speedYMod * 1.5
			if p.standingNPC then
				speedYMod = p.standingNPC.speedY * 0.1
			end
			if p.keys.up then
				v.speedY = -6
			else
				v.speedY = 20
			end
			v.speedY = v.speedY + speedYMod
			v.ai1 = p.character
		end
		if linkChars[p.character] then 
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,0)
			end
		else 
			p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
			SFX.play(18)
			if flamethrowerActive then
				p:mem(0x160, FIELD_WORD,30)
			end
		end
    end
end
return leaf