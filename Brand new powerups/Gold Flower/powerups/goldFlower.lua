local goldFlower = {}
local cp

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

goldFlower.projectileID = 754
goldFlower.basePowerup = PLAYER_FIREFLOWER
goldFlower.cheats = {"needagoldflower", "wannagetrich"}

goldFlower.transformOnLevelEnd = true

function goldFlower.onInitPowerupLib()
    goldFlower.spritesheets = {
        goldFlower:registerAsset(CHARACTER_MARIO, "goldFlower-mario.png"),
        goldFlower:registerAsset(CHARACTER_LUIGI, "goldFlower-luigi.png"),
        goldFlower:registerAsset(CHARACTER_PEACH, "goldFlower-peach.png"),
        goldFlower:registerAsset(CHARACTER_TOAD,  "goldFlower-toad.png"),
    }

    goldFlower.iniFiles = {
        goldFlower:registerAsset(CHARACTER_MARIO, "goldFlower-mario.ini"),
        goldFlower:registerAsset(CHARACTER_LUIGI, "goldFlower-luigi.ini"),
        goldFlower:registerAsset(CHARACTER_PEACH, "goldFlower-peach.ini"),
        goldFlower:registerAsset(CHARACTER_TOAD,  "goldFlower-toad.ini"),
    }

    goldFlower.gpImages = {
        goldFlower:registerAsset(CHARACTER_MARIO, "goldFlower-groundPound-1.png"),
        goldFlower:registerAsset(CHARACTER_LUIGI, "goldFlower-groundPound-2.png"),
    }
end


local animFrames = {12, 12, 12, 11, 11, 11, 11, 11, 11}
local projectileTimerMax = {30, 35, 40, 25, 25}
local projectileTimer = {}
local checkedForLevelEnd = false


local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)


---------------------
-- Local Functions --
---------------------

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
        and p:mem(0x164, FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

local function canSpawnSparkles(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and not p:mem(0x4A, FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and p.frame ~= (-50 * p.direction)
    )
end


------------------
-- CP Functions --
------------------

function goldFlower.onEnable(p, noEffects)
    projectileTimer[p.idx] = 0
end

function goldFlower.onDisable(p, noEffects)
end

function goldFlower.onTickPowerup(p)
    local flamethrowerCheat = Cheats.get("flamethrower")

    flamethrowerActive = flamethrowerCheat and flamethrowerCheat.active

    local decreaseRate = 1
    local keyCombo = p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED

    if flamethrowerActive then
        decreaseRate = 4
        keyCombo = p.keys.run or p.keys.altRun
    end

    projectileTimer[p.idx] = math.max(projectileTimer[p.idx] - decreaseRate, 0)
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if canSpawnSparkles(p) and RNG.random(10) > 9 then
        local e =  Effect.spawn(goldFlower.projectileID, p.x - 12 + RNG.random(p.width + 16), p.y - 8 + RNG.random(p.height + 16), p.character)
        e.speedX = RNG.random(0.5) - 0.25
        e.speedY = RNG.random(0.5) - 0.25
	end

    if projectileTimer[p.idx] > 0 or not canShoot(p) then return end

    if keyCombo or p:mem(0x50, FIELD_BOOL) then
        local v = NPC.spawn(
            goldFlower.projectileID,
            p.x + p.width/2 * (1 + p.direction) + p.speedX,
            p.y + p.height/2 + p.speedY, p.section, false, true
        )

        v.data.character = p.character
        v.data.player = p

        v.isProjectile = true
        v.direction = p.direction

        if (p.character == CHARACTER_PEACH or p.character == CHARACTER_TOAD) and p.keys.altRun then
            p:mem(0x154, FIELD_WORD, v.idx + 1)
            v:mem(0x12C, FIELD_WORD, p.idx)
            p:mem(0x62, FIELD_WORD, 5)
        else
            v.speedX = 5 * v.direction + p.speedX/3.5
            v.speedY = 8
        end

        if p.standingNPC then
            v.speedX = v.speedX + p.standingNPC.speedX/3.5
        end

        if p.character == CHARACTER_LUIGI then
            v.speedX = v.speedX * 0.85
        end
        
        if p.keys.up then
            if p.standingNPC then
                v.speedY = -6 + p.standingNPC.speedY * 0.1
            else
                v.speedY = -6 + p.speedY * 0.1
            end

            v.speedX = v.speedX * 0.9
        end

        if flamethrowerActive then
            v.speedX = v.speedX * 1.5
            v.speedY = v.speedY * 1.5
        end

        SFX.play(18)
        projectileTimer[p.idx] = projectileTimerMax[p.character]
    end
end

function goldFlower.onTickEndPowerup(p)
    local curFrame = animFrames[projectileTimerMax[p.character] - projectileTimer[p.idx] + 1]
    local canPlay = canShoot(p) and not p:mem(0x50,FIELD_BOOL) and p.mount == MOUNT_NONE

    if projectileTimer[p.idx] > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end


---------------------
-- Other Functions --
---------------------

function goldFlower.onInitAPI()
    registerEvent(goldFlower, "onTick")
    cp = require("customPowerups")
end

function goldFlower.onTick()
    if checkedForLevelEnd or not goldFlower.transformOnLevelEnd then return end

    if Level.endState() ~= 0 then
        checkedForLevelEnd = true

        for _, p in ipairs(Player.get()) do
            if cp.getCurrentPowerup(p) == goldFlower then
                cp.setPowerup(goldFlower.basePowerup, p, true)

                for i = 1, 10 do
                    local e =  Effect.spawn(goldFlower.projectileID, p.x - 8 + RNG.random(p.width + 8), p.y - 4 + RNG.random(p.height + 8), p.character)
                    e.speedX = RNG.random(6) - 3
                    e.speedY = RNG.random(6) - 3
                end
            end
        end
    end
end

return goldFlower