local bubbleFlowerSMW = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

bubbleFlowerSMW.projectileID = 817
bubbleFlowerSMW.basePowerup = PLAYER_FIREFLOWER
bubbleFlowerSMW.shootSFX = 7

bubbleFlowerSMW.cheats = {"needabubbleflower"}

function bubbleFlowerSMW.onInitPowerupLib()
    bubbleFlowerSMW.spritesheets = {
        bubbleFlowerSMW:registerAsset(CHARACTER_MARIO, "bubbleFlowerSMW-mario.png"),
        bubbleFlowerSMW:registerAsset(CHARACTER_LUIGI, "bubbleFlowerSMW-luigi.png"),
		bubbleFlowerSMW:registerAsset(CHARACTER_PEACH, "bubbleFlowerSMW-peach.png"),
        bubbleFlowerSMW:registerAsset(CHARACTER_TOAD, "bubbleFlowerSMW-toad.png"),
		bubbleFlowerSMW:registerAsset(CHARACTER_LINK, "bubbleFlowerSMW-link.png"),
    }

    bubbleFlowerSMW.iniFiles = {
        bubbleFlowerSMW:registerAsset(CHARACTER_MARIO, "bubbleFlowerSMW-mario.ini"),
        bubbleFlowerSMW:registerAsset(CHARACTER_LUIGI, "bubbleFlowerSMW-luigi.ini"),
		bubbleFlowerSMW:registerAsset(CHARACTER_PEACH, "bubbleFlowerSMW-peach.ini"),
		bubbleFlowerSMW:registerAsset(CHARACTER_TOAD, "bubbleFlowerSMW-toad.ini"),
		bubbleFlowerSMW:registerAsset(CHARACTER_LINK, "bubbleFlowerSMW-link.ini"),
    }

    bubbleFlowerSMW.gpImages = {
        bubbleFlowerSMW:registerAsset(CHARACTER_MARIO, "bubbleFlowerSMW-groundPound-1.png"),
        bubbleFlowerSMW:registerAsset(CHARACTER_LUIGI, "bubbleFlowerSMW-groundPound-2.png"),
    }
end

local animFrames = {12, 12, 12, 11, 11, 11, 11, 11, 11}
local projectileTimerMax = {55, 55, 55, 50, 40}
local lastDirection = {}

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

function bubbleFlowerSMW.onEnable(p)
    lastDirection[p.idx] = p.direction * -1
	
	p.data.bubbleFlowerSMW = {
		canShoot = true
	}
end

function bubbleFlowerSMW.onDisable(p)
	p.data.bubbleFlowerSMW = nil
end

function bubbleFlowerSMW.onTickPowerup(p)
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
		count = 2
        if p:isOnGround() then
            return
        end
    end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED or (p:mem(0x50, FIELD_BOOL) and p:mem(0x11C, FIELD_WORD) == 0)
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	
    if ((tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2) and p.data.bubbleFlowerSMW.canShoot == true then
		local mod = 1
        for i = 1, count do
			local dir = p.direction

			if p:mem(0x50, FIELD_BOOL) then
				dir = math.sign(i - 1.5)
				mod = 1.2
			end

			local v = NPC.spawn(
				bubbleFlowerSMW.projectileID,
				p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
				p.y + p.height/2 + p.speedY, p.section, false, true
			)

            v.ai1 = p.character
            v.speedX = NPC.config[v.id].thrownSpeed * dir + (p.speedX * 2)
			if math.abs(p.speedX) < 0.5 then
				v.speedX = NPC.config[v.id].thrownSpeed * dir
			end
			p.data.bubbleFlowerSMW.canShoot = false
            v:mem(0x156, FIELD_WORD, 32)
			
			-- handles shooting as link/snake/samus
			if linkChars[p.character] then 
				-- shoot less higher when ducking
				if p:mem(0x12E,FIELD_BOOL) then
					v.y = v.y + 4
				else
					v.y = v.y - 14
				end
				p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
				SFX.play(bubbleFlowerSMW.shootSFX)
				if flamethrowerActive then
					p:mem(0x162, FIELD_WORD,2)
				end
			else
				p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
				SFX.play(bubbleFlowerSMW.shootSFX)
				if not p.isSpinJumping then
					p:mem(0x118, FIELD_FLOAT,110)
				end
				if flamethrowerActive then
					p:mem(0x160, FIELD_WORD,30)
				end
			end
        end
    else
		if not p.data.bubbleFlowerSMW.canShoot then
			if p.character ~= CHARACTER_LINK then
				p:mem(0x160, FIELD_WORD, 2)
			elseif p.mount < 2 then
				p:mem(0x162, FIELD_WORD, 2)
			end
		end
	end
end

function bubbleFlowerSMW.onTickEndPowerup(p)
	if not p.isSpinJumping then
		lastDirection[p.idx] = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,lastDirection[p.idx]) -- prevents a base powerup's projectile from shooting while spinjumping
end

return bubbleFlowerSMW