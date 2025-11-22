local blockutils = require("blocks/blockutils")
local pm = require("playerManager")

local iceFlower = {}
local cp

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

-- Not multiplayer compatible

iceFlower.basePowerup = PLAYER_ICE
iceFlower.forcedStateType = 2
iceFlower.cheats = {"needacoolflower", "immadeofice"}

iceFlower.skateFramespeed = 8

iceFlower.waterFallBGOMap = table.map{66, 172}
iceFlower.waterPlatformSize = vector(32, 12)

iceFlower.skateOnWater = true
iceFlower.skateOnLava = true
iceFlower.skateDuration = -1

iceFlower.afterImageColor = Color.fromHexRGB(0x4090F0)
iceFlower.afterImageEnabled = true
iceFlower.afterImageFrequency = 4
iceFlower.afterImageFadespeed = 0.075

iceFlower.iceBlockSettings = {
    frames = 1,
	framespeed = 8,
	priority = -10,
    lifetime = 32,
}

iceFlower.images = {
    plain   = Graphics.loadImageResolved("iceblock-images/plain.png"),
    slope45 = Graphics.loadImageResolved("iceblock-images/slope-45.png"),
    slope26 = Graphics.loadImageResolved("iceblock-images/slope-26.png"),
}


function iceFlower.onInitPowerupLib()
    iceFlower.spritesheets = {
        iceFlower:registerAsset(CHARACTER_MARIO, "iceFlower-mario.png"),
        iceFlower:registerAsset(CHARACTER_LUIGI, "iceFlower-luigi.png"),
    }

    iceFlower.iniFiles = {
        iceFlower:registerAsset(CHARACTER_MARIO, "iceFlower-mario.ini"),
        iceFlower:registerAsset(CHARACTER_LUIGI, "iceFlower-luigi.ini"),
    }

    iceFlower.gpImages = {
        iceFlower:registerAsset(CHARACTER_MARIO, "iceFlower-groundPound-1.png"),
        iceFlower:registerAsset(CHARACTER_LUIGI, "iceFlower-groundPound-2.png"),
    }
end


local animFrames = {16, 17, 16, 18}
local playerData = {}
local spawnedBlocks = {}
local lavaBlacklist = table.map{405, 406, 420, 467, 468, 469, 470, 471, 473, 475, 477, 478, 481, 483, 484, 487}

local maskShader = Shader.fromFile(nil, "sh_solidColor.frag")
local afterImages = {}

local oldWeakLava = nil

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

respawnRooms = respawnRooms or {}

local effectOffsets = {
    vector(0, 1),
    vector(-1, 0),
    vector(0, -1),
    vector(1, 0),
}

local invisibleBlocks = {
    ["SOLID"] = 1006,

    ["FLOOR_LR"] = 1378,
    ["FLOOR_RL"] = 1379,

    ["CEIL_LR"] = 1381,
    ["CEIL_RL"] = 1380,

    ["30_FLOOR_LR"] = 1382,
    ["30_FLOOR_RL"] = 1383,

    ["30_CEIL_LR"] = 1385,
    ["30_CEIL_RL"] = 1384,
}

local solidEnds = {
    [1] = {vector(0, 0), vector(1, 0)}, -- up
    [2] = {vector(1, 0), vector(1, 1)}, -- right
    [3] = {vector(0, 1), vector(1, 1)}, -- down
    [4] = {vector(0, 0), vector(0, 1)}, -- left
}

local blockData = {
    [1006] = {name = "SOLID",       ends = solidEnds},
    [1378] = {name = "FLOOR_LR",    ends = {[1] = {vector(0, 1), vector(1, 0)}, [4] = {vector(0, 1), vector(1, 0)}}},
    [1379] = {name = "FLOOR_RL",    ends = {[1] = {vector(0, 0), vector(1, 1)}, [2] = {vector(0, 0), vector(1, 1)}}},
    [1381] = {name = "CEIL_LR",     ends = {[2] = {vector(0, 1), vector(1, 0)}, [3] = {vector(0, 1), vector(1, 0)}}},
    [1380] = {name = "CEIL_RL",     ends = {[3] = {vector(0, 0), vector(1, 1)}, [4] = {vector(0, 0), vector(1, 1)}}},
    [1382] = {name = "30_FLOOR_LR", ends = {[1] = {vector(0, 1), vector(1, 0)}, [4] = {vector(0, 1), vector(1, 0)}}},
    [1383] = {name = "30_FLOOR_RL", ends = {[1] = {vector(0, 0), vector(1, 1)}, [2] = {vector(0, 0), vector(1, 1)}}},
    [1385] = {name = "30_CEIL_LR",  ends = {[2] = {vector(0, 1), vector(1, 0)}, [3] = {vector(0, 1), vector(1, 0)}}},
    [1384] = {name = "30_CEIL_RL",  ends = {[3] = {vector(0, 0), vector(1, 1)}, [4] = {vector(0, 0), vector(1, 1)}}},
}


---------------------
-- Local Functions --
---------------------

local function canSkate(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == 0
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
        and (not p:isOnGround() or math.abs(p.speedX) > Defines.player_walkspeed/2)
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

local function getCorrectBlockID(id, is30Slope)
    local config = Block.config[id]
    local slopeAngle = "30_"

    if not is30Slope then
        slopeAngle = ""
    end

    if config.floorslope == -1 then
        return invisibleBlocks[slopeAngle .. "FLOOR_LR"]
    elseif config.floorslope == 1 then
        return invisibleBlocks[slopeAngle .. "FLOOR_RL"]
    end

    if config.ceilingslope == -1 then
        return invisibleBlocks[slopeAngle .. "CEIL_LR"]
    elseif config.ceilingslope == 1 then
        return invisibleBlocks[slopeAngle .. "CEIL_RL"]
    end

    return invisibleBlocks["SOLID"]
end

local function defaultCollisionFunc(v, col)
    return v:collide(col)
end

local function getCollisionFunc(l, col, x, y, w, h)
    return function(l, col)
        if x < col.x-w then
            return false;
        elseif x > col.x+col.width then
            return false;
        elseif y < col.y-h then
            return false;
        elseif y > col.y+col.height then
            return false;
        else
            return true;
        end
    end
end

local function collidingOnSide(p)
    local col = playerData[p.idx].colliderTheSecond

    col.width = 2
    col.height = p.height - 16
    col.x = p.x + p.width/2 * (p.direction + 1) - col.width/2
    col.y = p.y + p.height/2 - col.height/2

    for k, v in ipairs(Colliders.getColliding{a = col, b = Block.SOLID, btype = Colliders.BLOCK}) do
        if v:collidesWith(p) == 2 or v:collidesWith(p) == 4 then
            return true
        end
    end

    return false
end

local function getCollidingSide(v, p, collisionFunc, offset, thickness)
    if type(v) == "Block" and not Misc.canCollideWith(p, v) then
        return 0
    end

    if collisionFunc == nil then
        collisionFunc = defaultCollisionFunc
    end

    local col = playerData[p.idx].colliderTheSecond
    local offset = offset or 4

    thickness = thickness or 1

    if Block.SLOPE_MAP[v.id] then
        offset = 0
    end

    col.width = p.width - offset
    col.height = thickness
    col.x = p.x + p.width/2 - col.width/2
    col.y = p.y - col.height

    -- player below
    if collisionFunc(v, col) then
        return 3
    end

    col.y = p.y + p.height

    -- player on block
    if collisionFunc(v, col) then
        return 1
    end

    col.width = thickness
    col.height = p.height - offset
    col.x = p.x + p.width
    col.y = p.y + p.height/2 - col.height/2

    -- player on left
    if collisionFunc(v, col) then
        return 4
    end

    col.x = p.x - col.width

    -- player on right
    if collisionFunc(v, col) then
        return 2
    end

    -- no collision
    return 0
end

local function removeIceBlock(v)
    if not v.isValid then
        return
    end

    local parent = v.data._iceFlower.parent

    if parent and parent.isValid then
        parent.data._iceFlower_child = nil
    end

    v:delete()
end

local function onTickIceBlock(v, data)
    if v.isHidden or v:mem(0x5A, FIELD_BOOL) then
        return
    end

    local config = iceFlower.iceBlockSettings

    if not data.initialized then
        data.initialized = true
		data.timer = 0
        data.scaleTimer = 0
        data.scale = 0
	end

    data.timer = data.timer + 1

	for _,p in ipairs(Player.get()) do
		if data.timer <= config.lifetime or data.reset then
			data.scaleTimer = data.scaleTimer + 1

		elseif playerData[p.idx] and  getCollidingSide(v, p) == 0 and not data.reset then
			data.scaleTimer = math.max(data.scaleTimer - 1, 0)

			if data.scaleTimer == 0 then
				data.canRemove = true
			end
		end
	end

    data.scale = math.min(data.scaleTimer, 8)/8
    data.reset = nil

    if data.scale >= 0.5 and data.parent and Effect.count() <= 600 then
        local ends = blockData[v.id].ends[data.collidingDir] or solidEnds[data.collidingDir]
        local pos = math.lerp(ends[1], ends[2], RNG.random(0, 1))

        local e = Effect.spawn(74, v.x + pos.x * v.width, v.y + pos.y * v.height)
        e.x = e.x - e.width/2 + RNG.random(-2, 2) + effectOffsets[data.collidingDir].x * iceFlower.waterPlatformSize.y
        e.y = e.y - e.height/2 + RNG.random(-2, 2) + effectOffsets[data.collidingDir].y * iceFlower.waterPlatformSize.y
    end
end

local PLAYER_UP    = 1
local PLAYER_RIGHT = 2
local PLAYER_DOWN  = 3
local PLAYER_LEFT  = 4

local function getVisualDetails(v, collidingDir)
    local config = Block.config[v.id]

    local offset = vector(0, 0)
    local img = iceFlower.images.plain
    local rotation = 0

    local slopeRotation = math.deg(math.atan2(v.height, v.width))

    if (config.floorslope == -1 and collidingDir == PLAYER_LEFT)
    or (config.floorslope == 1 and collidingDir == PLAYER_RIGHT)
    or (config.ceilingslope == -1 and collidingDir == PLAYER_RIGHT)
    or (config.ceilingslope == 1 and collidingDir == PLAYER_LEFT)
    then
        return nil
    end

    -- draw a floor slope
    if config.floorslope ~= 0 and collidingDir == PLAYER_UP then
        if v.width == v.height then
            img = iceFlower.images.slope45
        else
            img = iceFlower.images.slope26
        end

        rotation = slopeRotation * config.floorslope
        offset.y = 4

    -- draw a ceiling slope
    elseif config.ceilingslope ~= 0 and collidingDir == PLAYER_DOWN then
        if v.width == v.height then
            img = iceFlower.images.slope45
        else
            img = iceFlower.images.slope26
        end

        rotation = slopeRotation * config.ceilingslope
        offset.y = -4

    -- draw the rest of the fucking blocks
    elseif collidingDir == PLAYER_UP then
        offset.y = img.height/2 - v.height/2
    elseif collidingDir == PLAYER_DOWN then
        offset.y = -(img.height/2 - v.height/2)
    elseif collidingDir == PLAYER_RIGHT then
        rotation = 90
        offset.x = -(img.height/2 - v.width/2)
    elseif collidingDir == PLAYER_LEFT then
        rotation = 90
        offset.x = img.height/2 - v.width/2
    end

    return img, offset, rotation
end

local function onCameraDrawIceBlock(v, data, camIdx)
    if v.isHidden or v:mem(0x5A, FIELD_BOOL) or not blockutils.visible(Camera(camIdx), v.x, v.y, v.width, v.height) then
        return
    end

	local config = iceFlower.iceBlockSettings
	local img, offset, rotation = getVisualDetails(v, data.collidingDir)

    if img == nil then
        return
    end

	local frame = math.floor(lunatime.drawtick() / config.framespeed) % config.frames
    local width = img.width
    local height = img.height/config.frames

	data.scale = data.scale or 0

	Graphics.drawBox{
		texture = img,
		x = v.x + v.width/2 + offset.x,
		y = v.y + v.height/2 + offset.y,
        width = width * data.scale,
        height = height * data.scale,
		sourceX = 0,
		sourceY = frame * height,
		sourceWidth = width,
		sourceHeight = height,
        rotation = rotation,
		sceneCoords = true,
        centered = true,
		priority = config.priority,
        color = Color.white .. data.scale,
	}
end


------------------
-- CP Functions --
------------------

function iceFlower.onEnable(p)
    if not playerData[p.idx] then
        playerData[p.idx] = {
            currentFrame = 0,
            collider = Colliders.Box(0, 0, 1, 1),
            colliderTheSecond = Colliders.Box(0, 0, 1, 1),
            skating = false,
            animTimer = 0,
            currentFrame = 0,
            inKnockBack = false,
            knockBackTimer = 0,
            initialDirection = 0,
            skateTimer = 0,
            canSpawnBlocks = true,
        }
    end

    local data = playerData[p.idx]

    if iceFlower.skateOnLava then
        oldWeakLava = Defines.weak_lava
        Defines.weak_lava = true
    end

    if p:isUnderwater() then
        data.canSpawnBlocks = false
    end
end

function iceFlower.onDisable(p)
    local data = playerData[p.idx]

    data.skating = false
    data.skateTimer = 0
    data.currentFrame = 0
    data.inKnockBack = false
    data.knockBackTimer = 0

    if iceFlower.skateOnLava then
        Defines.weak_lava = oldWeakLava
    end
end

function iceFlower.onTickPowerup(p)
    local data = playerData[p.idx]

    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    p:mem(0x0A, FIELD_BOOL, false)

    if p.deathTimer > 0 then
        return
    end

    if canSpawnSparkles(p) and RNG.random(10) > 9 then
        local e =  Effect.spawn(80, p.x - 12 + RNG.random(p.width + 16), p.y - 8 + RNG.random(p.height + 16), p.character)
        e.speedX = RNG.random(0.5) - 0.25
        e.speedY = RNG.random(0.5) - 0.25
	end

    if not p:isUnderwater() and not data.canSpawnBlocks then
        data.canSpawnBlocks = true
    end


    ------------------------------
    -- Ice Block Spawning logic --
    ------------------------------

    if data.canSpawnBlocks then
        if iceFlower.skateOnLava then
            for k, b in ipairs(Colliders.getColliding{a = data.collider, b = Block.LAVA, btype = Colliders.BLOCK}) do
                local collidingDir = getCollidingSide(b, p)

                if collidingDir > 0 and not lavaBlacklist[b.id] then
                    if not b.data._iceFlower_children then
                        b.data._iceFlower_children = {}
                    end

                    local children = b.data._iceFlower_children
                    local child = children[collidingDir]
                    local iceID = getCorrectBlockID(b.id, b.width/b.height ~= 1)

                    if not child or not child.isValid then
                        local newB = Block.spawn(iceID, b.x, b.y)

                        newB.data._iceFlower = {
                            parent = b,
                            collidingDir = collidingDir,
                        }

                        local img = Graphics.sprites.block[iceID].img
                        newB.width = img.width
                        newB.height = img.height

                        children[collidingDir] = newB
                        table.insert(spawnedBlocks, newB)
                    else
                        child.data._iceFlower.reset = true
                    end
                end
            end
        end

        if math.abs(p.speedX) > Defines.player_walkspeed then
            p.x = p.x + (p.width * p.direction * 2 + p.speedX)
            data.colliderTheSecond.x = data.colliderTheSecond.x + (p.width * p.direction * 2 + p.speedX)
        end

        if iceFlower.skateOnWater then
            for k, l in ipairs(Liquid.getIntersecting(
                p.x - 1 - iceFlower.waterPlatformSize.x + p.speedX,
                p.y - 1 - iceFlower.waterPlatformSize.y + p.speedY,
                p.x + p.width + 1 + iceFlower.waterPlatformSize.x + p.speedX,
                p.y + p.height + 1 + iceFlower.waterPlatformSize.y + p.speedY
            )) do
                -- intentional to not use l.isHidden, because I want compatibility with icantswim.lua
                if not l.isQuicksand and not l.layer.isHidden then
                    local collidingDir = getCollidingSide(l, p, getCollisionFunc(l, col, l.x, l.y, l.width, l.height), 8, iceFlower.waterPlatformSize.y + 2)

                    if collidingDir > 0 then
                        local x, y
                        local w, h = iceFlower.waterPlatformSize.x, iceFlower.waterPlatformSize.y

                        if collidingDir == 1 then
                            x = p.x + p.width/2 - w/2
                            y = l.y - h
                            p.y = math.min(y - p.height, p.y)

                        elseif collidingDir == 2 then
                            w, h = h, w
                            x = l.x + l.width
                            y = p.y + p.height/2 - h/2
                            p.x = math.max(x + w, p.x)

                        elseif collidingDir == 3 then
                            x = p.x + p.width/2 - w/2
                            y = l.y + l.height
                            p.y = math.max(y + h, p.y)

                        elseif collidingDir == 4 then
                            w, h = h, w
                            x = l.x - w
                            y = p.y + p.height/2 - h/2
                            p.x = math.min(x - p.width, p.x)
                        end

                        if collidingDir % 2 ~= 0 then
                            x = math.clamp(x, l.x, l.x + l.width - w)
                        else
                            y = math.clamp(y, l.y, l.y + l.height - h)
                        end

                        local canSpawn = true
                        local b = nil

                        for k, v in ipairs(spawnedBlocks) do
                            if v.isValid and getCollisionFunc(l, v, x,y,w,h)(l, v) then
                                if collidingDir % 2 ~= 0 and math.abs((x+w/2) - (v.x+v.width/2)) < 16 then
                                    canSpawn = false
                                    break
                                elseif collidingDir % 2 == 0 and math.abs((y+h/2) - (v.y+v.height/2)) < 16 then
                                    canSpawn = false
                                    break
                                end

                                b = v
                            end
                        end

                        if b then
                            if collidingDir % 2 ~= 0 then
                                local dir = math.sign((x+w/2) - (b.x+b.width/2))
                                x = (b.x + b.width/2) + dir * (b.width/2 + w/2) - w/2

                                if x < l.x or x > (l.x + l.width - w) then
                                    canSpawn = false
                                end
                            else
                                local dir = math.sign((y+h/2) - (b.y+b.height/2))
                                y = (b.y + b.height/2) + dir * (b.height/2 + h/2) - h/2

                                if y < l.y or y > (l.y + l.height - h) then
                                    canSpawn = false
                                end
                            end
                        end

                        if canSpawn then
                            local newB = Block.spawn(invisibleBlocks["SOLID"], x, y)

                            newB.width = w
                            newB.height = h

                            newB.data._iceFlower = {
                                collidingDir = collidingDir,
                            }

                            table.insert(spawnedBlocks, newB)
                        end
                    end
                end
            end
        end

        if math.abs(p.speedX) > Defines.player_walkspeed then
            p.x = p.x - (p.width * p.direction * 2 + p.speedX)
            data.colliderTheSecond.x = data.colliderTheSecond.x - (p.width * p.direction * 2 + p.speedX)
        end

        for k, b in BGO.iterateIntersecting(
            p.x - iceFlower.waterPlatformSize.y - 2,
            p.y,
            p.x + p.width + iceFlower.waterPlatformSize.y + 2,
            p.y + p.height
        ) do
            local sign = math.sign(p.x + p.width/2 - b.x - b.width/2)
            
            if iceFlower.waterFallBGOMap[b.id] and sign ~= 0 then
                local x

                if sign == 1 then
                    x = b.x + b.width
                    p.x = math.max(x + iceFlower.waterPlatformSize.y, p.x)
                elseif sign == -1 then
                    x = b.x - iceFlower.waterPlatformSize.y
                    p.x = math.min(x - p.width, p.x)
                end

                local child = b.data._iceFlower_children

                if not child or not child.isValid then
                    local newB = Block.spawn(invisibleBlocks["SOLID"], x, b.y)

                    newB.width = iceFlower.waterPlatformSize.y
                    newB.height = iceFlower.waterPlatformSize.x

                    newB.data._iceFlower = {
                        collidingDir = sign + 3,
                    }

                    table.insert(spawnedBlocks, newB)
                    b.data._iceFlower_children = newB
                else
                    child.data._iceFlower.reset = true
                end
            end
        end
    end


    -------------
    -- Skating --
    -------------

    if canSkate(p) and p:isOnGround() and p.keys.altRun == KEYS_PRESSED and not data.skating and (not aw or aw.isWallSliding(p) == 0) then
        data.skating = true
        data.skateTimer = 0
        p.speedX = math.max(math.abs(p.speedX), Defines.player_walkspeed) * p.direction
        data.initialDirection = p.direction
    end

    if data.skating then
        local stopSkaing = false

        data.skateTimer = data.skateTimer + 1

        if p:isOnGround() then
            data.animTimer = data.animTimer + 1
            data.currentFrame = (math.floor(data.animTimer/iceFlower.skateFramespeed) % #animFrames) + 1

            p.speedX = math.clamp(math.abs(p.speedX), data.animTimer, 8) * p.direction
            p.keys.run = false
        else
            data.animTimer = 0
            data.currentFrame = 0
        end

        if p.speedX < 0 and p.keys.right then
            stopSkaing = true
            p.speedX = p.speedX/2
        elseif p.speedX > 0 and p.keys.left then
            stopSkaing = true
            p.speedX = p.speedX/2
        end

        if math.sign(p.speedX) ~= data.initialDirection or collidingOnSide(p) then
            stopSkaing = true
            data.inKnockBack = true
            p.speedX = -Defines.player_walkspeed * data.initialDirection
            p.speedY = -4
        end

        if p:isOnGround() and aw then
            aw.preventWallSlide(p)
        end

        if not canSkate(p) or stopSkaing or (iceFlower.skateDuration > 0 and data.skateTimer >= iceFlower.skateDuration) then
            data.skating = false
            data.skateTimer = 0
            data.currentFrame = 0
            data.animTimer = 0
        end
    end

    if data.inKnockBack then
        p.keys.run = false
        p.keys.jump = false
        p.keys.altRun = false
        p.keys.altJump = false
        p.keys.left = false
        p.keys.right = false
        p.keys.up = false
        p.keys.down = false

        data.knockBackTimer = data.knockBackTimer + 1

        if data.knockBackTimer == 16 then
            data.inKnockBack = false
            data.knockBackTimer = 0
        end
    end
end

function iceFlower.onTickEndPowerup(p)
    local data = playerData[p.idx]

    data.collider.width = p.width + 8
    data.collider.height = p.height + 8
    data.collider.x = p.x + p.width/2 - data.collider.width/2
    data.collider.y = p.y + p.height/2 - data.collider.height/2

    local canPlay = (
        math.sign(p.speedX) == p.direction
        and not p:mem(0x12E, FIELD_BOOL)
    )

    if data.currentFrame > 0 and canPlay then
        p:setFrame(animFrames[data.currentFrame])
    end

    if data.inKnockBack and not p:mem(0x12E, FIELD_BOOL) then
        p:setFrame(6)
    end

    if data.skating and iceFlower.afterImageEnabled and data.skateTimer % iceFlower.afterImageFrequency == 0 then
        table.insert(afterImages, {
            texture = Graphics.sprites[pm.getName(p.character)][iceFlower.basePowerup].img,
            x = p.x,
            y = p.y,
            opacity = 1,
            direction = p.direction,
            frame = p:getFrame(),
            player = p,
        })
    end
end


---------------------
-- Other Functions --
---------------------

function iceFlower.onInitAPI()
    registerEvent(iceFlower, "onTick")
    registerEvent(iceFlower, "onDraw")
    registerEvent(iceFlower, "onCameraDraw")
    registerEvent(iceFlower, "onPlayerHarm")

    cp = require("customPowerups")
end

function iceFlower.onTick()
    for k = #spawnedBlocks, 1, -1 do
        local v = spawnedBlocks[k]
        local data = v.data._iceFlower

        if v.isValid and not data.canRemove then
            onTickIceBlock(v, data)
        else
            removeIceBlock(v)
            table.remove(spawnedBlocks, k)
        end
    end

    for k = #afterImages, 1, -1 do
        local v = afterImages[k]

        v.opacity = v.opacity - iceFlower.afterImageFadespeed

        if v.opacity <= 0 then
            table.remove(afterImages, k)
        end
    end
end

function iceFlower.onDraw()
    for k, v in ipairs(afterImages) do
        v.player:render{
            texture = v.texture,
            x = v.x,
            y = v.y,
            frame = v.frame,
            direction = v.direction,
            ignorestate = true,
            color = Color.white .. v.opacity,
            mount = 0,
            sceneCoords = true,
            priority = -26,
            shader = maskShader,
            uniforms = {
                color = iceFlower.afterImageColor,
            },
        }
    end
end

function iceFlower.onCameraDraw(camIdx)
    for k, v in ipairs(spawnedBlocks) do
        onCameraDrawIceBlock(v, v.data._iceFlower, camIdx)
    end
end

function iceFlower.onPlayerHarm(e, p)
    if not iceFlower.skateOnLava or cp.getCurrentPowerup(p) ~= iceFlower then
        return
    end
    
    local data = playerData[p.idx]
    local diedToLava = false

    local collider = Colliders.Box(p.x - 1, p.y - 1, p.width + 2, p.height + 2)

    for k, b in ipairs(Colliders.getColliding{a = collider, b = Block.LAVA, btype = Colliders.BLOCK}) do
        if Misc.canCollideWith(p, b) then
            diedToLava = true
            break
        end
    end

    if diedToLava then
        e.cancelled = true
    end
end

function respawnRooms.onPreReset(fromRespawn)
    for k, v in ipairs(spawnedBlocks) do
        removeIceBlock(v)
    end

    spawnedBlocks = {}
    afterImages = {}
end

return iceFlower