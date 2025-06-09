local leaf = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function leaf.onInitPowerupLib()
    leaf.spritesheets = {
        leaf:registerAsset(1, "fireLeaf-mario.png"),
        leaf:registerAsset(2, "fireLeaf-luigi.png"),
        leaf:registerAsset(3, "fireLeaf-peach.png"),
        leaf:registerAsset(4, "fireLeaf-toad.png"),
    }

    leaf.gpImages = {
        leaf:registerAsset(CHARACTER_MARIO, "fireLeaf-groundPound-1.png"),
        leaf:registerAsset(CHARACTER_LUIGI, "fireLeaf-groundPound-2.png"),
    }
end

leaf.basePowerup = PLAYER_LEAF
leaf.forcedStateType = 2

local GP
pcall(function() GP = require("GroundPound") end)

leaf.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

leaf.projectileID = 13


local projectileTimerMax = {30, 60, 60, 25, 25}
local projectileTimer = {}

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

respawnRooms = respawnRooms or {}

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
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function leaf.onEnable(p)
	projectileTimer[p.idx] = 0
end

function leaf.onDisable(p)
end

function leaf.onTickPowerup(p)
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
                leaf.projectileID,
                p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
                p.y + p.height/2 + p.speedY, p.section, false, true
            )
            
			v.speedX = 4.5 * dir + (p.speedX / 2)
			v.ai1 = p.character
			
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

return leaf