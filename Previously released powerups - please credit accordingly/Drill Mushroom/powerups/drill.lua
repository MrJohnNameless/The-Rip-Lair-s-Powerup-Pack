--[[

    drill.lua
    - by Marioman2007

    Powerup file for the drill mushroom. Part of the Rip Lair's powerup pack

    - reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
    - everything except "name" and "id" can be safely modified

    - the powerup images should be named as "drill-CHARACTER_NAME-#", where # is the frame index

]]

local pm = require("playerManager")
local easing = require("ext/easing")
local cp = require("customPowerups")

local drill = {}
local characterSprites = {}

drill.basePowerup = PLAYER_FIREFLOWER
drill.cheats = {"needadrill", "onewiththeearth"}

-------------
-- Settings --
--------------

-- player animation
drill.frameCount = 3
drill.frameSpeed = 6

-- digging animation
drill.digFrames = 2
drill.digFramespeed = 6

-- particle files
drill.digParticle = Misc.resolveFile("powerups/drill-digPart.ini")
drill.drillParticle = Misc.resolveFile("powerups/drill-drillPart.ini")

-- digging movement
drill.movementSpeed = 3
drill.movementSpeedFast = 5
drill.acceleration = 0.5
drill.deceleration = 0.25

drill.allowSpinjump = true   -- if true, the player can come out with a spinjump, otherwise it turns into a regular jump
drill.iFrames = 25           -- iframes given to the player after jumping out of the ground
drill.blockHitInterval = 16  -- delay between hitting a jewel block

-- effects used by the powerup
drill.effects = {
    poof = 10,
    ground = 1,
    dust = 131,
}

-- sounds used by the powerup
drill.SFX = {
    digStart = {volume = 0.5, id = "SFX/drillDig.ogg"},
    digLoop  = {volume = 0.4, id = "SFX/drillDigloop.ogg"},
    digStop  = {volume = 0.7, id = "SFX/drillPopOut.ogg"},
}

-- speedY of the digging particle
drill.particleRange = "-6:4"
drill.ceilingParticleRange = "0:0"


----------------------
-- Character Assets --
----------------------

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
    -- you do not need to make any edits to this

    for character, assetData in pairs(drill.spritesheets) do
        characterSprites[character] = {}

        for i = 1, drill.frameCount do
            characterSprites[character][i] = drill:registerAsset(character, "drill-"..pm.getName(character).."-"..i..".png")
        end
    end
end


---------------------
-- Other Variables --
---------------------

drill.drawDebug = false
drill.passBlockID = 0 -- set by block-n.lua


local GROUND_NONE  = 0  -- player outside the ground
local GROUND_DOWN  = 1  -- player in the ground
local GROUND_TOP   = 2  -- player in the ceiling

local starShader   = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))
local metalShader  = Shader.fromFile(nil, Misc.resolveFile("metalShader.frag"))
local vanishShader = Shader.fromFile(nil, Misc.resolveFile("vanishShader.frag"))

local playerData = {}
local blackListedStates = table.map{3, 6, 7, 9, 10, 499, 500}

local nonDiggableBlocks = {}

local hittableNPCs = table.iclone(NPC.HITTABLE)
local blacklistedNPCs = {}

local boxCollider = Colliders.Box(0, 0, 1, 1)
local digLoopSFX = nil
local applySettings = false

--------------------------------------
-- Compatibility with other scripts --
--------------------------------------

local jewelBlock
pcall(function() jewelBlock = require("AI/jewelBlock") end)

local drillSpot
pcall(function() drillSpot = require("AI/drillSpot") end)

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

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

local function SFXPlay(name, loops)
	local sfx = drill.SFX[name]
	
	if sfx then
		return SFX.play(sfx.id, sfx.volume or 1, loops)
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
        Level.endState() == LEVEL_WIN_TYPE_NONE
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and not p:isClimbing()
        and not p.holdingNPC
        and not p.isFairy
        and p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == 0
        and aw.isWallSliding(p) == 0
    )
end


local function invalidState(p)
	return (
		blackListedStates[p.forcedState]
        or p.inLaunchBarrel
        or p.inClearPipe
		or p.isMega
		or aw.isWallSliding(p) ~= 0
		or p.mount ~= MOUNT_NONE
		or p.isTanookiStatue
		or p.slidingOnSlope
		or p.isFairy
		or p:isDead()
		or p:mem(0x06, FIELD_WORD) > 0
		or Level.endState() ~= LEVEL_WIN_TYPE_NONE
	)
end


local function spawnPoof(x, y)
    local count = RNG.randomInt(5, 8)
    local speed = RNG.random(1, 2)

    for i = 1, count do
        local direction = -vector.right2:rotate(i * 360/count + RNG.randomInt(-15, 15))
        local e = Effect.spawn(drill.effects.poof, x, y)

        e.x = e.x - e.width/2
        e.y = e.y - e.height/2
        e.speedX = direction.x * speed
        e.speedY = direction.y * speed
    end
end


local function spawnFX(p, isCeiling, isWeak)
    local xcen = p.x + p.width/2
    local ybase = p.y + p.height

    if isCeiling then
        ybase = p.y
    end

    if not isWeak then
        Routine.run(function()
            for i = 1, RNG.randomInt(8, 12) do
                local e = Effect.spawn(drill.effects.dust, xcen, ybase)

                e.x = e.x - e.width/2 + RNG.randomInt(-16, 16)
                e.y = e.y - e.height/2 + RNG.randomInt(0, 8)
                e.speedX = RNG.random(-0.5, 0.5)
                e.speedY = RNG.random(-10, -2)

                if isCeiling then
                    e.y = e.y + 32
                    e.speedY = -e.speedY
                else
                    e.y = e.y - 32
                end

                Routine.skip()
            end
        end)
    end

    spawnPoof(xcen, ybase)

    local brick = Effect.spawn(drill.effects.ground, xcen, ybase + 32)

    brick.x = brick.x - brick.width/2
    brick.y = brick.y - brick.height/2
end


local function cancelHitting(p, data, gpData)
    data.fakeFrame = false
    data.hittingBlocks = false
    data.drillTimer = 0
    gpData.renderData.frameY = nil
    gpData.renderData.offset = nil
end


local function canPassThrough(v)
    if Block.SEMISOLID_MAP[v.id]
    or jewelBlock.idMap[v.id]
    then
        return true
    end

    for k, b in Block.iterateIntersecting(v.x, v.y, v.x + v.width, v.y + v.height) do
        if not b.isHidden and not b:mem(0x5A, FIELD_BOOL) and b.id == drill.passBlockID then
            return true
        end
    end

    return false
end


local function getSlopeDirection(b)
    if b == nil or not Block.SLOPE_MAP[b.id] then
        return 0
    end

    local config = Block.config[b.id]

    if config.floorslope ~= 0 then
        return config.floorslope
    elseif config.ceilingSlope ~= 0 then
        return config.ceilingSlope
    end

    return 0
end


local function getBlockSlope(b)
    if b == nil or not Block.SLOPE_MAP[b.id] then
        return 0
    end

    local config = Block.config[b.id]
    local angle = math.deg(math.atan2(b.height, b.width))

    return angle * -getSlopeDirection(b)
end


local function getYFromX(b, x)
    local config = Block.config[b.id]
    local slopeDir = getSlopeDirection(b)
    local angle = getBlockSlope(b)

    local s = 1

    if config.ceilingSlope ~= 0 then
        s = -1
    end

    return -math.tan(math.rad(angle)) * (x - b.width/2 * slopeDir * s)
end


local function getStandingBlock(p, isCeiling, x, y, w, h)
    local blockList = {}
    
    for k, v in Block.iterateIntersecting(x, y, x + w, y + h) do
        if not v.isHidden and not v:mem(0x5A, FIELD_BOOL) and Misc.canCollideWith(p, v) and (Block.SOLID_MAP[v.id] or Block.PLAYERSOLID_MAP[v.id]) and not canPassThrough(v) then
            table.insert(blockList, v)
        end
    end

    table.sort(blockList, function(a, b)
        if isCeiling then
            return a.y > b.y
        else
            return a.y < b.y
        end
    end)

    return blockList[1]
end


local function getLinecastObjects(p, data, direction, x1, y1, x2, y2)
    local final = {}

    if x2 < x1 then
        x1, x2 = x2, x1
    end

    if y2 < y1 then
        y1, y2 = y2, y1
    end

    for k, v in Block.iterateIntersecting(x1, y1, x2, y2) do
        local blockedBySlope = false
        local config = Block.config[v.id]

        if data.digState == GROUND_DOWN and config.floorslope ~= 0 then
            blockedBySlope = (direction == config.floorslope)
        elseif data.digState == GROUND_TOP and config.ceilingSlope ~= 0 then
            blockedBySlope = (direction == -config.ceilingSlope)
        end

        if Block.SOLID_MAP[v.id] and not v.isHidden and not v:mem(0x5A, FIELD_BOOL) and v ~= data.curBlock and not blockedBySlope and not canPassThrough(v) then
            table.insert(final, v)
        end
    end

    return final
end


local function hurtNPCsByHelmet(p, collider)
    for k, v in ipairs(Colliders.getColliding{a = collider, b = hittableNPCs, btype = Colliders.NPC}) do
        if Misc.canCollideWith(p, v) and not blacklistedNPCs[v.id] then
            v:harm(HARM_TYPE_NPC)
        end
    end
end


local function removeLoopSFX()
    if digLoopSFX == nil then
        return
    end

    if digLoopSFX.isValid then
        digLoopSFX:stop()
    end

    digLoopSFX = nil
end


----------------------------
-- External Use Functions --
----------------------------

-- sets a block so that the player cannot perform a dig on it
function drill.addNonDiggableBlock(id)
    nonDiggableBlocks[id] = true
end

-- sets a block to allow digging on it
function drill.addDiggableBlock(id)
    nonDiggableBlocks[id] = nil
end

-- allows the NPC to get hurt by the player's helmet drill
function drill.whitelistNPC(id)
    if not NPC.HITTABLE_MAP[id] then
        table.insert(hittableNPCs, id)
    end

    blacklistedNPCs[id] = nil
end

-- prevents the NPC from getting hurt by the player's helmet drill
function drill.blacklistNPC(id)
    blacklistedNPCs[id] = true
end

-- while this is called, the player cannot start digging
function drill.preventDigging(p)
    playerData[p.idx].preventDigging = true
end

-- starts digging
function drill.startDig(p, isCeiling, noEffects)
    if (not isCeiling and not isOnGround(p)) or not canDig(p) then
        return false
    end

    local data = playerData[p.idx]

    if not data or data.digState ~= GROUND_NONE or data.hittingBlocks or invalidState(p) then
        return false
    end

    local y1 = p.y + p.height
    local y2 = p.y + p.height + 4

    if isCeiling then
        y1 = p.y - 4
        y2 = p.y
    end

    -- search for non-diggable blocks
    for k, v in Block.iterateIntersecting(p.x, y1, p.x + p.width, y2) do
        if not v.isHidden and not v:mem(0x5A, FIELD_BOOL) and nonDiggableBlocks[v.id] and not Block.SEMISOLID_MAP[v.id] then
            return false
        end
    end

    -- search for blocks
    for k, w in ipairs(Warp.getIntersectingEntrance(p.x, p.y, p.x + p.width, p.y + p.height)) do
        if not w.isHidden and w.warpType == 1 and ((w.entranceDirection == 3 and not isCeiling) or (w.entranceDirection == 1 and isCeiling)) then
            return false
        end
    end

    local angle = 0

    if p:mem(0x48, FIELD_WORD) ~= 0 then
        local b = Block(p:mem(0x48, FIELD_WORD))

        data.curBlock = b
        data.blockOffset = (p.x + p.width/2) - (b.x + b.width/2)
        angle = -getBlockSlope(b)
    end

    local xcen = p.x + p.width/2
    local ybase = p.y + p.height

    if not isCeiling then
        data.burrowCollider.x = xcen - data.burrowCollider.width/2
        data.burrowCollider.y = ybase - data.burrowCollider.height

        data.burrowSensor.x = xcen - data.burrowSensor.width/2
        data.burrowSensor.y = ybase - data.burrowSensor.height/2
    else
        data.burrowCollider.x = xcen - data.burrowCollider.width/2
        data.burrowCollider.y = p.y

        data.burrowSensor.x = xcen - data.burrowSensor.width/2
        data.burrowSensor.y = p.y - data.burrowSensor.height/2
    end

    if data.curBlock == nil then
        local b = getStandingBlock(p, isCeiling, data.burrowSensor.x, data.burrowSensor.y, data.burrowSensor.width, data.burrowSensor.height)

        if b == nil then
            if not isCeiling then
                b = getStandingBlock(p, isCeiling, data.burrowCollider.x, data.burrowCollider.y, data.burrowCollider.width, data.burrowCollider.height + 2)
            else
                b = getStandingBlock(p, isCeiling, data.burrowCollider.x, data.burrowCollider.y - 2, data.burrowCollider.width, data.burrowCollider.height)
            end
        end

        -- uhh I don't know when or why this happens
        if b == nil then
            return false
        end

        data.curBlock = b
        data.blockOffset = (p.x + p.width/2) - (b.x + b.width/2)
    end

    p.speedX = 0
    p.speedY = 0
    p.forcedState = 8

    if isCeiling then
        data.digState = GROUND_TOP
        data.digPart:setParam("speedY", drill.ceilingParticleRange)
    else
        data.digState = GROUND_DOWN
        data.digPart:setParam("speedY", drill.particleRange)
    end

    if not noEffects then
        spawnFX(p, isCeiling)
        SFXPlay("digStart")
    end

    aw.preventWallSlide(p)
    
    local ps = PlayerSettings.get(pm.getBaseID(p.character), p.powerup)

    p:mem(0x164, FIELD_WORD, 0)
    p:mem(0x12E, FIELD_WORD, 1)
    p.height = ps.hitboxDuckHeight

    if not GP.custom then
        GP.cancelPound(p)
        GP.getData(p.idx).renderData.frameX = -999
    end

    data.angle = angle
    data.oldAngle = angle
    data.targetAngle = angle

    data.movementSpeed = 0
    data.digAnimTimer = 0
    data.digTimer = 0

    if cp.getCurrentID(p) == drill.id then
        GP.preventEffects(p)
    end

    return true
end

-- stops digging
function drill.stopDig(p, noEffects, isWeak)
    local data = playerData[p.idx]

    -- happens when character is changed, ????
    if not data then
        return
    end

    local canExit = true
    local ps = PlayerSettings.get(pm.getBaseID(p.character), p.powerup)
    local isCeiling = (data.digState == GROUND_TOP)

    if data.digState == GROUND_NONE then
        return false
    end

    boxCollider.width = p.width
    boxCollider.height = ps.hitboxHeight
    boxCollider.x = p.x
    boxCollider.y = p.y + p.height - boxCollider.height

    if isCeiling then
        boxCollider.y = p.y
    end

    -- search for blocks
    for k, v in ipairs(Colliders.getColliding{a = boxCollider, b = Block.SOLID, btype = Colliders.BLOCK}) do
        if v ~= data.curBlock and not jewelBlock.idMap[v.id] and Misc.canCollideWith(p, v) then
            canExit = false
            break
        end
    end

    -- search for block-like NPCs
    if canExit then
        for k, v in ipairs(Colliders.getColliding{a = boxCollider, b = NPC.PLAYERSOLID, btype = Colliders.NPC}) do
            if Misc.canCollideWith(p, v) then
                canExit = false
                break
            end
        end
    end

    if not canExit then
        p:mem(0x11E, FIELD_BOOL, false)
        p:mem(0x120, FIELD_BOOL, false)

        return false
    end

    -- handle exiting
    p.forcedState = 0
    p.forcedTimer = 0
    p.speedX = 0

    p:mem(0x11C, FIELD_WORD, 0)
    p:mem(0x11E, FIELD_BOOL, false)
    p:mem(0x120, FIELD_BOOL, false)

    if p.keys.altJump and drill.allowSpinjump then
        p:mem(0x50, FIELD_BOOL, true)
    end

    if not isCeiling then
        if not isWeak then
            p:mem(0x11C, FIELD_WORD, Defines.jumpheight * 1.3)
        else
            p.speedY = Defines.jumpspeed
        end
    end

    if not noEffects then
        spawnFX(p, isCeiling, isWeak)
        SFXPlay("digStop")
    end

    if isCeiling then
        p.height = ps.hitboxHeight
    else
        p.y = p.y + p.height - ps.hitboxHeight
        p.height = ps.hitboxHeight
    end

    if p.speedY ~= 0 then
        p:mem(0x132,FIELD_BOOL,true)
    end

    p:mem(0x134,FIELD_BOOL,true)

    for k, v in ipairs(Colliders.getColliding{a = p, b = jewelBlock.idList, btype = Colliders.BLOCK}) do
        v:remove()
    end

    if not isCeiling then
        hurtNPCsByHelmet(p, p)
    end

    data.digState = GROUND_NONE
    data.angle = 0
    data.angleLerp = 0
    data.oldAngle = 0
    data.targetAngle = 0
    data.curBlock = nil
    data.blockOffset = nil
    data.cooldown = 16

    p:mem(0x176, FIELD_WORD, 0)
    p:mem(0x140, FIELD_WORD, drill.iFrames)

    p:mem(0x164, FIELD_WORD, 0)
    p:mem(0x12E, FIELD_WORD, 0)

    if p.keys.left then
        p.speedX = -1.5
    elseif p.keys.right then
        p.speedX = 1.5
    end

    removeLoopSFX()

    return true
end

-- makes various blocks non-diggable
function drill.applyDefaultSettings()
    applySettings = true

    for _, id in ipairs(Block.NONSOLID .. Block.HURT .. Block.PLAYER .. Block.MEGA_SMASH .. Block.SEMISOLID) do
        if not drillSpot or not drillSpot.idMap[id] then
            drill.addNonDiggableBlock(id)
        end
    end

    local t = {
        -- pipes
          24, 570,1107,1109, 158, 157, 153, 154, 155, 156,1080, 377,1320,1346,1352,1358,1372,
          23, 569,1106,1108, 152, 151, 147, 148, 149, 150,1079, 376,1319,1345,1351,1357,1371,
        1364,1367,1365,1366,1341,1340,1336,1337,1338,1339,1081,1077,1321,1347,1353,1359,1373,
          22,  35,  37, 104, 114, 142, 143, 144, 145, 146, 195, 197,1317,1343,1349,1355,1369,
          21,  34,  36, 103, 113, 137, 138, 139, 140, 141, 194, 196,1316,1342,1348,1354,1368,
        1360,1363,1361,1362,1335,1331,1330,1332,1333,1334,1078,1076,1318,1344,1350,1356,1370,

        -- special blocks
         55, 159, 281, 458, 669, 670, 674, 675, 676, 677, 678, 679, 680, 691, 694, 696, 742,
        744, 745,1006,1007,1151,1277,1278,1374,1376,1378,1379,1380,1381,1382,1383,1384,1385,

        -- player blocks
        622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 639, 640, 641, 642, 643, 644,
        645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 659, 660, 663, 664,

        -- npc pass through blocks
        687, 1283, 1284, 1285, 1286, 1287, 1288, 1289, 1290, 1291,

        -- nitro crates
        1279, 1280, 1281,

        -- ?-blocks and bricks
        2, 4, 5, 60, 88, 89, 90, 188, 192, 193, 224, 225, 226, 280, 293, 737, 738, 739,
    }

    for _, id in ipairs(t) do
        drill.addNonDiggableBlock(id)
    end

    if not GP.custom then
        -- hit multihit npcs a bit more strongly (for non-bosses, this will simply kill them)
        local mulitHitHurtFunc = function(v, p, combo)
            if cp.getCurrentID(p) == drill.id then
                return v:harm(HARM_TYPE_NPC, nil, combo)
            else
                local newCombo = v:harm(HARM_TYPE_JUMP, nil, combo)
                GP.cancelPound(p)
                Colliders.bounceResponse(p, 1)

                return newCombo
            end
        end

        -- hurt the spiny npcs
        local spinyHurtFunc = function(v, p, combo)
            if cp.getCurrentID(p) == drill.id then
                return v:harm(HARM_TYPE_NPC, nil, combo)
            end
        end

        for k, id in ipairs(NPC.MULTIHIT) do
            GP.registerCustomNPCFunc(id, mulitHitHurtFunc)
        end

        for id = 1, NPC_MAX_ID do
            if NPC.config[id].jumphurt then
                GP.registerCustomNPCFunc(id, spinyHurtFunc)
            end
        end
    end
end


------------------------
-- Ground Pound Stuff --
------------------------

function GP.onBlockPound(e, v, p)
    if e.cancelled or GP.custom then
        return
    end

    local isJewelBlock = jewelBlock and jewelBlock.idMap[v.id]
    local isDrillPowerup = cp.getCurrentID(p) == drill.id

    if not isDrillPowerup then
        return
    end

    local data = playerData[p.idx]

    if isJewelBlock then
        data.hittingBlocks = true
        data.lastHittingBlocks = true
        data.fakeFrame = GP.getFrame(p)
        data.fakePos = p.y

        GP.preventEffects(p)
    else
        local digStarted = drill.startDig(p)

        if digStarted then
            e.cancelled = true
        end
    end
end

function GP.onPostBlockPound(v, p)
    local isJewelBlock = jewelBlock and jewelBlock.idMap[v.id]

    if not isJewelBlock or GP.custom then
        return
    end

    if cp.getCurrentID(p) ~= drill.id and v.data.hp == 0 then
        GP.cancelPound(p)
        GP.preventPoundJump(p)

        p.speedY = p.speedY/2
    end
end


--------------------
-- Enable/Disable --
--------------------

function drill.onEnable(p)
    if playerData[p.idx] == nil then
        playerData[p.idx] = {}
    end

    local data = playerData[p.idx]

    if not data.initializedImportant then
        local ps = PlayerSettings.get(pm.getBaseID(p.character), p.powerup)

        data.digPart = Particles.Emitter(0, 0, drill.digParticle)
        data.drillPart = Particles.Emitter(0, 0, drill.drillParticle)
        data.burrowCollider = Colliders.Box(0, 0, ps.hitboxWidth, 32)
        data.burrowSensor = Colliders.Box(0, 0, 2, 2)
        data.helmetCollider = Colliders.Box(0, 0, 24, 20)

        data.initializedImportant = true
    end

    -- misc.
    data.animTimer = 0
    data.digAnimTimer = 0
    data.digTimer = 0
    data.preventDigging = false
    data.cooldown = 0
    data.movementSpeed = 0
    
    -- dirt angle related
    data.angle = 0
    data.angleLerp = 0
    data.oldAngle = 0
    data.targetAngle = 0

    -- GP related
    data.hittingBlocks = false
    data.fakeFrame = false
    data.fakePos = 0

    data.drillTimer = 0
    data.lastHittingBlocks = false

    -- diggin related
    data.curBlock = nil
    data.blockOffset = nil
    data.digState = GROUND_NONE
end


function drill.onDisable(p)
    drill.stopDig(p, true)
    playerData[p.idx] = nil
end


----------------------
-- Digging Movement --
----------------------

local function handleMovement(p, data)
    -- if we need to find a new block, do it
    if data.curBlock == nil or data.curBlock.isHidden or not Colliders.collide(data.burrowSensor, data.curBlock) then
        local b = getStandingBlock(p, data.digState == GROUND_TOP, data.burrowSensor.x, data.burrowSensor.y, data.burrowSensor.width, data.burrowSensor.height)

        -- check the bigger collider (I hope this works)
        if b == nil then
            if data.digState == GROUND_DOWN then
                b = getStandingBlock(p, data.digState == GROUND_TOP, data.burrowCollider.x, data.burrowCollider.y, data.burrowCollider.width, data.burrowCollider.height + 2)
            else
                b = getStandingBlock(p, data.digState == GROUND_TOP, data.burrowCollider.x, data.burrowCollider.y - 2, data.burrowCollider.width, data.burrowCollider.height + 2)
            end
        end

        -- check again but a bit lower this time (I REALLY hope this works)
        if b == nil then
            if data.digState == GROUND_DOWN then
                b = getStandingBlock(p, data.digState == GROUND_TOP, data.burrowSensor.x, data.burrowSensor.y, data.burrowSensor.width, data.burrowSensor.height + 16)
            else
                b = getStandingBlock(p, data.digState == GROUND_TOP, data.burrowSensor.x, data.burrowSensor.y - 16, data.burrowSensor.width, data.burrowSensor.height + 16)
            end
        end

        -- okay, there are no blocks to attach to, retreat
        if b == nil then
            drill.stopDig(p, false, true)
            return
        end

        data.curBlock = b
        data.blockOffset = (p.x + p.width/2) - (b.x + b.width/2)
    end

    local b = data.curBlock
    local angleRad = math.rad(getBlockSlope(b))
    local bounds = p.sectionObj.boundary

    if nonDiggableBlocks[b.id] then
        drill.stopDig(p, false, true)
        return
    end

    local targetSpeed = drill.movementSpeed

    if p.keys.run then
        targetSpeed = drill.movementSpeedFast
    end

    if p.keys.left then
        data.movementSpeed = math.max(data.movementSpeed - drill.acceleration, -targetSpeed)
    elseif p.keys.right then
        data.movementSpeed = math.min(data.movementSpeed + drill.acceleration, targetSpeed)
    else
        if data.movementSpeed > 0 then
            data.movementSpeed = math.max(data.movementSpeed - drill.deceleration, 0)
        elseif data.movementSpeed < 0 then
            data.movementSpeed = math.min(data.movementSpeed + drill.deceleration, 0)
        end
    end

    if data.movementSpeed ~= 0 then
        data.digAnimTimer = data.digAnimTimer + 1 * math.abs(data.movementSpeed)/drill.movementSpeedFast
    end

    data.blockOffset = data.blockOffset + data.movementSpeed * math.cos(angleRad)

    local direction = math.sign(data.movementSpeed)
    local newX = math.clamp(b.x + b.width/2 + data.blockOffset - p.width/2, bounds.left, bounds.right - p.width)
    local newY = b.y - p.height

    if data.digState == GROUND_TOP then
        newY = b.y + b.height
    end

    -- don't go out of section bounds
    if newX <= bounds.left or newX >= (bounds.right - p.width) then
        newX = math.clamp(newX, bounds.left, bounds.right - p.width)
        data.blockOffset = (newX + p.width/2) - (b.x + b.width/2)
        data.movementSpeed = 0
    end
    
    -- duplicate intentional
    if Block.SLOPE_MAP[b.id] then
        newY = b.y + b.height - p.height + getYFromX(b, data.blockOffset)

        if data.digState == GROUND_TOP then
            newY = newY - b.height + p.height
        end
    end

    -- check if any block is in the way
    local linecastOffset = 0

    if data.digState == GROUND_TOP then
        linecastOffset = p.height
    end

    if direction < 0 then
        local blockList = getLinecastObjects(p, data, direction, newX, newY + 16, p.x, p.y + 16)

        if #blockList > 0 then
            local isColliding, point, normal, hitObj = Colliders.linecast(
                vector(p.x + p.width/2, p.y + linecastOffset),
                vector(newX - 8, newY + linecastOffset),
                blockList
            )

            if isColliding then
                local correctX = hitObj.x + hitObj.width

                if newX < correctX then
                    newX = hitObj.x + hitObj.width
                    data.blockOffset = (newX + p.width/2) - (b.x + b.width/2)
                    data.movementSpeed = 0
                end
            end
        end

    elseif direction > 0 then
        local blockList = getLinecastObjects(p, data, direction, p.x + p.width, p.y + 16, newX + p.width, newY + 16)

        if #blockList > 0 then
            local isColliding, point, normal, hitObj = Colliders.linecast(
                vector(p.x + p.width/2, p.y + linecastOffset),
                vector(newX + 8 + p.width, newY + linecastOffset),
                blockList
            )

            if isColliding then
                local correctX = hitObj.x - p.width

                if newX > correctX then
                    newX = hitObj.x - p.width
                    data.blockOffset = (newX + p.width/2) - (b.x + b.width/2)
                    data.movementSpeed = 0
                end
            end
        end
    end

    -- duplicate intentional
    if Block.SLOPE_MAP[b.id] then
        newY = b.y + b.height - p.height + getYFromX(b, data.blockOffset)

        if data.digState == GROUND_TOP then
            newY = newY - b.height + p.height
        end
    end

    p.x = newX
    p.y = newY

    local xcen = p.x + p.width/2
    local ybase = p.y + p.height

    if data.digState == GROUND_DOWN then
        data.burrowCollider.x = xcen - data.burrowCollider.width/2
        data.burrowCollider.y = ybase - data.burrowCollider.height

        data.burrowSensor.x = xcen - data.burrowSensor.width/2
        data.burrowSensor.y = ybase - data.burrowSensor.height/2
    else
        data.burrowCollider.x = xcen - data.burrowCollider.width/2
        data.burrowCollider.y = p.y

        data.burrowSensor.x = xcen - data.burrowSensor.width/2
        data.burrowSensor.y = p.y - data.burrowSensor.height/2
    end
end


-------------------
-- Digging State --
-------------------

local function handleDigging(p, data)
    -- various restrictions
    p:mem(0x140, FIELD_WORD, 1)
    p:mem(0x3C, FIELD_BOOL, false)

    p.keys.down = false

    aw.preventWallSlide(p)

    if not GP.custom then
        GP.preventPound(p)
        GP.preventPoundJump(p)
    end

    -- collect the drill spots
    if drillSpot then
        for k, v in Block.iterateIntersecting(p.x, p.y + p.height, p.x + p.width, p.y + p.height*2) do
            if drillSpot.idMap[v.id] and not v.isHidden and not v:mem(0x5A, FIELD_BOOL) then
                drillSpot.collect(v)
            end
        end
    end

    -- update dirt angle
    local newAngle = -getBlockSlope(data.curBlock)

    if data.targetAngle ~= newAngle then
        data.targetAngle = newAngle
        data.oldAngle = data.angle
        data.angleLerp = 0
    end

    if data.oldAngle ~= data.targetAngle then
        data.angleLerp = math.min(data.angleLerp + 0.2, 1)
        data.angle = math.lerp(data.oldAngle, data.targetAngle, easing.outSine(data.angleLerp, 0, 1, 1))

        if data.angleLerp == 1 then
            data.oldAngle = data.targetAngle
            data.angleLerp = 0
        end
    end

    data.digTimer = data.digTimer + 1

    if digLoopSFX == nil and data.digTimer > 20 then
        digLoopSFX = SFXPlay("digLoop", 0)
    end

    -- exiting
    local escapeInput = (p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED)

    if invalidState(p) or escapeInput or not isOnGround(p) then
        drill.stopDig(p, false, not escapeInput)
    end
end


-------------------------
-- Handle Groundpounds --
-------------------------

local function handleGroundPound(p, data, gpData)
    if data.hittingBlocks then
        if invalidState(p) or p.keys.jump then
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

            gpData.renderData.frameY = data.fakeFrame
            gpData.renderData.offset = vector(0, data.fakePos + math.sin(data.drillTimer * 0.5) * 2 - p.y)

            aw.preventWallSlide(p)
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
        spawnPoof(p.x + p.width/2, p.y + p.height)
    end
end


-----------------
-- Apply Logic --
-----------------

function drill.onTickPowerup(p)
    if not playerData[p.idx] then
	    return
    end

    local data = playerData[p.idx]
    local frame = math.floor(data.animTimer / drill.frameSpeed) % drill.frameCount

    data.animTimer = data.animTimer + 1

    if p.mount < 2 then
        if p.character ~= CHARACTER_LINK then
            p:mem(0x160, FIELD_WORD, 2)
        else
            p:mem(0x162, FIELD_WORD, 2)
        end
    end

    if not GP.custom then
        local gpData = GP.getData(p.idx)

        if data.digState == GROUND_NONE and p.forcedState == 0 then
            gpData.renderData.frameX = frame
        end

        handleGroundPound(p, data, gpData)
    end

    if data.digState == GROUND_NONE then
        if p.forcedState == 0 then
            Graphics.sprites[pm.getName(p.character)][drill.basePowerup].img = drill:getAsset(p.character, characterSprites[p.character][frame + 1])
            hurtNPCsByHelmet(p, data.helmetCollider)
        end

        data.cooldown = math.max(data.cooldown - 1, 0)

        if data.cooldown == 0 and not Defines.cheat_shadowmario then
            if p.keys.down and isOnGround(p) then
                drill.startDig(p)

            elseif p.speedY < 0 then
                boxCollider.width = p.width
                boxCollider.height = 2
                boxCollider.x = p.x + p.width/2 - boxCollider.width/2
                boxCollider.y = p.y - boxCollider.height

                for k, v in ipairs(Colliders.getColliding{a = boxCollider, b = Block.SOLID .. Block.PLAYERSOLID, btype = Colliders.BLOCK}) do
                    if Misc.canCollideWith(p, v) then
                        drill.startDig(p, true)
                        break
                    end
                end
            end
        end
    else
        handleDigging(p, data)
    end

    data.preventDigging = false
end


--------------------
-- Collider Stuff --
--------------------

function drill.onTickEndPowerup(p)
    local data = playerData[p.idx]

    if not data then
        return
    end

    if data.digState ~= GROUND_NONE then
        handleMovement(p, data)
    end

    data.helmetCollider.x = p.x + p.width/2 - data.helmetCollider.width/2
    data.helmetCollider.y = p.y - data.helmetCollider.height + 4
end


---------------
-- Rendering --
---------------

function drill.onDrawPowerup(p)
    local data = playerData[p.idx]

    if not data then
        return
    end

    local img = drill:getAsset(p.character, drill.digImages[p.character])
    local frame = math.floor(data.digAnimTimer / drill.digFramespeed) % drill.digFrames

    local shader, uniforms
	local color = Color.white

	if not p.hasStarman then
		if p.data.metalcapPowerupcapTimer then
			shader = metalShader
		elseif p.data.vanishcapPowerupcapTimer then
			shader = vanishShader
		end

	elseif p.hasStarman then
		shader = starShader
		uniforms = {time = lunatime.tick() * 2}

	elseif Defines.cheat_shadowmario then
		color = Color.black
	end

    data.drillPart.x = p.x + p.width/2
    data.drillPart.y = p.y + p.height
    data.drillPart.enabled = data.hittingBlocks

    data.digPart.x = p.x + p.width/2
    data.digPart.y = p.y + p.height
    data.digPart.enabled = (data.digState ~= GROUND_NONE)

    if data.digState == GROUND_TOP then
        data.digPart.y = p.y
    end

    data.drillPart:Draw(-24)
    data.digPart:Draw(-26)

    if data.digState ~= GROUND_NONE then
        local width = img.width
        local height = img.height/drill.digFrames

        local yScale = 1
        local yOffset = p.y + p.height

        local scale = 1 + 0.075 * (1 + math.sin(data.animTimer * 0.75))/2

        if data.digState == GROUND_TOP then
            yScale = -1
            yOffset = p.y
        end

        Graphics.drawBox{
            texture = img,
            x = p.x + p.width/2,
            y = yOffset,
            width = width * scale,
            height = height * yScale * scale,
            sourceX = 0,
            sourceY = frame * height,
            sourceWidth = width,
            sourceHeight = height,
            priority = -25,
            centered = true,
            sceneCoords = true,
            rotation = data.angle,
            color = color,
            shader = shader,
            uniforms = uniforms,
        }
    end

    if not GP.custom and data.hittingBlocks then
        local gpData = GP.getData(p.idx)

        p:setFrame(-50 * p.direction)
        GP.renderPlayer(p, gpData.renderData)
    end

    if drill.drawDebug then
        data.helmetCollider:draw(Color.red .. 0.5)

        data.burrowCollider:draw(Color.green .. 0.5)
        data.burrowSensor:draw(Color.yellow)

        boxCollider:draw(Color.blue .. 0.5)

        Text.print("Block Offset: " .. tostring(data.blockOffset), 100, 100)

        local b = data.curBlock

        if b ~= nil then
            Colliders.getHitbox(b):draw(Color.blue .. 0.5)
        end

        Graphics.drawBox{
            x = p.x,
            y = p.y,
            width = p.width,
            height = p.height,
            sceneCoords = true,
            color = Color.pink .. 0.5,
        }
    end
end


---------------------
-- Other Functions --
---------------------

function drill.onInitAPI()
    registerEvent(drill, "onStart")
    registerEvent(drill, "onNPCCollect")
end

function drill.onStart()
    if applySettings then
        if jewelBlock then
            for _, id in ipairs(jewelBlock.idList) do
                drill.addNonDiggableBlock(id)
            end
        end
    end
end

function drill.onNPCCollect(e, v, p)
    local data = playerData[p.idx]

    if e.cancelled or not data or cp.getCurrentID(p) ~= drill.id then
        return
    end

    if data.digState ~= GROUND_NONE and Colliders.collide(p, v) then
        e.cancelled = true
    end
end

return drill