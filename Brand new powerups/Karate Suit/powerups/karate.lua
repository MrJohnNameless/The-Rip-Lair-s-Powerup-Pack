local karate = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

karate.basePowerup = PLAYER_FIREFLOWER
karate.forcedStateType = 1
karate.cheats = {"needakaratesuit"}


karate.cooldown = 16


function karate.onInitPowerupLib()
    karate.spritesheets = {
        karate:registerAsset(CHARACTER_MARIO, "karate-mario.png"),
        karate:registerAsset(CHARACTER_LUIGI, "karate-luigi.png"),
    }

    karate.iniFiles = {
        karate:registerAsset(CHARACTER_MARIO, "karate-mario.ini"),
        karate:registerAsset(CHARACTER_LUIGI, "karate-luigi.ini"),
    }
end


local playerData = {}

local ATTACK = {
    NONE        = 0,
    GROUND_KICK = 1,
    AERIAL_KICK = 2,
    INIT_PUNCH  = 3,
    NEXT_PUNCH  = 4,
}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)


local attackData = {
    [ATTACK.GROUND_KICK]  = {
        animation = {27, framespeed = 8},

        colliderFunc = function(p, col)
            col.width = 24
            col.height = 24
            col.x = p.x + p.width/2 + (col.width/2) * p.direction - col.width/2
            col.y = p.y + p.height - col.height - 4
        end,

        onTick = function(p, data, atkData)
            data.animTimer = data.animTimer + 1

            if data.timer == 0 then
                p.speedX = 5 * p.direction
                data.canHarm = true
            end

            if data.timer >= 32 then
                p.speedX = p.speedX * 1/3
                return true
            end
        end,
    },

    [ATTACK.AERIAL_KICK]  = {
        animation = {28, framespeed = 8},

        colliderFunc = function(p, col)
            col.width = 24
            col.height = 24
            col.x = p.x + p.width/2 + (col.width/2) * p.direction - col.width/2
            col.y = p.y + p.height - col.height - 4
        end,

        onTick = function(p, data, atkData)
            data.animTimer = data.animTimer + 1

            if data.timer == 0 then
                p.speedX = 6 * p.direction
				data.canHarm = true
			elseif data.timer == 1 then
				p.speedY = -6
            elseif data.timer <= 24 and not data.knockedBack then
                p.speedY = math.min(p.speedY, -Defines.player_grav)
            end

            if data.timer >= 48 then
                data.canDoAerialKick = false
                return true
            end
        end,
    },

    [ATTACK.INIT_PUNCH] = {
        animation = {47,48,49, framespeed = 6},

        colliderFunc = function(p, col)
            col.width = 24
            col.height = 24
            col.x = p.x + p.width/2 + (col.width/2 + 4) * p.direction - col.width/2
            col.y = p.y + 32 - col.height/2
        end,

        onTick = function(p, data, atkData)
            local animData = atkData.animation
            local limit = #animData * animData.framespeed - 1

            if not data.reachedLimit and data.animTimer < limit then
                data.animTimer = data.animTimer + 1

                if data.animTimer == animData.framespeed then
                    p.speedX = 5 * p.direction
                    data.canHarm = true
                end
            else
                data.reachedLimit = true
            end
			
			if data.timer > (limit - 48) then data.canUseSecondPunch = true end
			
            if data.reachedLimit and data.timer > (limit + 32) and p:isOnGround() then
                if data.animTimer == (limit - animData.framespeed) then
                    p.speedX = -3 * p.direction
                    data.canHarm = false
                end

                data.animTimer = data.animTimer - 1
            end
			
			if p.keys.jump then return true end

            if ((not p:isOnGround() and data.timer > (limit + 32)) or data.animTimer == -animData.framespeed) and data.reachedLimit then
                return true
            end
        end,
    },

    [ATTACK.NEXT_PUNCH] = {
        animation = {37,38, framespeed = 8},

        colliderFunc = function(p, col)
            col.width = 24
            col.height = 24
            col.x = p.x + p.width/2 + (col.width/2 + 4) * p.direction - col.width/2
            col.y = p.y + 32 - col.height/2
        end,

        onTick = function(p, data, atkData)
            local animData = atkData.animation
		
			if p.keys.left == KEYS_PRESSED then
				p.direction = -1
			elseif p.keys.right == KEYS_PRESSED then
				p.direction = 1
			end

            data.animTimer = math.min(data.animTimer + 1, #animData * animData.framespeed - 1)

            if data.timer == 0 then
                p.speedX = 4 * p.direction
                data.canHarm = true
            end

			if p.keys.down then return "GROUND_KICK" end
			if p.keys.jump then return true end

            if data.timer > 32 then
                return true
            end
        end,
    },
}


---------------------
-- Local Functions --
---------------------

local function canAttack(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and p.mount == MOUNT_NONE
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and not p:mem(0x50, FIELD_BOOL)
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and not p:mem(0x50, FIELD_BOOL)
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

local function getAttack(p, data)
    if not p:isOnGround() and data.attack == ATTACK.NONE and data.canDoAerialKick then
        return "AERIAL_KICK"
    end

    if not p:isOnGround() then
        return "NONE"
    end

    local canDoGroundKick = true

    if p.standingNPC and NPC.config[p.standingNPC.id].grabtop then
        canDoGroundKick = false
    end

    if p:mem(0x12E, FIELD_BOOL) and canDoGroundKick and data.attack == ATTACK.NONE then
        return "GROUND_KICK"
    end

    if p:mem(0x12E, FIELD_BOOL) then
        return "NONE"
    end

    if data.attack == ATTACK.NONE then
        return "INIT_PUNCH"
    elseif data.attack == ATTACK.INIT_PUNCH and data.canUseSecondPunch then
        return "NEXT_PUNCH"
    end

    return "NONE"
end


------------------
-- CP Functions --
------------------

function karate.onEnable(p, noEffects)
    if not playerData[p.idx] then
        playerData[p.idx] = {
            attack = ATTACK.NONE,
            initDirection = 0,
            cooldown = 0,
            collider = Colliders.Box(0, 0, 1, 1),
            timer = 0,
            animTimer = 0,

            canDoAerialKick = true,
            reachedLimit = false,
            knockedBack = false,
            canHarm = false,
            canUseSecondPunch = false,
        }
    end

    --playerData[p.idx].collider:debug(true)
end

function karate.onDisable(p, noEffects)
    local data = playerData[p.idx]

    data.attack = ATTACK.NONE
    data.cooldown = 0
    p:mem(0x164, FIELD_WORD, 0)
end

function karate.onTickPowerup(p)
    local data = playerData[p.idx]

    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if not data.canDoAerialKick and p:isOnGround() and data.attack ~= ATTACK.AERIAL_KICK then
        data.canDoAerialKick = true
    end

    local atk = ATTACK[getAttack(p, data)]

    if canAttack(p) and p.keys.run == KEYS_PRESSED and atk ~= ATTACK.NONE and atk ~= data.attack then
        data.attack = atk
        data.timer = 0
        data.animTimer = 0
        data.initDirection = p.direction
        data.reachedLimit = false
        data.knockedBack = false
        data.canHarm = false
        data.canUseSecondPunch = false
    end

    if data.attack == ATTACK.NONE then return end

    local atkData = attackData[data.attack]
    local canExit = atkData.onTick(p, data, atkData)

    data.timer = data.timer + 1

    p:mem(0x164, FIELD_WORD, -1)
    p:mem(0x12E, FIELD_WORD, 0)

    p:mem(0x172, FIELD_BOOL, false)

    p.keys.left = false
    p.keys.right = false
    p.keys.up = false
    p.keys.down = false
    p.keys.altJump = false

    if not data.knockedBack and data.canHarm then
        for k, v in ipairs(Colliders.getColliding{a = data.collider, b = Block.SOLID, btype = Colliders.BLOCK}) do
            if v.contentID == 0 and Block.MEGA_SMASH_MAP[v.id] then
                v:remove(true)
            else
                v:hit(true, p)
                data.knockedBack = true
                p.speedX = -3 * data.initDirection

                if v.contentID == 0 then
                    SFX.play(2)
                end
            end

            local e = Effect.spawn(
                75,
                (data.collider.x + data.collider.width/2 + v.x + v.width/2)/2,
                (data.collider.y + data.collider.height/2 + v.y + v.height/2)/2
            )

            e.x = e.x - e.width/2
            e.y = e.y - e.height/2
        end

        for k, v in ipairs(Colliders.getColliding{a = data.collider, b = NPC.HITTABLE, btype = Colliders.NPC}) do
            v:harm(HARM_TYPE_NPC)

            if NPC.MULTIHIT_MAP[v.id] then
                data.knockedBack = true
                p.speedX = -3 * data.initDirection
            end
        end
    end

    if p:isOnGround() then
        Effect.spawn(74, p.x + RNG.random(p.width/2) + 4 + p.speedX, p.y + p.height + RNG.random(-4, 4) - 4)
    end

    if canExit or not canAttack(p) or p.keys.altRun then
        data.attack = ATTACK.NONE
        p:mem(0x164, FIELD_WORD, 0)
    end
end

function karate.onTickEndPowerup(p)
    local data = playerData[p.idx]

    data.collider.width = 32
    data.collider.height = p.height - 8
    data.collider.x = p.x + p.width/2 + data.collider.width/2 * p.direction - data.collider.width/2
    data.collider.y = p.y + p.height/2 - data.collider.height/2

    if data.attack == ATTACK.NONE then
        return
    end

    attackData[data.attack].colliderFunc(p, data.collider)

    local animData = attackData[data.attack].animation
    local frame = animData[(math.floor(math.max(data.animTimer, 0) / animData.framespeed) % #animData) + 1]

    if frame and canAttack(p) then
        p:setFrame(frame)
    end
end

return karate