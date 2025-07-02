local superBallFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

superBallFlower.projectileID = 958
superBallFlower.basePowerup = PLAYER_FIREFLOWER

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
local projectileTimerMax = {30, 60, 60, 25, 25}
local projectileTimer = {}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount < 2
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x12E, FIELD_BOOL) -- ducking
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

superBallFlower.aliases = {"ricochet","wowsoretro"}

function superBallFlower.onEnable(p)
    projectileTimer[p.idx] = 0
end

function superBallFlower.onDisable(p)
end

function superBallFlower.onTickPowerup(p)
    projectileTimer[p.idx] = math.max(projectileTimer[p.idx] - 1, 0)
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if projectileTimer[p.idx] > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE or restrictMovement then return end

    local count = 1

    if p:mem(0x50, FIELD_BOOL) then
        count = 2

        if p:isOnGround() then
            return
        end
    end

    if p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED or (p:mem(0x50, FIELD_BOOL) and p:mem(0x11C, FIELD_WORD) == 0) and not p:mem(0x50, FIELD_BOOL) then
        local mod = 1

        for i = 1, count do
            local dir = p.direction

            if p:mem(0x50, FIELD_BOOL) then
                dir = math.sign(i - 1.5)
                mod = 1.2
            end

            local v = NPC.spawn(
                superBallFlower.projectileID,
                p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
                p.y + p.height/2 + p.speedY, p.section, false, true
            )
            v.direction = p.direction
            v.speedY = 4
			if player.keys.up then
				local speedYMod = player.speedY * 0.1
				if player.standingNPC then
					speedYMod = player.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			end
        end

        SFX.play(18)
        projectileTimer[p.idx] = projectileTimerMax[p.character] * mod
    end
end

function superBallFlower.onTickEndPowerup(p)

	if player.character == CHARACTER_PEACH then
	
		animFrames = {
		10,10,10,9,9,9,9,9,9,
		}
	
	end

    local curFrame = animFrames[projectileTimerMax[p.character] - projectileTimer[p.idx]]
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    if projectileTimer[p.idx] > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end

function superBallFlower.onDrawPowerup(p)
    --Text.print(superBallFlower.name,100,100)
end

return superBallFlower