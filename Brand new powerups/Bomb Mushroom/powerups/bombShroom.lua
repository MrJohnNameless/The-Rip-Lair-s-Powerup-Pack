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
bombShroom.basePowerup = PLAYER_FIREFLOWER

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12}
local projectileTimerMax = {64, 64, 64, 64, 64}
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

bombShroom.aliases = {"icallthestorm","andthenalongcamezeus"}

function bombShroom.onEnable(p)
    projectileTimer[p.idx] = 0
end

function bombShroom.onDisable(p)
end

function bombShroom.onTickPowerup(p)
    projectileTimer[p.idx] = math.max(projectileTimer[p.idx] - 1, 0)
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if projectileTimer[p.idx] > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

    local count = 1

    if p:mem(0x50, FIELD_BOOL) then
        count = 2

        if p:isOnGround() then
            return
        end
    end

    if p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED or (p:mem(0x50, FIELD_BOOL) and p:mem(0x11C, FIELD_WORD) == 0) then
        local mod = 1

        for i = 1, count do
            local dir = p.direction

            if p:mem(0x50, FIELD_BOOL) then
                dir = math.sign(i - 1.5)
                mod = 1.2
            end

            local v = NPC.spawn(
                bombShroom.projectileID,
                p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
                p.y + p.height/2 + p.speedY, p.section, false, true
            )
            
			 local speedYMod = p.speedY * 0.1
			 local holdingUp = 0
			 local xSlowDown = 0
			
            if p.keys.up then
               speedYMod = speedYMod * 1.5
                if p.standingNPC then
                    speedYMod = p.standingNPC.speedY * 0.1
                end
               holdingUp = -7
			   xSlowDown = -2
            end

			 v.speedY = -2 + speedYMod + holdingUp

            v.ai1 = p.character
            v.speedX = dir * (6 + xSlowDown)
            v:mem(0x156, FIELD_WORD, 32)
        end

        SFX.play(18)
        projectileTimer[p.idx] = projectileTimerMax[p.character] * mod
    end
end

function bombShroom.onTickEndPowerup(p)
    local curFrame = animFrames[projectileTimerMax[p.character] - projectileTimer[p.idx]]
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    if projectileTimer[p.idx] > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end

return bombShroom
