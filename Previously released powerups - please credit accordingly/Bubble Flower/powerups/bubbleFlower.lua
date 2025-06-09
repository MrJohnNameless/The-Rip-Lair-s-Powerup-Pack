local bubbleFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

bubbleFlower.projectileID = 752
bubbleFlower.basePowerup = PLAYER_FIREFLOWER

bubbleFlower.cheats = {"needabubbleflower"}

function bubbleFlower.onInitPowerupLib()
    bubbleFlower.spritesheets = {
        bubbleFlower:registerAsset(CHARACTER_MARIO, "bubbleFlower-mario.png"),
        bubbleFlower:registerAsset(CHARACTER_LUIGI, "bubbleFlower-luigi.png"),
    }

    bubbleFlower.iniFiles = {
        bubbleFlower:registerAsset(CHARACTER_MARIO, "bubbleFlower-mario.ini"),
        bubbleFlower:registerAsset(CHARACTER_LUIGI, "bubbleFlower-luigi.ini"),
    }

    bubbleFlower.gpImages = {
        bubbleFlower:registerAsset(CHARACTER_MARIO, "bubbleFlower-groundPound-1.png"),
        bubbleFlower:registerAsset(CHARACTER_LUIGI, "bubbleFlower-groundPound-2.png"),
    }
end

local animFrames = {12, 12, 12, 11, 11, 11, 11, 11, 11}
local projectileTimerMax = {60, 60, 60, 25, 25}
local projectileTimer = {}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canShoot(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and (p.mount == MOUNT_NONE or p.mount == MOUNT_BOOT)
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
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

function bubbleFlower.onEnable(p)
    projectileTimer[p.idx] = 0
end

function bubbleFlower.onDisable(p)
end

function bubbleFlower.onTickPowerup(p)
    projectileTimer[p.idx] = math.max(projectileTimer[p.idx] - 1, 0)
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if projectileTimer[p.idx] > 0 or not canShoot(p) then return end

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
                bubbleFlower.projectileID,
                p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
                p.y + p.height/2 + p.speedY, p.section, false, true
            )
            
            if p.keys.up then
                local speedYMod = p.speedY * 0.1
                if p.standingNPC then
                    speedYMod = p.standingNPC.speedY * 0.1
                end
                v.speedY = -1 + speedYMod
            end

            v.ai1 = p.character
            v.speedX = NPC.config[v.id].thrownSpeed * dir + p.speedX/3.5
            v:mem(0x156, FIELD_WORD, 32)
        end

        SFX.play(18)
        projectileTimer[p.idx] = projectileTimerMax[p.character] * mod
    end
end

function bubbleFlower.onTickEndPowerup(p)
    local curFrame = animFrames[projectileTimerMax[p.character] - projectileTimer[p.idx]]
    local canPlay = canShoot(p) and not p:mem(0x50,FIELD_BOOL) and p.mount == MOUNT_NONE

    if projectileTimer[p.idx] > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end

return bubbleFlower