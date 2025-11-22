--[[

    Cape for anotherpowerup.lua
    by MrDoubleA

    Credit to JDaster64 for making a SMW physics guide and ripping SMA4 Mario/Luigi sprites
    Custom Toad and Link sprites by Legend-Tony980 (https://www.deviantart.com/legend-tony980/art/SMBX-Toad-s-sprites-Fourth-Update-724628909, https://www.deviantart.com/legend-tony980/art/SMBX-Link-s-sprites-Sixth-Update-672269804)
    Custom Peach sprites by Lx Xzit and Pakesho
    SMW Mario and Luigi graphics from AwesomeZack

    Credit to FyreNova for generally being cool (oh and maybe working on a SMBX38A version of this, too)

]]

local ai = require("powerups/cp_laserSuit_ai")

local apt = {}

apt.apSounds = {
    upgrade = SFX.open(Misc.resolveSoundFile("powerups/cp_cape_get")),
    reserve = 12
}

apt.items = {854}
apt.cheats = {"needalasesuit","notahoax"}
apt.forcedStateType = 2

function apt.onInitPowerupLib()
    apt.spritesheets = {
        apt:registerAsset(1, "mario-ap_laser.png"),
        apt:registerAsset(2, "luigi-ap_laser.png"),
        --apt:registerAsset(3, "peach-ap_laser.png"),
        --apt:registerAsset(4, "toad-ap_laser.png"),
        --apt:registerAsset(5, "link-ap_laser.png"),
    }

    apt.iniFiles = {
        apt:registerAsset(1, "mario-ap_laser.ini"),
        apt:registerAsset(2, "luigi-ap_laser.ini"),
		--apt:registerAsset(3, "peach-ap_laser.ini"),
        --apt:registerAsset(4, "toad-ap_laser.ini"),
        --apt:registerAsset(5, "link-ap_laser.ini"),
    }

    apt.capeSpritesheets = {
        apt:registerAsset(1, "mario-ap_laser_cape.png"),
        apt:registerAsset(2, "luigi-ap_laser_cape.png"),
        --apt:registerAsset(3, "peach-ap_laser_cape.png"),
        --apt:registerAsset(4, "toad-ap_laser_cape.png"),
        --apt:registerAsset(5, "link-ap_laser_cape.png"),
    }

    ai.getAsset = apt.getAsset
end

ai.register(apt)

function apt.onEnable(p)
    ai.onEnable(apt,p)
end
function apt.onDisable(p)
    ai.onDisable(apt,p)
end

function apt.onTickPowerup(p)
    ai.onTick(apt,p)
end
function apt.onTickEndPowerup(p)
    ai.onTickEnd(apt,p)
end
function apt.onDrawPowerup(p)
    ai.onDraw(apt,p)
end


return apt
