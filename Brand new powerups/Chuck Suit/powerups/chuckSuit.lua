local chuckSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

chuckSuit.projectileID = 775
chuckSuit.basePowerup = PLAYER_FIREFLOWER
chuckSuit.forcedStateType = 2
chuckSuit.cheats = {"needachucksuit"}


chuckSuit.chargeFX = Graphics.loadImageResolved("powerups/chuckSuit-chargeFX.png")
chuckSuit.chargeFrames = 3
chuckSuit.chargeFramespeed = 4

chuckSuit.maxSpeed = 10
chuckSuit.acceleration = 0.75
chuckSuit.dashWaitTime = 8
chuckSuit.playerFramespeed = 6
chuckSuit.cooldown = 16

chuckSuit.canThrow = true
chuckSuit.canDash = true


function chuckSuit.onInitPowerupLib()
    chuckSuit.spritesheets = {
        chuckSuit:registerAsset(CHARACTER_MARIO, "chuckSuit-mario.png"),
    }

    chuckSuit.iniFiles = {
        chuckSuit:registerAsset(CHARACTER_MARIO, "chuckSuit-mario.ini"),
    }
end


local animFrames = {11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12}
local projectileTimerMax = {30, 35, 40, 25, 25}

local dashFrames = {16, 17}
local dashFramesAir = {17}

local playerData = {}
local starShader = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))
local stompSfx = Misc.resolveSoundFile("chuck-stomp")

local blockBlacklist = {}
local blockWhitelist = {}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)


---------------------
-- Local Functions --
---------------------

local function canDoStuff(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == MOUNT_NONE
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x12E, FIELD_BOOL) -- ducking
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164, FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and not p:mem(0x50, FIELD_BOOL)
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

local function cancelDashing(p, data)
    data.dashTimer = -1
    data.cooldown = chuckSuit.cooldown
    data.holdingAltrun = true
    p.speedX = p.speedX * 3/4
end


------------------
-- CP Functions --
------------------

function chuckSuit.blacklist(id)
    blockBlacklist[id] = true
    blockWhitelist[id] = nil
end

function chuckSuit.whitelist(id)
    blockBlacklist[id] = nil
    blockWhitelist[id] = true
end

function chuckSuit.onEnable(p, noEffects)
    if not playerData[p.idx] then
        playerData[p.idx] = {
            projectileTimer = 0,
            dashTimer = -1,
            initDirection = 0,
            cooldown = 0,
            collider = Colliders.Box(0, 0, 1, 1),
            holdingAltrun = false,
        }
    end

    local data = playerData[p.idx]

    data.projectileTimer = 0
    data.dashTimer = -1
end

function chuckSuit.onDisable(p, noEffects)
    cancelDashing(p, playerData[p.idx])
    playerData[p.idx].dashCooldown = 0
end

function chuckSuit.onTickPowerup(p)
    local data = playerData[p.idx]
    local keyCombo = p.keys.run == KEYS_PRESSED and not p.keys.altRun
    local variousChecks = canDoStuff(p)

    data.projectileTimer = math.max(data.projectileTimer - 1, 0)
    data.cooldown = math.max(data.cooldown - 1, 0)

    if data.holdingAltrun and not p.keys.altRun then
        data.holdingAltrun = false
    end
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if variousChecks
    and keyCombo
    and data.projectileTimer == 0
    and data.dashTimer == -1
    and p:isOnGround()
    and chuckSuit.canThrow
    then
        local v = NPC.spawn(
            chuckSuit.projectileID,
            p.x + p.width/2 + 32 * p.direction,
            p.y + p.height, p.section
        )

        v.x = v.x - v.width/2
        v.y = v.y - v.height

        v.isProjectile = true
        v.direction = p.direction
        v.data.moveStartTime = 12

        data.projectileTimer = projectileTimerMax[p.character]
    end

    if variousChecks
    and p.keys.altRun
    and data.dashTimer <= chuckSuit.dashWaitTime
    and p:isOnGround()
    and (projectileTimerMax[p.character] - data.projectileTimer + 1) > #animFrames
    and data.cooldown == 0
    and not data.holdingAltrun
    and chuckSuit.canDash
    then
        if data.dashTimer == -1 then
            data.projectileTimer = 0
            data.dashTimer = 0
            data.initDirection = p.direction
        end

        p.speedX = p.speedX * 0.96

        if math.abs(p.speedX) < 1 then
            p.speedX = 0
        end

        p.keys.left = false
        p.keys.right = false
        p.direction = data.initDirection
    end

    if data.dashTimer >= 0 then
        data.dashTimer = data.dashTimer + 1
        p.keys.run = false

        if not p:isOnGround() then
            data.initDirection = p.direction
        end

        if (not p.keys.altRun or not variousChecks or p:mem(0x50, FIELD_BOOL))
        or (data.dashTimer <= chuckSuit.dashWaitTime and not p:isOnGround())
        or data.initDirection ~= p.direction
        then
            cancelDashing(p, data)
        end
    end

    if data.dashTimer > chuckSuit.dashWaitTime then
        p.speedX = math.clamp(p.speedX + chuckSuit.acceleration * p.direction, -chuckSuit.maxSpeed, chuckSuit.maxSpeed)

        if p.direction == 1 then
            p.keys.right = false
        elseif p.direction == -1 then
            p.keys.left = false
        end

        if p:isOnGround() then
            Effect.spawn(74, p.x + RNG.random(p.width/2) + 4 + p.speedX, p.y + p.height + RNG.random(-4, 4) - 4)

            if lunatime.tick() % 9 == 0 then
                SFX.play(stompSfx)
            end
        end

        local broken = false
        local stopDash = false

        for k, v in ipairs(Colliders.getColliding{a = data.collider, b = NPC.HITTABLE, btype = Colliders.NPC}) do
            v:harm(HARM_TYPE_NPC)

            if NPC.MULTIHIT_MAP[v.id] then
                cancelDashing(p, data)
                p.speedX = -2 * p.direction
                p.speedY = -6
                broken = true
                break
            end
        end

        if not broken then
            for k, v in ipairs(Colliders.getColliding{a = data.collider, b = Block.SOLID, btype = Colliders.BLOCK}) do
                local canBreak = (Block.MEGA_SMASH_MAP[v.id] or blockWhitelist[v.id]) and not blockBlacklist[v.id]

                if v.contentID == 0 and canBreak then
                    v:remove(true)
                else
                    v:hit(true, p)
                    stopDash = true
                end
            end
        end

        if stopDash then
            cancelDashing(p, data)
            p.speedX = -2 * p.direction
            p.speedY = -6

            local e = Effect.spawn(75, data.collider.x + data.collider.width/2, data.collider.y + data.collider.height/2)
            e.x = e.x - e.width/2
            e.y = e.y - e.height/2
        end
    end
end

function chuckSuit.onTickEndPowerup(p)
    local data = playerData[p.idx]

    data.collider.width = 32
    data.collider.height = p.height - 8
    data.collider.x = p.x + p.width/2 + data.collider.width/2 * p.direction - data.collider.width/2
    data.collider.y = p.y + p.height/2 - data.collider.height/2

    local variousChecks = canDoStuff(p)
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer + 1]

    if data.projectileTimer > 0 and variousChecks and curFrame then
        p:setFrame(curFrame)
    end

    if data.dashTimer == -1 then return end

    local frameTable

    if p:isOnGround() then
        frameTable = dashFrames
    else
        frameTable = dashFramesAir
    end

    curFrame = frameTable[(math.floor(data.dashTimer / chuckSuit.playerFramespeed) % #frameTable) + 1]

    if variousChecks and curFrame then
        p:setFrame(curFrame)
    end
end

function chuckSuit.onDrawPowerup(p)
    local data = playerData[p.idx]

    if data.dashTimer > chuckSuit.dashWaitTime and p.forcedState ~= 8 and not p:mem(0x142, FIELD_BOOL) and p.deathTimer == 0 then
        local img = chuckSuit.chargeFX
        local width = img.width
        local height = img.height/chuckSuit.chargeFrames

        local curFrame = math.floor(data.dashTimer / chuckSuit.chargeFramespeed) % chuckSuit.chargeFrames

        Graphics.drawBox{
            texture = img,

            x = p.x + p.width/2,
            y = p.y + p.height/2,

            width = width * p.direction,
            height = width,

            sourceX = 0,
            sourceY = curFrame * width,

            sourceWidth = width,
            sourceHeight = width,

            priority = -25,
            sceneCoords = true,
            centered = true,

            shader = (p.hasStarman and starShader) or nil,
            uniforms = (p.hasStarman and {time = lunatime.tick() * 2}) or nil,
        }
    end
end

return chuckSuit