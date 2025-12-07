local goalTape = require("npcs/AI/goalTape")
local cursedWart = {}
local cp

local STATE = {
    IDLE  = 0,
    SHOOT = 1,
    HURT  = 2,
}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

cursedWart.projectileID = 783

cursedWart.basePowerup = PLAYER_FIREFLOWER
cursedWart.cheats = {"needacursedWartSuit", "frogfucius"}
cursedWart.forcedStateType = 2
cursedWart.dontGoToReserve = true


cursedWart.cellSize = vector(100, 100)
cursedWart.textureOffset = vector(0, 10)

cursedWart.health = 6
cursedWart.knockbackSpeed = vector(-5, -6)

cursedWart.animData = {
    [STATE.IDLE]  = {frames = 2, frameX = 1, framespeed = 8},
    [STATE.SHOOT] = {frames = 1, frameX = 2, framespeed = 8},
    [STATE.HURT]  = {frames = 2, frameX = 3, framespeed = 8},
}

local powerupRevert = require("powerups/powerupRevert")
powerupRevert.register("Cursed Wart Suit", 2)

local emptyImage = Graphics.loadImageResolved("stock-32.png")
local iniFile = Misc.resolveFile("powerups/cursedWart.ini")

cursedWart.spritesheets = {
    emptyImage,
    emptyImage,
    emptyImage,
    emptyImage,
}

cursedWart.iniFiles = {
    iniFile,
    iniFile,
    iniFile,
    iniFile,
}

function cursedWart.onInitPowerupLib()
    cursedWart.playerImages = {
        cursedWart:registerAsset(CHARACTER_MARIO, "cursedWart-mario.png"),
        cursedWart:registerAsset(CHARACTER_LUIGI, "cursedWart-luigi.png"),
        cursedWart:registerAsset(CHARACTER_PEACH, "cursedWart-toad.png"), -- placeholder
        cursedWart:registerAsset(CHARACTER_TOAD,  "cursedWart-toad.png"),
    }
end


local curHealth = 0
local hurtTimer = -1
local state = 0
local animTimer = 0
local curFrame = 0
local shootTimer = -1
local shootSFX = nil

local starShader = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))

local metalShader = Shader()
metalShader:compileFromFile(nil, Misc.resolveFile("metalShader.frag") or nil)

local vanishShader = Shader()
vanishShader:compileFromFile(nil, Misc.resolveFile("vanishShader.frag") or nil)

local GP
pcall(function() GP = require("GroundPound") end)

local APDL
pcall(function() APDL = require("anotherPowerDownLibrary") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local health
pcall(function() health = require("customHealth") end)


---------------------
-- Local Functions --
---------------------

local function canShoot(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and Level.endState() == LEVEL_WIN_TYPE_NONE
    )
end

local function changeState(newState, forced)
    if state == newState and not forced then
        return
    end

    state = newState
    animTimer = 0
end


------------------
-- CP Functions --
------------------

function cursedWart.onEnable(p, noEffects)
    Defines.player_grabSideEnabled = false
    Defines.player_grabTopEnabled = false
    Defines.player_grabShellEnabled = false

    Defines.player_grav = 0.6
    Defines.jumpheight = 15
    Defines.jumpspeed = -5.5
    Defines.jumpheight_bounce = 15
    Defines.jumpheight_player = 15
    Defines.player_runspeed = Defines.player_walkspeed

    curHealth = cursedWart.health
    changeState(STATE.IDLE, true)
	
	if APDL then
		APDL.enabled = false
	end
end

function cursedWart.onDisable(p, noEffects)
    Defines.player_grabSideEnabled = nil
    Defines.player_grabTopEnabled = nil
    Defines.player_grabShellEnabled = nil

    Defines.player_grav = nil
    Defines.jumpheight = nil
    Defines.jumpspeed = nil
    Defines.jumpheight_bounce = nil
    Defines.jumpheight_player = nil
    Defines.player_runspeed = nil

    p:mem(0x164, FIELD_WORD, 0)
	
	if APDL then
		APDL.enabled = true
	end
end

function cursedWart.onTickPowerup(p)
    if GP then
        GP.preventPound(p)
    end

    if aw then
        aw.preventWallSlide(p)
    end

    p:mem(0x160, FIELD_WORD, 2)
    p:mem(0xBC, FIELD_WORD, 2)
    p:mem(0x2C, FIELD_DFLOAT, 0)
    p:mem(0x40, FIELD_WORD, 0)

    p:mem(0x164, FIELD_WORD, -1)
    p:mem(0x12E, FIELD_WORD, 0)

    p:mem(0x120, FIELD_BOOL, false)

    local keyCombo = p.keys.run or p.keys.altRun

    if keyCombo and canShoot(p) and hurtTimer == -1 then
        changeState(STATE.SHOOT)

        if not shootSFX or not shootSFX:isplaying() then
            shootSFX = SFX.play(62)
        end

        if shootTimer % 10 == 0 then
            local n = NPC.spawn(
                cursedWart.projectileID,
                p.x + p.width/2 + 8 * p.direction,
                p.y,
                p.section, false, true
            )

            n.direction = p.direction
            n.speedX = 7 * n.direction * (1 - shootTimer/140)
            n.speedY = -10 + LegacyRNG.generateNumber() * 6
        end

        shootTimer = shootTimer + 1

        if shootTimer == 120 then
            shootTimer = 0
        end

    elseif state == STATE.SHOOT then
        shootTimer = 0
        changeState(STATE.IDLE) 
    end

    if state ~= STATE.SHOOT and shootSFX then
        shootSFX:stop()
        shootSFX = nil
    end

    if state == STATE.SHOOT and p:isOnGround() then
        p.keys.left = false
        p.keys.right = false
        p.speedX = 0
    end

    if hurtTimer >= 0 then
        hurtTimer = hurtTimer + 1

        p.keys.up = false
        p.keys.down = false
        p.keys.left = false
        p.keys.right = false
        p.keys.run = false
        p.keys.altRun = false
        p.keys.jump = false
        p.keys.altJump = false

        if hurtTimer == 48 then
            hurtTimer = -1
            changeState(STATE.IDLE)
        end
    end

    local animData = cursedWart.animData[state]

    animTimer = animTimer + 1
    curFrame = math.floor(animTimer / animData.framespeed) % animData.frames
end

function cursedWart.onTickEndPowerup(p)
end

local function drawPlayer(p, priority, opacity)
    local animData = cursedWart.animData[state]
    local img = cursedWart:getAsset(p.character, cursedWart.playerImages[p.character])
    local size = cursedWart.cellSize

	local shader,uniforms
	local color = Color.white
	if not p.hasStarman then
		if p.data.metalcapPowerupcapTimer then
			shader = metalShader
		elseif p.data.vanishcapPowerupcapTimer then
			shader = vanishShader
		end
	elseif p.hasStarman then
		shader = starShader
		uniforms = {time = lunatime.tick()*2}
	elseif Defines.cheat_shadowmario then
		color = Color.black
	end

    Graphics.drawBox{
        texture = img,

        x = p.x + p.width/2 + cursedWart.textureOffset.x * p.direction,
        y = p.y + p.height - size.y/2 + cursedWart.textureOffset.y,

        width = size.x * p.direction,
        height = size.y,

        sourceX = (animData.frameX - 1) * size.x,
        sourceY = curFrame * size.y,

        sourceWidth = size.x,
        sourceHeight = size.y,

        priority = priority,
        sceneCoords = true,
        centered = true,
        color = Color.white .. opacity,

        shader = shader,
        uniforms = uniforms,
    }
end

function cursedWart.onDrawPowerup(p)
    if p.forcedState ~= 8 and not p:mem(0x142, FIELD_BOOL) and p.deathTimer == 0 then
        local priority = -25
        local info = goalTape.playerInfo[p.idx]

        if info and info.darkness > 0 then
            local priority = (info.pausesGame and 0.5) or -6
            drawPlayer(p, priority, info.darkness)
        end

        if p.forcedState == FORCEDSTATE_PIPE then
            priority = -70
        end

        drawPlayer(p, priority, 1)
    end

    if p.forcedState ~= cp.powerUpForcedState and Graphics.isHudActivated() then
        local fullImg = Graphics.sprites.hardcoded["36-1"].img
        local emptyImg = Graphics.sprites.hardcoded["36-2"].img

        local width = (fullImg.width + 2) * cursedWart.health - 2

        for i = 1, cursedWart.health do
            local img = emptyImg

            if curHealth > 0 and curHealth >= i then
                img = fullImg
            end

            Graphics.drawImageWP(
                img,
                camera.width/2 - width/2 + (i - 1) * (fullImg.width + 2),
                80,
                4.99
            )
        end
    end
end


---------------------
-- Other Functions --
---------------------

function cursedWart.onInitAPI()
    registerEvent(cursedWart, "onPlayerHarm")

    cp = require("customPowerups")
end

function cursedWart.onPlayerHarm(e, p)
    if e.cancelled or health or cp.getCurrentPowerup(p) ~= cursedWart then
        return
    end

    if curHealth > 1 then
        e.cancelled = true

        curHealth = curHealth - 1
        hurtTimer = 0
        shootTimer = 0
        changeState(STATE.HURT)

        p.speedX = cursedWart.knockbackSpeed.x * p.direction
        p.speedY = cursedWart.knockbackSpeed.y
        p:mem(0x140, FIELD_WORD, 150)

        SFX.play(39)
    else
        curHealth = 0
        p:kill()
        Explosion.spawn(p.x + p.width/2, p.y + p.height/2, 3)
    end
end

return cursedWart