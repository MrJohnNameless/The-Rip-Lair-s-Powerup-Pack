local drill = {}

local pm = require("playerManager")
local easing = require("ext/easing")
local cp = require("customPowerups")

local gfxTable = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

-- the powerup images should be named as "drill-CHARACTER_NAME-#", where # is the frame index

drill.basePowerup = PLAYER_FIREFLOWER

drill.frameCount = 3
drill.frameSpeed = 4
drill.digFrames = 2
drill.digFramespeed = 6

drill.digParticle = Misc.resolveFile("powerups/drill-digPart.ini")
drill.drillParticle = Misc.resolveFile("powerups/drill-drillPart.ini")

drill.blockHitInterval = 16
drill.iFrames = 40 -- iframes given to the player after jumping out of the ground

drill.effects = {
    smoke = 250,
    poof = 249,
    ground = 753,
}

drill.SFX = {
    digStart = {id = 4, volume = 1},
    digEnd = {id = 4, volume = 1},
    drillStart = {id = "powerups/drill-drillStart.ogg", volume = 1},
}

function drill.onInitPowerupLib()
    drill.spritesheets = {
        drill:registerAsset(CHARACTER_MARIO, "drill-mario-1.png"),
        drill:registerAsset(CHARACTER_LUIGI, "drill-luigi-1.png"),
    }

    drill.iniFiles = {
        drill:registerAsset(CHARACTER_MARIO, "drill-mario.ini"),
        drill:registerAsset(CHARACTER_LUIGI, "drill-luigi.ini"),
    }

    drill.gpImages = {
        drill:registerAsset(CHARACTER_MARIO, "drill-groundPound-1.png"),
        drill:registerAsset(CHARACTER_LUIGI, "drill-groundPound-2.png"),
    }

    drill.digImages = {
        drill:registerAsset(CHARACTER_MARIO, "drill-dig-1.png"),
        drill:registerAsset(CHARACTER_LUIGI, "drill-dig-2.png"),
    }

    -- load assets, the programmer way
    for character, assetData in pairs(drill.spritesheets) do
        gfxTable[character] = {}

        for i = 1, drill.frameCount do
            gfxTable[character][i] = drill:registerAsset(character, "drill-"..pm.getName(character).."-"..i..".png")
        end
    end
end


local playerData = {}
local blackListedStates = table.map{3, 6, 7, 8, 9, 10, 499, 500}

local nonDiggableBlocks = {}
local passableBlocks = {}

local oldFilters = {}

local hittableNPCs = table.iclone(NPC.HITTABLE)
local blacklistedNPCs = {}

local jewelBlock
pcall(function() jewelBlock = require("AI/jewelBlock") end)

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local drillSpot
pcall(function() drillSpot = require("AI/drillSpot") end)

aw = aw or {
	preventWallSlide = function() end,
	isWallSliding = function() return 0 end,
}

GP = GP or {
    custom = true,
    overrideRenderData = function() end,
    preventEffects = function() end,
}

------------------------
-- Internal Functions --
------------------------

local function SFXPlay(name)
	local sfx = drill.SFX[name]
	
	if sfx then
		return SFX.play(sfx.id, sfx.volume or 1)
	end
end

local function isOnGround(p)
	return (
		p.speedY == 0 -- "on a block"
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end


local function canDig(p)
    return (
        p.forcedState == 0
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x40, FIELD_WORD) == 0 --climbing
        and p.deathTimer == 0
        and p.mount == 0
        and not p.holdingNPC
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and aw.isWallSliding(p) == 0
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end


local function spawnFX(p)
    local smoke = Effect.spawn(drill.effects.poof, p.x + p.width/2, p.y + p.height/2)
    smoke.x = smoke.x - smoke.width/2
    smoke.y = smoke.y - smoke.height/2

    local brick = Effect.spawn(drill.effects.ground, p.x + p.width/2, p.y + p.height/2)
    brick.x = brick.x - brick.width/2
    brick.y = brick.y - brick.height/2

    for i = 1, 12 do
        local e = Effect.spawn(drill.effects.smoke, p.x + p.width/2, p.y + p.height)
        e.x = e.x - e.width/2 + RNG.randomInt(-24, 24)
        e.y = e.y - e.height/2 + RNG.randomInt(-32, -16)
        e.speedX = RNG.randomInt(-1, 1)
        e.speedY = RNG.randomInt(-4, -2)
    end
end


local function canCancel(p)
	return (
		blackListedStates[p.forcedState]
        or p.inLaunchBarrel
        or p.inClearPipe
		or p.isMega
		or aw.isWallSliding(p) ~= 0
		or p.mount ~= MOUNT_NONE
		or p:mem(0x4A, FIELD_BOOL) -- statue
		or p:mem(0x3C, FIELD_BOOL) -- sliding
		or p:mem(0x0C, FIELD_BOOL) -- fairy
		or (p.deathTimer > 0 and p:mem(0x13C, FIELD_BOOL))
		or p:mem(0x06, FIELD_WORD) > 0
		or Level.endState() ~= LEVEL_WIN_TYPE_NONE
        or not isOnGround(p)
	)
end


local function cancelHitting(p, data, gpData)
    data.fakeFrame = false
    data.hittingBlocks = false
    data.drillTimer = 0
    gpData.renderData.frameY = nil
    gpData.renderData.offset = nil
end


local function exitBlockFilter(v)
    return (Block.SOLID_MAP[v.id] or passableBlocks[v.id]) and not v.isHidden and not v:mem(0x5A, FIELD_BOOL)
end


----------------------------
-- External Use Functions --
----------------------------

function drill.addNonDiggableBlock(id)
    nonDiggableBlocks[id] = true
end


function drill.addDiggableBlock(id)
    nonDiggableBlocks[id] = nil
end


function drill.addNonPassableBlock(id)
    passableBlocks[id] = nil
end


function drill.addPassableBlock(id)
    passableBlocks[id] = true
end


function drill.whitelistNPC(id)
    if not NPC.HITTABLE_MAP[id] then
        table.insert(hittableNPCs, id)
    end

    blacklistedNPCs[id] = nil
end


function drill.blacklistNPC(id)
    blacklistedNPCs[id] = true
end


function drill.preventDigging(p)
    playerData[p.idx].preventDigging = true
end

function drill.startDig(p, noEffects)
    if not isOnGround(p) or not canDig(p) then return false end

    local data = playerData[p.idx]
    local canDigOnBlock = true

    if not data or data.isDigging or data.hittingBlocks or canCancel(p) then return false end

    for k, v in Block.iterateIntersecting(p.x, p.y + p.height, p.x + p.width, p.y + p.height + 4) do
        if not v.isHidden and not v:mem(0x5A, FIELD_BOOL) and nonDiggableBlocks[v.id] then
            canDigOnBlock = false
            break
        end
    end

    if not canDigOnBlock then return false end

    p.speedX = p.speedX/2
    p.speedY = p.speedY/2
    data.isDigging = true

    aw.preventWallSlide(p)
    --p:mem(0x12E, FIELD_BOOL, false)

    if not GP.custom then
        GP.cancelPound(p)
        GP.getData(p.idx).renderData.frameX = -999
    end

    for k, id in ipairs(table.unmap(passableBlocks)) do
        oldFilters[id] = Block.config[id].playerfilter or 0
        Block.config[id].playerfilter = -1
    end

    if p:mem(0x48, FIELD_WORD) ~= 0 then
        local b = Block(p:mem(0x48, FIELD_WORD))
        local angle = math.deg(math.atan2(b.height, b.width)) * Block.config[b.id].floorslope
        data.angle = angle
        data.curAngle = angle
        data.targetAngle = angle
    end

    if not noEffects then
        spawnFX(p)
        SFXPlay("digStart")
    end

    if cp.getCurrentID(p) == drill.id then
        GP.preventEffects(p)
    end

    return true
end


function drill.stopDig(p, noEffects)
    local data = playerData[p.idx]
    local canExit = true

    if not data.isDigging then return false end

    for k, v in ipairs(Colliders.getColliding{a = p, btype = Colliders.BLOCK, filter = exitBlockFilter}) do
        canExit = false
        break
    end

    if not canExit then
        p:mem(0x11E, FIELD_BOOL, false)
        p:mem(0x120, FIELD_BOOL, false)
    end

    if canExit then
        data.isDigging = false
        data.angle = 0
        data.angleLerp = 0
        data.curAngle = 0
        data.targetAngle = 0
        p:mem(0x140, FIELD_WORD, math.max(p:mem(0x140, FIELD_WORD), drill.iFrames))

        for k, filter in pairs(oldFilters) do
            Block.config[k].playerfilter = filter
        end

        oldFilters = {}

        if not noEffects then
            spawnFX(p)
            SFXPlay("digEnd")
        end

        return true
    end

    return false
end


function drill.applyDefaultSettings()
    for _, id in ipairs(Block.NONSOLID..Block.HURT..Block.PLAYER..Block.MEGA_SMASH..Block.SEMISOLID) do
        if not drillSpot or not drillSpot.idMap[id] then
            drill.addNonDiggableBlock(id)
        end

        if Block.MEGA_SMASH_MAP[id] then
            drill.addPassableBlock(id)
        end
    end

    if jewelBlock then
        for _, id in ipairs(jewelBlock.idList) do
            drill.addPassableBlock(id)
            drill.addNonDiggableBlock(id)
        end
    end
end


function GP.onBlockPound(e, v, p)
    if e.cancelled or GP.custom then return end

    local isJewelBlock = jewelBlock and jewelBlock.idMap[v.id]
    local isDrillPowerup = cp.getCurrentID(p) == drill.id

    if not isDrillPowerup then return end

    local data = playerData[p.idx]

    if isJewelBlock then
        data.hittingBlocks = true
        data.lastHittingBlocks = true
        data.fakeFrame = GP.getFrame(p)
        data.fakePos = p.y
        GP.preventEffects(p)
        SFXPlay("drillStart")
    else
        local digStarted = drill.startDig(p)

        if digStarted then
            e.cancelled = true
        end
    end
end

function GP.onPostBlockPound(v, p)
    local isJewelBlock = jewelBlock and jewelBlock.idMap[v.id]

    if not isJewelBlock or GP.custom then return end

    if cp.getCurrentID(p) ~= drill.id and v.data.hp == 0 then
        GP.cancelPound(p)
        GP.preventPoundJump(p)
        p.speedY = p.speedY/2
    end
end


-----------------------
-- Powerup Functions --
-----------------------

function drill.onEnable(p)
    playerData[p.idx] = {
        animTimer = 0,
        isDigging = false,
        angle = 0,
        angleLerp = 0,
        curAngle = 0,
        targetAngle = 0,
        curSlope = nil,
        digPart = Particles.Emitter(0, 0, drill.digParticle),
        drillPart = Particles.Emitter(0, 0, drill.drillParticle),
        collider = Colliders.Box(0, 0, 24, 20),
        effectSpawned = false,
        waitTimer = 0,
        storedNPCs = {},
        hittingBlocks = false,
        fakeFrame = false,
        fakePos = 0,
        drillTimer = 0,
        preventDigging = false,
        lastHittingBlocks = false,
    }
end


function drill.onDisable(p)
    local data = playerData[p.idx]

    if data then
        data.animTimer = 0
    end

    for k, filter in pairs(oldFilters) do
        Block.config[k].playerfilter = filter
    end

    oldFilters = {}
    drill.stopDig(p, true)

    playerData[p.idx] = nil
end


function drill.onTickPowerup(p)
    if not playerData[p.idx] then
	return
    end

    local data = playerData[p.idx]
    local frame = math.floor(data.animTimer / drill.frameSpeed) % drill.frameCount

    data.animTimer = data.animTimer + 1

    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if not GP.custom then
        local gpData = GP.getData(p.idx)

        if not data.isDigging and p.forcedState == 0 then
            gpData.renderData.frameX = frame
        end

        if gpData.state == GP.STATE_SPIN then
            if gpData.rotlerp >= (GP.rotationDuration - 4)/GP.rotationDuration and not data.effectSpawned then
                local e = Effect.spawn(249, p.x + p.width/2, p.y + p.height/2)
                e.x = e.x - e.width/2
                e.y = e.y - e.height/2
                data.effectSpawned = true
            end
        else
            data.effectSpawned = false
        end

        if data.hittingBlocks then
            if canCancel(p) or p.keys.jump then
                cancelHitting(p, data, gpData)
            else

                data.drillTimer = data.drillTimer + 1

                p.keys.right = false
                p.keys.left = false
                p.keys.down = false
                p.keys.altJump = false
                p.speedX = 0
                p:mem(0x172, FIELD_BOOL, false) -- run
                p:mem(0x174, FIELD_BOOL, false) -- jump
                p:mem(0x50,  FIELD_BOOL, false) -- spin jump
                aw.preventWallSlide(p)

                gpData.renderData.frameY = data.fakeFrame
                gpData.renderData.offset = vector(0, data.fakePos + math.sin(data.drillTimer * 0.5) * 2 - p.y)
                GP.preventPoundJump(p)
                drill.preventDigging(p)

                local blocksFound = false

                for k, b in Block.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+2) do
                    if jewelBlock.idMap[b.id] and not b.isHidden and not b:mem(0x5A, FIELD_BOOL) then
                        if data.drillTimer % drill.blockHitInterval == 0 then
                            b:hit(true, p)
                        end

                        blocksFound = true
                    end
                end

                if not blocksFound then
                    cancelHitting(p, data, gpData)
                end
            end
        elseif data.lastHittingBlocks then
            data.lastHittingBlocks = false

            local smoke = Effect.spawn(drill.effects.poof, p.x + p.width/2, p.y + p.height/2)
            smoke.x = smoke.x - smoke.width/2
            smoke.y = smoke.y - smoke.height/2
        end
    end

    if not data.isDigging then
        if p.forcedState == 0 then
            Graphics.sprites[pm.getName(p.character)][drill.basePowerup].img = drill:getAsset(p.character, gfxTable[p.character][frame + 1])

            for k, v in ipairs(Colliders.getColliding{a = data.collider, b = hittableNPCs, btype = Colliders.NPC}) do
                if not blacklistedNPCs[v.id] then
                    v:harm(HARM_TYPE_NPC)
                end
            end
        end

        -- digging
        if p.keys.down then
            drill.startDig(p)
        end

    -- inside the ground
    else
        p:setFrame(-50 * p.direction)
        p:mem(0x140, FIELD_WORD, 1)
        p:mem(0x3C, FIELD_BOOL, false)
        p.keys.down = false
        data.curSlope = nil

        aw.preventWallSlide(p)

        if not GP.custom then
            GP.preventPound(p)
            GP.preventPoundJump(p)
        end

        if drillSpot then
            for k, v in Block.iterateIntersecting(p.x, p.y + p.height, p.x + p.width, p.y + p.height*2) do
                if drillSpot.idMap[v.id] and not v.isHidden and not v:mem(0x5A, FIELD_BOOL) then
                    drillSpot.collect(v)
                end
            end
        end

        local xcen, ybase = p.x + p.width/2, p.y + p.height

        for k, v in Block.iterateIntersecting(xcen - 2, ybase, xcen + 2, ybase + 16) do
            if Block.SLOPE_MAP[v.id] and Block.config[v.id].floorslope ~= 0 and not v.isHidden and not v:mem(0x5A, FIELD_BOOL) then
                data.curSlope = v
                break
            end
        end

        if data.curSlope then
            local b = data.curSlope
            data.targetAngle = math.deg(math.atan2(b.height, b.width)) * Block.config[b.id].floorslope
        else
            data.targetAngle = 0
        end

        if data.curAngle ~= data.targetAngle then
            data.angleLerp = math.min(data.angleLerp + 0.05, 1)
            data.angle = easing.outQuad(data.angleLerp, data.curAngle, data.targetAngle - data.curAngle, 1)

            if data.angleLerp == 1 then
                data.curAngle = data.targetAngle
                data.angleLerp = 0
            end
        end

        local escapeInput = p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED

        if canCancel(p) or escapeInput or not isOnGround(p) then
            drill.stopDig(p)
        end
    end

    data.preventDigging = false
end


function drill.onTickEndPowerup(p)
    local data = playerData[p.idx]

    if not data then return end

    data.collider.x = p.x + p.width/2 - data.collider.width/2
    data.collider.y = p.y - data.collider.height + 4
end


function drill.onDrawPowerup(p)
    local data = playerData[p.idx]

    if not data then return end

    local img = drill:getAsset(p.character, drill.digImages[p.character])
    local frame = math.floor(data.animTimer / drill.digFramespeed) % drill.digFrames

    data.digPart.x = p.x + p.width/2
    data.digPart.y = p.y + p.height
    data.digPart.enabled = data.isDigging
    data.digPart:Draw(-24)

    data.drillPart.x = p.x + p.width/2
    data.drillPart.y = p.y + p.height
    data.drillPart.enabled = data.hittingBlocks
    data.drillPart:Draw(-24)

    if data.isDigging then        
        Graphics.drawBox{
            texture = img,
            x = p.x + p.width/2, y = p.y + p.height - (img.height/drill.digFrames)/2 + 6,
            sourceX = 0, sourceY = frame * img.height/drill.digFrames,
            sourceWidth = img.width, sourceHeight = img.height/drill.digFrames,
            sceneCoords = true, priority = -25,
            centered = true, rotation = data.angle,
        }
    end

    if not GP.custom and data.hittingBlocks then
        local gpData = GP.getData(p.idx)

        p:setFrame(-50 * p.direction)
        GP.renderPlayer(p, gpData.renderData)
    end
end


---------------------
-- Other Functions --
---------------------

function drill.onInitAPI()
    registerEvent(drill, "onNPCCollect")
end

function drill.onNPCCollect(e, v, p)
    local data = playerData[p.idx]

    if e.cancelled or not data or cp.getCurrentID(p) ~= drill.id then
        return
    end

    if data.isDigging and Colliders.collide(p, v) then
        e.cancelled = true
    end
end

return drill