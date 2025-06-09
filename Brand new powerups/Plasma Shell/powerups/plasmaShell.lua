local plasmaShell = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "iniFiles",
-- "cheats", "registerAsset", "getAsset", "pathFormat", "costumePathFormat", "forcedStateType"

-- everything except "name", "id", "registerAsset" and "getAsset" can be safely modified


plasmaShell.projectileID = 880
plasmaShell.basePowerup = PLAYER_FIREFLOWER


function plasmaShell.onInitPowerupLib()
    plasmaShell.spritesheets = {
        plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-mario.png"),
        plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-luigi.png"),
        plasmaShell:registerAsset(CHARACTER_PEACH, "plasmaShell-toad.png"),	-- placeholder
        plasmaShell:registerAsset(CHARACTER_TOAD,  "plasmaShell-toad.png"),
    }

    plasmaShell.iniFiles = {
        plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-mario.ini"),
        plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-luigi.ini"),
        plasmaShell:registerAsset(CHARACTER_PEACH, "plasmaShell-toad.ini"),	-- placeholder
        plasmaShell:registerAsset(CHARACTER_TOAD,  "plasmaShell-toad.ini"),
    }

    plasmaShell.gpImages = {
        --plasmaShell:registerAsset(CHARACTER_MARIO, "plasmaShell-groundPound-1.png"),
        --plasmaShell:registerAsset(CHARACTER_LUIGI, "plasmaShell-groundPound-2.png"),
    }
end


local animFrames = {1, 1, 1, 13, 13, 13, -1, -1 , -1, 15, 15, 15, 11, 11, 12, 12}
local projectileTimerMax = {50, 50, 60, 40, 40}
local projectileTimer = {}

local GP
pcall(function() GP = require("GroundPound") end)

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
		and not p:mem(0x50,FIELD_BOOL)	-- spinjumping
        and not p:mem(0x12E, FIELD_BOOL) -- ducking
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function plasmaShell.onEnable(p)
    projectileTimer[p.idx] = 0
end

function plasmaShell.onDisable(p)
end

function plasmaShell.onTickPowerup(p)
    projectileTimer[p.idx] = math.max(projectileTimer[p.idx] - 1, 0)
    
    if p.mount < 2 then
        p:mem(0x160, FIELD_WORD, 2)
    end

    if projectileTimer[p.idx] > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end


    if p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED then		-- handles throwing
	
		local dir = p.direction
		
		p.speedY = math.min(-3,p.speedY)
		local v = NPC.spawn(
			plasmaShell.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
		)
		
		if p.keys.up then
			local speedYMod = p.speedY * 0.1
			if p.standingNPC then
				speedYMod = p.standingNPC.speedY * 0.1
			end
			v.speedY = -9 + speedYMod
		end
		
		v.ai1 = p.character
		if p.keys.altRun == KEYS_PRESSED then	-- if altRun was pressed, the player shall immediately explode upwards, starting a spinjump
			v.x = p.x + p.width * 0.5 - v.width * 0.5
			v.y = p.y + p.height * 0,5 - v.height * 0.5
			v:kill()										-- makes the shell immediately explode
			p.speedY = math.min(-10,p.speedY)				-- bounce the player up
			
			p:mem(0x18,FIELD_BOOL,false)					-- no hovering for Peach after bouncing up
			p:mem(0x1C,FIELD_WORD,0)						-- stop hovering when bouncing up
			p:mem(0x11C,FIELD_WORD,0)						-- stop jumping
			
			if p.character ~= 3 and p.character ~= 5 then	-- make characters spinjump (not peach and Link since they usually can't)
				p:mem(0x50,FIELD_BOOL,true)
			end
		end
		v.speedX = NPC.config[v.id].thrownSpeed * dir + p.speedX/3.5
		v:mem(0x156, FIELD_WORD, 32)	-- I frames
	

        SFX.play(18)
        projectileTimer[p.idx] = projectileTimerMax[p.character]
		
	end
end

function plasmaShell.onTickEndPowerup(p)
    local curFrame = animFrames[projectileTimerMax[p.character] - projectileTimer[p.idx]]
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL)

    if projectileTimer[p.idx] > 0 and canPlay and curFrame then
        p:setFrame(curFrame)
    end
end

function plasmaShell.onDrawPowerup(p)
    --Text.print(plasmaShell.name,100,100)
end

function respawnRooms.onPreReset(fromRespawn)
    for _, p in ipairs(Player.get()) do
	    projectileTimer[p.idx] = 0
    end
end

return plasmaShell