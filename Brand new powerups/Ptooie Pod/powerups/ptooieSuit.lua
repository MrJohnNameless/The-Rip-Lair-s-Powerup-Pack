
--[[
					Ptooie Suit by MrNameless
				
		A customPowerups script that brings over the Ptooie Suit
			powerup from "Mario Takes A Three" over to SMBX.
			
	CREDITS:
	Marioman2007 & Emral 
		- created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
		- also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)

	Neweegee - Made the original Ptooie Mario & Ptooie powerup sprites used here.
	Mors, Gatete, Cruise Elroy & Neweegee - Developed Mario Takes a Three where the Ptooie Suit originated from (https://mfgg.net/index.php?act=resdb&param=02&c=2&id=36312) 
	
	Sleepy - Helped in ripping the item-holding & swimming sprites & also made the item-pulling & yoshi-riding sprites for this.
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local ptooie = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

ptooie.projectileID = 868
ptooie.forcedStateType = 2 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
ptooie.basePowerup = PLAYER_FIREFLOWER
ptooie.cheats = {"needaptooie","hawktuah","pograhna","plantneutralspecial","spititout","peashooter","middleground","cloudywithachanceofspikeballs","balancingact"}
ptooie.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

ptooie.settings = {
	blowheights = {72,72}, -- what are the blowheights that the player's projectile alternate in reaching? ({72,72} by default)
	spitSpeedX = 3, -- what is the minimum speed will the player's projectile be sent horizontally? (3 by default)
	spitSpeedY = -Defines.npc_grav, -- what is the minimum speed will the player's projectile be sent vertically? (-Defines.npc_grav by default)
	bounceOnHit = false, -- should the player's projectile bounce upward by a speed of -4 upon hitting any npc? (false by default)
	standstillRequirement = false, -- does the player need to be completely still in order to use their projectile, accurate to the Mario Takes a Three? (false by default)
}

-- runs when customPowerups is done initializing the library
function ptooie.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	ptooie.spritesheets = {
		ptooie:registerAsset(CHARACTER_MARIO, "mario-ptooie.png"),
		ptooie:registerAsset(CHARACTER_LUIGI, "luigi-ptooie.png"),
		false, -- ptooie:registerAsset(CHARACTER_PEACH, "peach-ptooie.png"),
		false, -- ptooie:registerAsset(CHARACTER_TOAD,  "toad-ptooie.png"),
		false, -- ptooie:registerAsset(CHARACTER_LINK,  "link-ptooie.png"),
	}
		
	-- needed to align the sprites relative to the player's hurtbox
	ptooie.iniFiles = {
		ptooie:registerAsset(CHARACTER_MARIO, "mario-ptooie.ini"),
		ptooie:registerAsset(CHARACTER_LUIGI, "luigi-ptooie.ini"),
		false, -- ptooie:registerAsset(CHARACTER_PEACH, "peach-ptooie.ini"),
		false, -- ptooie:registerAsset(CHARACTER_TOAD,  "toad-ptooie.ini"),
		false, -- ptooie:registerAsset(CHARACTER_LINK,  "link-ptooie.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the ptooie powerup
	ptooie.gpImages = {
		ptooie:registerAsset(CHARACTER_MARIO, "ptooie-groundPound-1.ini"),
		ptooie:registerAsset(CHARACTER_LUIGI, "ptooie-groundPound-2.ini"),
	}
	--]]
end

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animation = {7,36} -- the animation frames for ducking

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {50, 50, 50, 50, 50}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canShoot(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
		and ((p:mem(0x12E, FIELD_BOOL) and not linkChars[p.character]) or (linkChars[p.character] and p.keys.down)) -- ducking
    )
end

function ptooie.onInitAPI()
	registerEvent(ptooie,"onNPCKill")
end

-- runs once when the powerup gets activated, passes the player
function ptooie.onEnable(p)	
	p.data.ptooieSuit = {
		projectileTimer = 0,
		duckTimer = 0,
		recalc = false,
		blowing = false,
		ballNPC = nil,
		blowheight = RNG.irandomEntry(ptooie.settings.blowheights),
	}
end

-- runs once when the powerup gets deactivated, passes the player
function ptooie.onDisable(p)
	p.data.ptooieSuit = nil
end

function ptooie.onTickPowerup(p) return end

function ptooie.handlePlayer(p) 
	if not p.data.ptooieSuit then return end -- check if the powerup is currenly active
	local data = p.data.ptooieSuit
	local settings = ptooie.settings
	local dir = p.direction
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

	-- doing this in order to fix an annoying oversight where the player is still ""falling"" when standing on an NPC
	local speedY = p.speedY
	if p:mem(0x176,FIELD_WORD) ~= 0 then speedY = 0 end

	data.projectileTimer = math.max(data.projectileTimer - 1, 0) 
	
    if canShoot(p) and Level.endState() == LEVEL_WIN_TYPE_NONE 
	and data.duckTimer <= 0 and data.projectileTimer <= 0 then
		-- spawns the projectile itself
        local v = NPC.spawn(
			ptooie.projectileID,
			p.x + p.width/2 + p.speedX,
			p.y - p.height/1.5 + speedY, p.section, false, true
        )
		v.speedY = -Defines.npc_grav
		v.direction = dir
		v:mem(0x12E, FIELD_WORD, 9999)
		v:mem(0x130, FIELD_WORD, p.idx)
		SFX.play(18)
		
		data.blowing=false
		data.recalc = false
		data.duckTimer = 0
		data.ballNPC = v
        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
		
    elseif canShoot(p) then
		data.duckTimer = data.duckTimer + 1
		-- handles ptooie spike ball
		if data.ballNPC ~= nil and data.ballNPC.isValid then
			local n = data.ballNPC
			n.despawnTimer = math.min(n.despawnTimer,1)
			n.speedX = p.speedX
			n.x = (p.x + p.width/2) - n.width/2 + p.speedX
			
			if (n.y+n.height > p.y-64 and n.speedY > 0) or (n.y+n.height > p.y-data.blowheight and n.speedY < 0) then
				n.speedY = n.speedY - Defines.player_grav - 0.02 + math.min(speedY/2,Defines.npc_grav)
				data.blowing = true
				data.recalc = true
			else
				data.blowing = false
			end
			local maxspeed = NPC.config[ptooie.projectileID].maxspeed
			n.speedY = math.max(math.min(n.speedY,maxspeed - 1),-(maxspeed or 4))
			if data.recalc and not data.blowing then
				data.blowheight = RNG.irandomEntry(settings.blowheights)
				data.recalc = false
			end 
			if (p.speedX ~= 0 and (Defines.levelFreeze or settings.standstillRequirement)) then
				data.ballNPC.speedX = p.speedX
				data.ballNPC.speedY = p.speedY
				data.ballNPC = nil
			elseif (p.keys.left == KEYS_PRESSED and p.direction == -1) or (p.keys.right == KEYS_PRESSED and p.direction == 1) then
				n.speedX = (settings.spitSpeedX * p.direction) + p.speedX/2
				n.speedY = math.min(n.speedY,settings.spitSpeedY) + math.min(speedY/3,0)
				data.ballNPC = nil
			end
		end
	else
		data.duckTimer = 0
		data.ballNPC = nil
	end
end

function ptooie.onTickEndPowerup(p)
	if not p.data.ptooieSuit then return end -- check if the powerup is currently active
	local data = p.data.ptooieSuit
	
	ptooie.handlePlayer(p)
	
    local curFrame = animation[1 + math.floor(data.duckTimer / 16) % #animation] -- sets the frame depending on how much the projectile timer has
    local canPlay = canShoot(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if p:mem(0x12E,FIELD_BOOL) and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

function ptooie.onDrawPowerup(p) return end

function ptooie.onNPCKill(token,v,harm,c)
	for _,p in ipairs(Player.get()) do
		if p.data.ptooieSuit then
			local data = p.data.ptooieSuit
			if data.ballNPC and v == data.ballNPC then
				data.ballNPC = nil
			end
		end
	end
end

return ptooie