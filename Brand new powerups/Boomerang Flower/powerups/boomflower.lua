local boomerangFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

boomerangFlower.projectileID = 760
boomerangFlower.projectileCap = 1
boomerangFlower.basePowerup = PLAYER_HAMMER
boomerangFlower.cheats = {"needaboomerangflower","tythetiger"}

function boomerangFlower.onInitPowerupLib()
    boomerangFlower.spritesheets = {
        boomerangFlower:registerAsset(1, "boomflower-mario.png"),
        boomerangFlower:registerAsset(2, "boomflower-luigi.png"),
        boomerangFlower:registerAsset(3, "boomflower-peach.png"),
        boomerangFlower:registerAsset(4, "boomflower-toad.png"),
    }
    boomerangFlower.iniFiles = {
		boomerangFlower:registerAsset(1, "boomflower-mario.ini"),
		boomerangFlower:registerAsset(2, "boomflower-luigi.ini"),
		boomerangFlower:registerAsset(3, "boomflower-peach.ini"),
		boomerangFlower:registerAsset(4, "boomflower-toad.ini"),
	}
end

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
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function boomerangFlower.onInitAPI()
	registerEvent(boomerangFlower,"onNPCKill")
end

function boomerangFlower.onEnable(p)
	p.data.boomerangFlower = {
		thrownBoomerangs = {}
	}
	p:mem(0x162,FIELD_WORD,5) -- prevents link from shooting a base projectile whenever collecting the powerup with his sword
end

function boomerangFlower.onDisable(p)
	p.data.boomerangFlower = nil
end

function boomerangFlower.onTickPowerup(p)
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
    if not p.data.boomerangFlower then return end
	local data = p.data.boomerangFlower
	
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,5)
	else
		p:mem(0x160, FIELD_WORD,5)
	end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED) and not p:mem(0x50, FIELD_BOOL)
	
	if #data.thrownBoomerangs >= boomerangFlower.projectileCap and not flamethrowerActive then return end
    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive and lunatime.tick() % 8 == 0 then 
		tryingToShoot = true
	end

    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
		local dir = p.direction

		local v = NPC.spawn(
				boomerangFlower.projectileID,
				p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
				p.y + p.height/2 + p.speedY, p.section, false, true
		)

		v.direction = p.direction

		if boomerangFlower.projectileID == 292 then
			v.x = v.x - (32 * dir)
			v.speedX = 50 * v.direction + v.speedX
			v.speedY = -5
			v.ai5 = 1
		else
			v.speedX = 10 * v.direction
			v.data.owner = p
		end
		table.insert(data.thrownBoomerangs,v) -- makes the player "own" the laser they shot
		
		if linkChars[p.character] then
			SFX.play(82)
		else
			p:mem(0x118, FIELD_FLOAT,110)
			SFX.play(18)
		end
    end
end

function boomerangFlower.onNPCKill(token,v,harm,c)
	if v.id ~= boomerangFlower.projectileID then return end
	for _,p in ipairs(Player.get()) do
		if p.data.boomerangFlower then
			local data = p.data.boomerangFlower
			for i,n in ipairs(data.thrownBoomerangs) do
				if n.isValid and n == v then
					table.remove(data.thrownBoomerangs, i) -- makes the player "disown" the boomerang they thrown
					break
				end
			end
		end
	end
end

return boomerangFlower