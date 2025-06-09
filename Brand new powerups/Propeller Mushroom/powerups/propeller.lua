local goalTape = require("npcs/AI/goalTape")
local pm = require("playerManager")
local propeller = {}
local cp

local STATE = {
    NONE = 0,
    RISING = 1,
    FALLING = 3,
    SLOWFALLING = 4,
    DRILLING = 2,
}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

propeller.basePowerup = PLAYER_FIREFLOWER
propeller.cheats = {"needapropeller", "helicopter"}

propeller.propellerFrames = 4
propeller.propellerFramespeeds = {
    [STATE.NONE]        = 6,
    [STATE.RISING]      = 2,
    [STATE.DRILLING]    = 2,
    [STATE.FALLING]     = 4,
    [STATE.SLOWFALLING] = 2,
}

propeller.frames = 8
propeller.framespeed = 2

propeller.textureOffset = vector(0, 22)

propeller.fallingUsesSpinjump = false

propeller.speeds = {
    rising      = -15,
    falling     = 2,
    slowFalling = 0.75,
    drilling    = 12,
}

propeller.clownCarOffsets = {
    [CHARACTER_MARIO] = -36,
    [CHARACTER_LUIGI] = -38,

    -- this will apply to every charcater that's not listed here
    [-1] = -30,
}

propeller.animData = {
    [STATE.RISING]      = {frameX = 1, frames = 8, framespeed = 2},
    [STATE.DRILLING]    = {frameX = 2, frames = 8, framespeed = 1.2},
    [STATE.FALLING]     = {frameX = 3, frames = 8, framespeed = 6},
    [STATE.SLOWFALLING] = {frameX = 1, frames = 8, framespeed = 3},
}

propeller.SFXs = {
    fly      = {id = "powerups/propeller-fly.ogg",      volume = 0.2},
    fall     = {id = "powerups/propeller-fall.ogg",     volume = 0.5},
    slowFall = {id = "powerups/propeller-slowFall.ogg", volume = 0.5},
    drill    = {id = "powerups/propeller-drill.ogg",    volume = 0.3},
}

function propeller.onInitPowerupLib()
    propeller.spritesheets = {
        propeller:registerAsset(CHARACTER_MARIO, "propeller-mario.png"),
        propeller:registerAsset(CHARACTER_LUIGI, "propeller-luigi.png"),
    }

    propeller.iniFiles = {
        propeller:registerAsset(CHARACTER_MARIO, "propeller-mario.ini"),
        propeller:registerAsset(CHARACTER_LUIGI, "propeller-luigi.ini"),
    }

    propeller.gpImages = {
        --propeller:registerAsset(CHARACTER_MARIO, "propeller-groundPound-1.png"),
        --propeller:registerAsset(CHARACTER_LUIGI, "propeller-groundPound-2.png"),
    }

    propeller.propellerImages = {
        propeller:registerAsset(CHARACTER_MARIO, "propeller-1.png"),
        propeller:registerAsset(CHARACTER_LUIGI, "propeller-2.png"),
    }

    propeller.propellerTiltedImages = {
        propeller:registerAsset(CHARACTER_MARIO, "propeller-1-tilted.png"),
        propeller:registerAsset(CHARACTER_LUIGI, "propeller-2-tilted.png"),
    }

    propeller.flyingImages = {
        propeller:registerAsset(CHARACTER_MARIO, "propeller-mario-flying.png"),
        propeller:registerAsset(CHARACTER_LUIGI, "propeller-luigi-flying.png"),
    }

    cp = require("customPowerups")
end


-- global: affects the propeller's offset for every frame
-- flying: affects the propeller's offset when flying
-- specifying a frame as false will hide the propeller on that frame

propeller.defaultOffsets = {
    global = vector(0, 0),
    flying = vector(0, 0),

    -- "pulling objects from top" frames
    [22] = false, [23] = false,

    -- climbing frames
    [25] = false, [26] = false,
}


-- this table handles per character offsets
-- you can use this to handle separate offsets for costumes too
-- in case an offset is not specified, it'll use the value from propeller.defaultOffsets

propeller.perCharacterOffsets = {
    [CHARACTER_MARIO] = {
        ["__default"] = {
            [1] = vector(-2, 0),
            [2] = vector(-2, 0),
            [3] = vector(-2, 0),
        
            [4] = vector(-2, -2),
            [5] = vector(-2, -2),
        
            [6] = vector(2, 0),
            [7] = vector(4, -4),
        
            [8] = vector(-2, 0),
            [9] = vector(-2, 0),
            [10] = vector(-2, 0),
        
            [13] = vector(0, 0),
            [15] = vector(0, 0),
        
            [24] = vector(-2, 2),
        
            [30] = vector(-9, -2),
            [31] = vector(-5, 6),
        
            [40] = vector(-1, 0),
            [41] = vector(-1, 0),
            [42] = vector(-1, 0),
            [43] = vector(-1, 0),
            [44] = vector(-1, 0),
        },

        ["SMW-MARIO"] = {
            [1] = vector(-0, 0),
            [2] = vector(-0, 0),
            [3] = vector(-0, -2),
        
            [4] = vector(-0, -0),
            [5] = vector(-0, -0),
        
            [6] = vector(0, -2),
            [7] = vector(-0, 2),
        
            [8] = vector(-0, 0),
            [9] = vector(-0, 0),
            [10] = vector(-0, -2),
        
            [13] = vector(0, 0),
            [15] = vector(0, 0),

            [16] = vector(-0, 0),
            [17] = vector(-0, 0),
            [18] = vector(-0, -2),
            [19] = vector(-0, -0),

            [22] = {vector(-12, 2), useTilted = true},
            [23] = {vector(-12, 4), useTilted = true},
        
            [24] = vector(-0, 6),

            [25] = vector(-0, 0),
            [26] = vector(-0, 0),

            [27] = vector(2, -10),

            [28] = vector(0, 0),  --offset not Changeable?
            [29] = vector(6, 4),  --offset not Changeable?
        
            [30] = vector(-4, -2),
            [31] = vector(-2, 12),

            [32] = {vector(-12, 20), useTilted = true},
            [33] = {vector(-12, 20), useTilted = true},

            [34] = vector(-0, -0),

            [35] = vector(-6, -2),
        
            [40] = vector(-0, 2),
            [41] = vector(-0, 2),
            [42] = vector(-0, 2),
            [43] = vector(-0, 2),
            [44] = vector(-0, 2),

            [45] = vector(-4, -2),
        },
    },

    [CHARACTER_LUIGI] = {
        ["__default"] = {
            flying = vector(0, -2),

            [1] = vector(-4, -2),
            [2] = vector(-2, -2),
            [3] = vector(-4, -2),
        
            [4] = vector(-4, -4),
            [5] = vector(-4, -4),
        
            [6] = vector(0, -4),
            [7] = vector(4, -6),
        
            [8] = vector(-4, -2),
            [9] = vector(-4, -2),
            [10] = vector(-4, -2),
        
            [13] = vector(0, -2),
            [15] = vector(0, -2),
        
            [24] = vector(-4, 0),
        
            [30] = vector(-11, -6),
            [31] = vector(-5, 2),
        
            [40] = vector(-3, -2),
            [41] = vector(-3, -2),
            [42] = vector(-3, -2),
            [43] = vector(-3, -2),
            [44] = vector(-3, -2),
        },

        ["SMW-LUIGI"] = {
            [1] = vector(-0, 2),
            [2] = vector(-0, 2),
            [3] = vector(-0, 0),
        
            [4] = vector(-0, 2),
            [5] = vector(-0, 2),
        
            [6] = vector(0, 0),
            [7] = vector(-0, 2),
        
            [8] = vector(-0, 2),
            [9] = vector(-0, 2),
            [10] = vector(-0, 0),
        
            [13] = vector(0, 2),
            [15] = vector(0, 2),

            [16] = vector(-0, 2),
            [17] = vector(-0, 2),
            [18] = vector(-0, 0),
            [19] = vector(-0, 2),

            [22] = {vector(-12, -2), useTilted = true},
            [23] = {vector(-12, -0), useTilted = true},
        
            [24] = vector(-0, 10),

            [25] = vector(-0, 2),
            [26] = vector(-0, 2),

            [27] = vector(2, -8),

            [28] = vector(0, 0),  --offset not Changeable?
            [29] = vector(6, 4),  --offset not changeable?
        
            [30] = vector(-4, -6),
            [31] = vector(-2, 10),

            [32] = {vector(-12, 22), useTilted = true},
            [33] = {vector(-12, 22), useTilted = true},

            [34] = vector(-0, 2),

            [35] = vector(-6, -6),
        
            [40] = vector(-0, 4),
            [41] = vector(-0, 4),
            [42] = vector(-0, 4),
            [43] = vector(-0, 4),
            [44] = vector(-0, 4),

            [45] = vector(-4, -6),
        },
    },
}


-----------------
-- Local Stuff --
-----------------

local playerData = {}
local starShader = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))

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

local function canDoubleJump(p)
    local data = playerData[p.idx]

    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == 0
        and not p.holdingNPC
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and p:mem(0x34, FIELD_WORD) == 0 -- in a liquid
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
        and not data.lastClimbing
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

local function canSpawnSparkles(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and not p:mem(0x4A, FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
    )
end

local function SFXPlay(name, loops, delay)
	local sfx = propeller.SFXs[name]
	
	if sfx and sfx.id then
		return SFX.play{sound = sfx.id, volume = sfx.volume, loops = loops, delay = delay}
	end
end

local function changeState(data, newState)
    if data.state == newState then return end

    local nextSFX = nil

    data.state = newState
    data.animTimer = 0

    data.oldFramespeed = data.currentFramespeed
    data.targetFramespeed = propeller.propellerFramespeeds[data.state]
    data.framespeedLerp = 0

    if data.fallSFX then
        data.fallSFX:stop()
        data.fallSFX = nil
    end

    if data.state == STATE.FALLING then
        nextSFX = "fall"
    elseif data.state == STATE.SLOWFALLING then
        nextSFX = "slowFall"
    end

    if nextSFX then
        Routine.run(function()
            Routine.wait(0.25)

            if data.state == newState then
                if data.fallSFX then
                    data.fallSFX:stop()
                end

                data.fallSFX = SFXPlay(nextSFX, 0, 0)
            end
        end)
    end
end

local function getPropellerOffset(character, frame, flying)
    local globalOffset = nil
    local offset = nil
    local useTilted = false
    local charTable = propeller.perCharacterOffsets[character]

    if flying then
        frame = "flying"
    end

    if charTable then
        local costumeName = pm.getCostume(character) or "__default"
        local tbl = charTable[costumeName]

        if tbl then
            globalOffset = tbl.global
            offset = tbl[frame]
        end
    end

    if offset == nil then
        offset = propeller.defaultOffsets[frame]
    end

    if type(offset) == "table" then
        useTilted = offset.useTilted
        offset = offset[1]
    end

    if offset ~= false then
        globalOffset = globalOffset or propeller.defaultOffsets.global

        return (offset or vector(0, 0)) + globalOffset, useTilted
    else
        return nil
    end
end


-----------------------
-- Powerup Functions --
-----------------------

function propeller.startFlying(p)
    local data = playerData[p.idx]

    -- commented out because this kills all the speedY momentum
    -- p:mem(0x11C, FIELD_WORD, Defines.jumpheight)

    p:mem(0x50, FIELD_BOOL, not not propeller.fallingUsesSpinjump)
    p.speedY = propeller.speeds.rising

    p:mem(0x11C, FIELD_WORD, 0)
    p:mem(0x48, FIELD_WORD, 0)
    p:mem(0x176, FIELD_WORD, 0)

    for i = 1, 10 do
        local e = Effect.spawn(80, p.x, p.y + p.height + p.speedY)
        e.speedX = LegacyRNG.generateNumber() * 4 - 2
        e.speedY = (LegacyRNG.generateNumber() + 2 - math.abs(e.speedX))/2
        e.speedX = e.speedX - p.speedX * 0.2
        e.y = e.y - e.height/2
    end

    data.canDoubleJump = false
    changeState(data, STATE.RISING)
    data.initDirection = p.direction
    data.justStartedJump = true

    SFXPlay("fly")

    Routine.run(function()
        Routine.waitFrames(4)

        for i = 1, 12 do
            if data.state ~= STATE.RISING then
                break
            end

            if p.speedY < -2 then
                Routine.waitFrames(2)

                for i = 1, RNG.randomInt(1, 2) do
                    local e = Effect.spawn(80, p.x + p.width/2 + RNG.randomInt(-8, 8), p.y + p.height + RNG.randomInt(-8, 8))
                    e.x = e.x - e.width/2
                    e.y = e.y - e.height/2

                    e.speedX = RNG.random(-1, 1)
                    e.speedY = p.speedY/propeller.speeds.rising * RNG.random(2, 4)
                end
            end
        end
    end)
end

function propeller.stopFlying(p)
    local data = playerData[p.idx]

    changeState(data, STATE.NONE)

    p:mem(0x164, FIELD_WORD, 0)
end

function propeller.isFlying(p)
    if playerData[p.idx] then
        return playerData[p.idx].state ~= STATE.NONE
    end

    return false
end

function propeller.blacklist(id)
    blockBlacklist[id] = true
    blockWhitelist[id] = nil
end

function propeller.whitelist(id)
    blockBlacklist[id] = nil
    blockWhitelist[id] = true
end

function propeller.getData(p)
    if p then
        return playerData[p.idx]
    end

    return playerData
end


------------------
-- CP Functions --
------------------

function propeller.onEnable(p)
    if not playerData[p.idx] then
        playerData[p.idx] = {
            lastClimbing = 0,
            checkedForClimbing = false,

            state = STATE.NONE,
            initDirection = 1,
            canDoubleJump = true,
            justStartedJump = false,

            animFrame = 0,
            animTimer = 0,

            propellerAnimFrame = 0,
            propellerAnimTimer = 0,

            collider = Colliders.Box(0, 0, 1, 1),
            fallSFX = nil,

            oldFramespeed = 0,
            currentFramespeed = 0,
            targetFramespeed = 0,
            framespeedLerp = -1,
        }
    end
    
    local data = playerData[p.idx]

    data.currentFramespeed = propeller.propellerFramespeeds[data.state]
    data.lastClimbing = p.climbing
    changeState(data, STATE.NONE)

    --data.collider:debug(true)
end

function propeller.onDisable(p)
    local data = playerData[p.idx]

    data.checkedForClimbing = false
    data.canDoubleJump = true

    propeller.stopFlying(p)
end

function propeller.onTickPowerup(p)
    local data = playerData[p.idx]

    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if p:isOnGround() or (data.lastClimbing and not p.climbing) then
        data.canDoubleJump = true
    end

    if data.state == STATE.NONE then
        if canDoubleJump(p) and data.canDoubleJump and p.keys.up and p.keys.altJump == KEYS_PRESSED then
            propeller.startFlying(p)
        end
    else
        if GP then
            GP.preventPound(p)
        end

        p:mem(0x164, FIELD_WORD, -1)
        p:mem(0x12E, FIELD_WORD, 0)
        p.direction = data.initDirection

        -- player animation handling
        local animData = propeller.animData[data.state]

        data.animTimer = data.animTimer + 1

        if data.animTimer >= animData.framespeed then
            data.animFrame = data.animFrame + 1
            data.animTimer = 0
        end

        data.animFrame = data.animFrame % animData.frames


        if data.state ~= STATE.DRILLING and p.keys.down then
            changeState(data, STATE.DRILLING)
            p:mem(0x50, FIELD_BOOL, true)
            SFXPlay("drill")
        end

        if not canDoubleJump(p)
        or (p:isOnGround() and not data.justStartedJump)
        or p:mem(0x11C, FIELD_WORD) > 0 then
            propeller.stopFlying(p)

            if p:mem(0x11C, FIELD_WORD) > 0 then
                data.canDoubleJump = true
            end
        end

        data.justStartedJump = false
    end

    if data.framespeedLerp >= 0 then
        data.framespeedLerp = math.min(data.framespeedLerp + 0.01, 1)
        data.currentFramespeed = math.lerp(data.oldFramespeed, data.targetFramespeed, data.framespeedLerp)

        if data.framespeedLerp == 1 then
            data.framespeedLerp = -1
        end
    end

    -- propeller animation handling
    local framespeed = data.currentFramespeed

    data.propellerAnimTimer = data.propellerAnimTimer + 1

    if data.propellerAnimTimer >= framespeed then
        data.propellerAnimFrame = data.propellerAnimFrame + 1
        data.propellerAnimTimer = 0
    end

    data.propellerAnimFrame = data.propellerAnimFrame % propeller.propellerFrames

    if data.lastClimbing ~= p.climbing and not data.checkedForClimbing then
        data.checkedForClimbing = true

        Routine.run(function()
            Routine.waitFrames(2)
            data.lastClimbing = p.climbing
            data.checkedForClimbing = false
        end)
    end

    if data.storedSpeed then
        p.speedY = data.storedSpeed
        data.storedSpeed = nil
    end

    if data.state == STATE.RISING then
        data.collider.x = p.x + p.width/2 - data.collider.width/2 + p.speedX
        data.collider.y = p.y - data.collider.height + p.speedY

        for k, v in ipairs(Colliders.getColliding{a = data.collider, b = Block.SOLID, btype = Colliders.BLOCK}) do
            if (Block.MEGA_SMASH_MAP[v.id] or blockWhitelist[v.id]) and not blockBlacklist[v.id] then
                if v.id ~= 90 and v.contentID == 0 then
                    v:remove(true)
                else
                    v:hit(false, p)

                    if v.id == 90 then
                        data.storedSpeed = p.speedY
                    end
                end
            end
        end

        if p.speedY >= 2 and not data.justStartedJump then
            if p.keys.altJump then
                changeState(data, STATE.SLOWFALLING)
            else
                changeState(data, STATE.FALLING)
            end

            if not propeller.fallingUsesSpinjump then
                p:mem(0x50, FIELD_BOOL, false)
            else
                p:mem(0x50, FIELD_BOOL, true)
            end
        end

    elseif data.state == STATE.FALLING then
        if p.keys.altJump then
            changeState(data, STATE.SLOWFALLING)
        end

        p.speedY = math.min(p.speedY, propeller.speeds.falling)

    elseif data.state == STATE.SLOWFALLING then
        if not p.keys.altJump then
            changeState(data, STATE.FALLING)
        end

        p.speedY = math.min(p.speedY, propeller.speeds.slowFalling)
        
    elseif data.state == STATE.DRILLING then
        p.speedY = math.min(p.speedY + 0.5, propeller.speeds.drilling)

        if not p.keys.down then
            changeState(data, STATE.FALLING)

            if not p.keys.altJump and not propeller.fallingUsesSpinjump then
                p:mem(0x50, FIELD_BOOL, false)
            else
                p:mem(0x50, FIELD_BOOL, true)
            end
        end

        data.collider.x = p.x + p.width/2 - data.collider.width/2 + p.speedX
        data.collider.y = p.y + p.height + p.speedY

        for k, v in ipairs(Colliders.getColliding{a = data.collider, b = Block.SOLID, btype = Colliders.BLOCK}) do
            local canBreak = (Block.MEGA_SMASH_MAP[v.id] or blockWhitelist[v.id]) and not blockBlacklist[v.id]

            if v.contentID == 0 and canBreak then
                v:remove(true)
            else
                if v.contentID ~= 0 then
                    propeller.stopFlying(p)
                    p:mem(0x50, FIELD_BOOL, false)
                end

                v:hit(true, p)
            end
        end

        if lunatime.tick() % 3 == 0 then
            local effectCount = 2 * RNG.randomInt(1, 2) - 1

            for i = 1, effectCount do
                local idx = (effectCount + 1)/2 - i

                local e = Effect.spawn(
                    80,
                    p.x + p.width/2 + RNG.randomInt(-8, 8),
                    p.y + p.height + p.speedY - math.abs(idx) * 16
                )

                e.x = e.x - e.width/2
                e.y = e.y - e.height/2

                e.speedX = math.sign(idx)
                e.speedY = -RNG.random(2, 3)
            end
        end
    end
end

function propeller.onTickEndPowerup(p)
    local data = playerData[p.idx]

    data.collider.width = p.width - 4
    data.collider.height = math.clamp(math.abs(p.speedY), 4, 8)
end

local function drawPlayerStuff(data, p, priority, opacity)
    local animData = propeller.animData[data.state]
    
    -- player flying sprites
    if data.state ~= STATE.NONE then
        local img = propeller:getAsset(p.character, propeller.flyingImages[p.character])
        local width = img.width/3
        local height = img.height/propeller.frames

        Graphics.drawBox{
            texture = img,
            x = p.x + p.width/2 + propeller.textureOffset.x * p.direction,
            y = p.y + p.height - height/2 + propeller.textureOffset.y,
            width = width * data.initDirection,
            height = height,
            sourceX = width * (animData.frameX - 1),
            sourceY = data.animFrame * height,
            sourceWidth = width,
            sourceHeight = height,
            priority = priority,
            sceneCoords = true,
            centered = true,
            shader = (p.hasStarman and starShader) or nil,
            uniforms = (p.hasStarman and {time = lunatime.tick() * 2}) or nil,
            color = Color.white .. opacity,
        }

        p.frame = -50 * p.direction
    end

    -- propeller sprites
    local frame = math.abs(p.frame)

    if p:mem(0x50, FIELD_BOOL) and data.state == STATE.NONE then
        frame = (p.direction == 1 and 15) or 13
    end

    local offset, useTilted = getPropellerOffset(p.character, frame, data.state ~= STATE.NONE)
    local canDraw = (p.mount ~= MOUNT_BOOT or not p:mem(0x12E, FIELD_BOOL)) and cp.canDrawStuff(p) and not p:mem(0x0C, FIELD_BOOL)

    if offset and canDraw then
        local img = propeller:getAsset(p.character, propeller.propellerImages[p.character])

        if useTilted then
            img = propeller:getAsset(p.character, propeller.propellerTiltedImages[p.character]) or image
        end

        local width = img.width
        local height = img.height/propeller.propellerFrames
        local mountOffset = 0

        if p.mount == MOUNT_YOSHI then
            mountOffset = p:mem(0x10E, FIELD_WORD)
        elseif p.mount == MOUNT_CLOWNCAR then
            mountOffset = (propeller.clownCarOffsets[p.character] or propeller.clownCarOffsets[-1])
        end

        Graphics.drawBox{
            texture = img,
            x = p.x + p.width/2 + offset.x * p.direction,
            y = p.y - height/2 + offset.y + mountOffset,
            width = width * p.direction,
            height = height,
            sourceX = 0,
            sourceY = data.propellerAnimFrame * height,
            sourceWidth = width,
            sourceHeight = height,
            priority = priority,
            sceneCoords = true,
            centered = true,
            shader = (p.hasStarman and starShader) or nil,
            uniforms = (p.hasStarman and {time = lunatime.tick() * 2}) or nil,
            color = Color.white .. opacity,
        }
    end
end

function propeller.onDrawPowerup(p)
    local data = playerData[p.idx]

    if p.forcedState ~= 8 and not p:mem(0x142, FIELD_BOOL) and p.deathTimer == 0 and (not GP or not GP.isPounding(p)) then
        local priority = -25
        local info = goalTape.playerInfo[p.idx]

        if info and info.darkness > 0 then
            local priority = (info.pausesGame and 0.5) or -6
            drawPlayerStuff(data, p, priority, info.darkness)
        end

        if p.forcedState == FORCEDSTATE_PIPE then
            priority = -70
        end

        drawPlayerStuff(data, p, priority, 1)

        --[[
        Graphics.drawBox{
            x = p.x,
            y = p.y,
            w = p.width,
            h = p.height,
            sceneCoords = true,
            color = Color.blue .. 0.5,
        }
        ]]
    end
end

return propeller