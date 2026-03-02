
local explosions = Particles.Emitter(0, 0, Misc.resolveFile("powerups/cp_iceshroom_explosion.ini"))
local apt = {}

-- Variable "name" is reserved
-- variable "registerItems" is reserved

apt.apSounds = {
    upgrade = 6,
    reserve = 12
}

apt.items = {981} -- Items that can be collected

function apt.onInitPowerupLib()
    apt.spritesheets = {
        apt:registerAsset(1, "iceshroom-mario.png"), --Mario
        apt:registerAsset(2, "iceshroom-luigi.png"), --Luigi
        apt:registerAsset(3, "iceshroom-peach.png"), --Peach
        apt:registerAsset(4, "iceshroom-toad.png"), --Toad
        apt:registerAsset(5, "iceshroom-link.png"), --Link
    }

    apt.gpImages = {
        apt:registerAsset(CHARACTER_MARIO, "iceshroom-groundPound-1.png"),
        apt:registerAsset(CHARACTER_LUIGI, "iceshroom-groundPound-2.png"),
    }
end

--------------------
apt.projectileTimer = 45
apt.projectileTimerMax = {
    30,
    35,
    40,
    25,
    25
}
--------------------

local animFrames = {
    11,11,11,11,12,12,12,12,
}

apt.aliases = {"needaiceshroom"}

-- Runs when a player switches to this powerup. Use for setting stuff like global Defines.
function apt.onEnable()
	if isOverworld then return end
	if lunatime.tick() <= 1 then return end
    explosions.x = player.x + 0.5 * player.width
    explosions.y = player.y + 0.5 * player.height
	explosions:Emit(1)
	SFX.play("powerups/cp_explode.ogg")
    local circ = Colliders.Circle(player.x + 0.5 * player.width, player.y + 0.5 * player.height, 96)
    for k,n in ipairs(Colliders.getColliding{
        atype = Colliders.NPC,
        b = circ,
        filter = function(o)
            if NPC.HITTABLE_MAP[o.id] and not o.friendly and not o.isHidden then
                return true
            end
        end
    }) do
        n:harm(HARM_TYPE_EXT_ICE)
    end
end

-- Runs when player switches to this powerup. Use for resetting stuff from onEnable.
function apt.onDisable()

end

-- If you wish to have global onTick etc... functions, you can register them with an alias like so:
-- registerEvent(apt, "onTick", "onPersistentTick")

local function canShoot()
    return (
        apt.projectileTimer <= 0 and
        player.forcedState == 0 and
        player.deathTimer == 0 and
        player:mem(0x0C, FIELD_BOOL) == false -- fairy
    )
end

local function ducking()
    return player:mem(0x12E, FIELD_BOOL)
end

-- No need to register. Runs only when powerup is active.
function apt.onTick()

    apt.projectileTimer = apt.projectileTimer - 0.5
    
    if not canShoot() then return end

    if player.keys.altRun == KEYS_PRESSED and apt.projectileTimer <= 0 then
        explosions.x = player.x + 0.5 * player.width
        explosions.y = player.y + 0.5 * player.height
        explosions:Emit(1)
        SFX.play("powerups/cp_explode.ogg")
            local circ = Colliders.Circle(player.x + 0.5 * player.width, player.y + 0.5 * player.height, 96)
            for k,n in ipairs(Colliders.getColliding{
                atype = Colliders.NPC,
                b = circ,
                filter = function(o)
                    if NPC.HITTABLE_MAP[o.id] and not o.friendly and not o.isHidden then
                        return true
                    end
                end
            }) do
                n:harm(HARM_TYPE_EXT_ICE)
            end
            apt.projectileTimer = 45
    end
end

-- No need to register. Runs only when powerup is active.
function apt.onDraw()
        explosions:Draw(-5)
end

return apt
