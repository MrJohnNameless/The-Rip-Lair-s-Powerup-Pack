
--[[
				astroSuit.lua by MrNameless & SleepyVA
				
			A customPowerups script that adds an orignal powerup
		that gives player higher jumps, the ability to fall slowly or quickly 
		  and the ability to shoot three Astro Suit Lasers at a time.
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	SleepyVA - Provided sprites for Mario, Luigi, Toad
			 - also made improved edits of sprites for Link
	S3K Stage - made the original sprites of Peach with a ponytail which were used here (https://youtu.be/vwAQmpKEWhI)
	David184, Qw2, Terra King - Ripped the laser firing SFX from Terraria which was used here (https://www.sounds-resource.com/pc_computer/terraria/sound/2890/)
	
	Version 3.5.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local astroSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

astroSuit.projectileID = 960
astroSuit.forcedStateType = 2 -- 0 for instant, 1 for flickering, 2 for poof effect
astroSuit.basePowerup = PLAYER_FIRE
astroSuit.items = {}
astroSuit.collectSounds = {
    upgrade = 34,
    reserve = 12,
}
astroSuit.cheats = {"needanastrosuit","needaastrosuit","immoonwalking","houstonwehaveaproblem","onestepforplumberkind","spacecadet", "mspinball", "tickettothemoon", "rogerramjet"}

-- runs when customPowerups is done initializing the library
function astroSuit.onInitPowerupLib()
	astroSuit.spritesheets = {
		astroSuit:registerAsset(CHARACTER_MARIO, "mario-astroSuit.png"),
		astroSuit:registerAsset(CHARACTER_LUIGI, "luigi-astroSuit.png"),
		astroSuit:registerAsset(CHARACTER_PEACH, "peach-astroSuit.png"),
		astroSuit:registerAsset(CHARACTER_TOAD,  "toad-astroSuit.png"),
		astroSuit:registerAsset(CHARACTER_LINK,  "link-astroSuit.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	astroSuit.iniFiles = {
		astroSuit:registerAsset(CHARACTER_MARIO, "mario-astroSuit.ini"),
		astroSuit:registerAsset(CHARACTER_LUIGI, "luigi-astroSuit.ini"),
		astroSuit:registerAsset(CHARACTER_PEACH, "peach-astroSuit.ini"),
		astroSuit:registerAsset(CHARACTER_TOAD,  "toad-astroSuit.ini"),
		astroSuit:registerAsset(CHARACTER_LINK,  "link-astroSuit.ini"),
	}
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	astroSuit.gpImages = {
		astroSuit:registerAsset(CHARACTER_MARIO, "astroSuit-groundPound-1.png"),
		astroSuit:registerAsset(CHARACTER_LUIGI, "astroSuit-groundPound-2.png"),
	}
	--]]
end

astroSuit.settings = {
	projectileSpeed = 8, -- How fast should the projectile move horizontally? (8 by default)
	projectileLifetime = 80, -- How long should the projectile last before automatically being destroyed? (80 by default)
	projectileCap = 3, -- How many projectiles can the player shoot at a time? Setting it to -1 will allow infinite shooting (3 by default)
	projectileHarmType = -1, -- What's the harm type afflicted onto the npc that got hit by the projectile? (-1 (Player Fireball) by default)
	allowSlowfall = true, -- Does the player fall much slower than usual? (true by default)
	allowFastfall = true, -- Is the player allowed to fall much faster when holding down? (true by default) 
	firingSFX = Misc.resolveFile("powerups/laserFire.ogg"),
}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 12, 12}-- the animation frames for shooting a fireball

local jumpheights = {30,35,30,25,30}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

-- calls in MrDoubleA's respawnRooms if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?p=396718)
local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

respawnRooms = respawnRooms or {}

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function handleJumping(p,allowSpin,forceJump,playSFX,inputCheck) -- "replaces" the default SMBX jump with a replica that allows adjustable jumpheight
	if p.deathTimer > 0 then return end
	if not p.keys.jump and not p.keys.altJump then return end
	local wasMuted1 = false
	local wasMuted2 = false
	local shouldJump = false
	local holdingJump = p.keys.jump or p.keys.altJump
	local tappingJump = p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED
	
	if ((inputCheck == "tap" and tappingJump) or (inputCheck == "hold" and holdingJump))
	and p.mount ~= MOUNT_CLOWNCAR
	and p:mem(0x26,FIELD_WORD) == 0	
	then
		shouldJump = true
	end
	
	local finalHeight = jumpheights[p.character]
	if (p.mount ~= 0 and p.keys.altJump == KEYS_PRESSED) or ((isOnGround(p) or forceJump) and shouldJump) then
		Audio.sounds[1].muted = true
		Audio.sounds[33].muted = true
		if allowSpin  -- lessens the jumpheight when spinjumping
		and p.keys.altJump and p.mount == 0
		and p.character ~= CHARACTER_PEACH
		and p.character ~= CHARACTER_LINK then 
			finalHeight = jumpheights[p.character] - 10
			p:mem(0x50,FIELD_BOOL, true)
			if playSFX then SFX.play(33) end
		else
			if playSFX then SFX.play(1) end
		end
		Routine.run(function()
			Routine.skip()
			p:mem(0x11C,FIELD_WORD, finalHeight) -- this handles jumpheights (this trick doesn't affect springs :[ )
			Audio.sounds[1].muted = wasMuted1
			Audio.sounds[33].muted = wasMuted2
		end)
	end
end

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount < 2
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p:mem(0x12E, FIELD_BOOL) or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function astroSuit.onInitAPI()
	registerEvent(astroSuit,"onNPCHarm")
	registerEvent(astroSuit,"onNPCTransform")
	registerEvent(astroSuit,"onNPCKill")
	registerEvent(astroSuit,"onBlockHit")
end

-- runs once when the powerup gets activated, passes the player
function astroSuit.onEnable(p)
	p.data.astroSuit = {
		animTimer = 0,
		ownedLasers = {}
	}
end

-- runs once when the powerup gets deactivated, passes the player
function astroSuit.onDisable(p)
	p.data.astroSuit = nil
end

-- runs when the powerup is active, passes the player
function astroSuit.onTickPowerup(p) 
	if not p.data.astroSuit then return end -- check if the powerup is currenly active
	local data = p.data.astroSuit
	local settings = astroSuit.settings
	
    data.animTimer = math.max(data.animTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
		p:mem(0x160, FIELD_WORD, 5)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 5)
    end
	
	-- replaces the default SMBX jump with a replica that allows extended jumpheights
	if isOnGround(p) or (not isOnGround(p) and p.mount ~= 0) then
		handleJumping(p,true,false,true,"tap")
	end
	
	if p:mem(0x50,FIELD_BOOL) or p.mount ~= 0 then
		for _, n in NPC.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+32+math.max(p.speedY,0)) do
			if n.isValid and not n.isHidden and n.despawnTimer > 0 and NPC.config[n.id].spinjumpsafe then
				local isColliding, isSpinjumping = Colliders.bounce(p, n)
				if isColliding and (isSpinjumping or p.mount ~= 0) then
					handleJumping(p,false,true,false,"hold")
					return
				end
			end
		end
	end
	
	if p.mount ~= MOUNT_CLOWNCAR and p.speedY > 0 and not p.keys.down and astroSuit.settings.allowSlowfall then
		p.speedY = math.min(p.speedY ,4.5)
	elseif p.mount ~= MOUNT_CLOWNCAR and not isOnGround(p) and p.keys.down and astroSuit.settings.allowFastfall then
		p.speedY = math.min(p.speedY + 0.4,Defines.gravity)
	end
	
	local flamethrowerActive = Cheats.get("flamethrower").active
	
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if (#data.ownedLasers >= settings.projectileCap and settings.projectileCap >= 0 and not flamethrowerActive) then return end
	
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive and lunatime.tick() % 6 == 0 then 
		tryingToShoot = true
	end
	
    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end -- if spinjumping while on the ground
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (tryingToShoot and not p:mem(0x50, FIELD_BOOL) and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			astroSuit.projectileID,
			p.x + p.width/2 + (p.width/2 + 16) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
			
		if linkChars[p.character] then -- handles shooting as link/snake/samus
			if not p:mem(0x12E,FIELD_BOOL) then -- if ducking, have the npc not rise higher
				v.y = v.y - 8
			end
			v.x = v.x + (8 * dir) -- adjust the npc a bit to look like it's being shot out of link's sword
		end
		v.speedX = (settings.projectileSpeed + p.speedX/3.5) * dir
		v.data.totalLife = settings.projectileLifetime -- sets how long the laser should live
		v.data.variant = p.character -- changes the sprite of the laser based on the character shooting it
		table.insert(data.ownedLasers,v) -- makes the player "own" the laser they shot
		
        data.animTimer = 25
		SFX.play(settings.firingSFX)
    end
end

function astroSuit.onTickEndPowerup(p)
	if not p.data.astroSuit then return end
	local data = p.data.astroSuit

	local curFrame = animFrames[math.min(1 + math.floor(data.animTimer / 5),#animFrames)] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.animTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

-- the following chunks of code all refreshes the player's jump replica
function astroSuit.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "Player" then return end
	if harm ~= 1 or harm ~= 8 then return end
	if cp.getCurrentPowerup(c) ~= astroSuit or not c.data.astroSuit then return end 	
	handleJumping(c,false,true,false,"hold")
end

-- check if a player was right above the NPC whenever it was transformed
function astroSuit.onNPCTransform(v,oldID,harm)
	if harm ~= 1 or harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if cp.getCurrentPowerup(p) == astroSuit and p.data.astroSuit then
			-- refreshes the player's jump replica
			handleJumping(p,false,true,false,"hold")
		end
	end
end

-- check if a player was right above the noteblock whenever it was hit from above
function astroSuit.onBlockHit(token,v,above,p)
	if v.id ~= 55 or not above then return end
	for _,p in ipairs(Player.getIntersecting(v.x,v.y - 4,v.x + v.width,v.y + v.height)) do  -- refreshes the player's jump replica after hitting a note block
		if cp.getCurrentPowerup(p) == astroSuit and p.data.astroSuit then
			handleJumping(p,false,true,true,"hold")
		end
	end
end

function astroSuit.onNPCKill(token,v,harm,c)
	if v.id ~= astroSuit.projectileID then return end
	for _,p in ipairs(Player.get()) do
		if cp.getCurrentPowerup(p) == astroSuit and p.data.astroSuit then
			local data = p.data.astroSuit
			for i,n in ipairs(data.ownedLasers) do
				if n.isValid and n == v then
					table.remove(data.ownedLasers, i) -- makes the player "disown" the laser they shot, allowing them to shoot more
					break
				end
			end
		end
	end
end

-- (requires MrDoubleA's respawnRooms) runs once upon quick restarting
function respawnRooms.onPreReset(fromRespawn)
    for _, p in ipairs(Player.get()) do
		astroSuit.onDisable(p)
    end
end

return astroSuit