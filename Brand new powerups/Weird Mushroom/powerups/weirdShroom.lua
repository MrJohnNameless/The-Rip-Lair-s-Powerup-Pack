--[[
			weirdShroom.lua by DeviousQuacks23
				
		       A customPowerups script that brings over
			the Weird Mushroom from SMM to SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)

	MrNameless - Made the Jumping Lui that this powerup is based on
	MegaDood - Made the SFX for this powerup
	Buttercarsen - Made the player sprites
	Linkys4Mario - Made the powerup sprite	
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local weirdShroom = {}

weirdShroom.basePowerup = PLAYER_FIRE
weirdShroom.items = {}
weirdShroom.collectSounds = {
    upgrade = Misc.resolveFile("powerups/weirdShroom.ogg"),
    reserve = 12,
}
weirdShroom.cheats = {"needaweirdmushroom","needaweirdshroom","myeyes","theseediblesaintsh","thisisawkward","hehasnograce","lanky"}

-- runs when customPowerups is done initializing the library
function weirdShroom.onInitPowerupLib()
	weirdShroom.spritesheets = {
		weirdShroom:registerAsset(CHARACTER_MARIO, "weird-mario.png"),
		weirdShroom:registerAsset(CHARACTER_LUIGI, "weird-luigi.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	weirdShroom.iniFiles = {
		weirdShroom:registerAsset(CHARACTER_MARIO, "weird-mario.ini"),
		weirdShroom:registerAsset(CHARACTER_LUIGI, "weird-luigi.ini"),
	}
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- jump heights for mario, luigi, peach, toad, link, ""megaman"", & wario respectively
local jumpheights = {40,45,40,35,40,nil,40}

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
	if not p.keys.jump and not p.keys.altJump then return end
	
	local wasMuted1 = Audio.sounds[1].muted
	local wasMuted2 = Audio.sounds[33].muted
	
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
		and not linkChars[p.character] then 
			finalHeight = jumpheights[p.character] - 10
			p:mem(0x50,FIELD_BOOL, true)
			if playSFX then SFX.play(Misc.resolveFile("powerups/weirdSpinjump.ogg")) end
		else
			if playSFX then SFX.play(Misc.resolveFile("powerups/weirdJump.ogg")) end
		end
		Routine.run(function()
			Routine.skip()
			p:mem(0x11C,FIELD_WORD, finalHeight) -- this handles jumpheights (this trick doesn't affect springs :[ )
			Audio.sounds[1].muted = wasMuted1
			Audio.sounds[33].muted = wasMuted2
		end)
	end
end

function weirdShroom.onInitAPI()
	registerEvent(weirdShroom, "onNPCHarm")
	registerEvent(weirdShroom, "onNPCTransform")
	registerEvent(weirdShroom, "onBlockHit")
end

-- runs once when the powerup gets activated, passes the player
function weirdShroom.onEnable(p)
	p.data.weirdShroom = {}
end

-- runs once when the powerup gets deactivated, passes the player
function weirdShroom.onDisable(p)
	p.data.weirdShroom = nil
end

-- runs when the powerup is active, passes the player
function weirdShroom.onTickPowerup(p)
	if not p.data.weirdShroom then return end -- check if the powerup is currenly active
	
    	if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        	p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    	end
	
	if p.forcedState ~= 0 then return end
	local data = p.data.weirdShroom
	
	if p:mem(0x11C,FIELD_WORD) <= 0 and p.forcedState == 0 and not p:mem(0x36,FIELD_BOOL) 
	and not p:mem(0x0C,FIELD_BOOL) and p.speedY <= -Defines.player_grav then
		p.speedY = p.speedY + 0.1
	end
	
	-- replaces the default SMBX jump with a replica that allows extended jumpheights
	if isOnGround(p) or (not isOnGround(p) and p.mount ~= 0) then
		handleJumping(p,true,false,true,"tap")
	end

	if not p:mem(0x50,FIELD_BOOL) and p.mount == 0 then return end
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

-- the following chunks of code all refreshes the player's jump replica

function weirdShroom.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "Player" then return end
	if harm ~= 1 and harm ~= 8 then return end
	if cp.getCurrentPowerup(c) ~= weirdShroom or not c.data.weirdShroom then return end 	
	handleJumping(c,false,true,false,"hold")
end

-- check if a player was right above the NPC whenever it was transformed by a jump/sword harmtype
function weirdShroom.onNPCTransform(v,oldID,harm)
	if harm ~= 1 and harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if cp.getCurrentPowerup(p) == weirdShroom and p.data.weirdShroom then
			handleJumping(p,false,true,false,"hold")
		end
	end
end

-- check if a player was right above the noteblock whenever it was hit from above
function weirdShroom.onBlockHit(token,v,upper,p)
	if v.id ~= 55 or not upper then return end
	for _,p in ipairs(Player.getIntersecting(v.x,v.y - 4,v.x + v.width,v.y + v.height)) do  -- refreshes the player's jump replica after hitting a note block
		if cp.getCurrentPowerup(p) == weirdShroom and p.data.weirdShroom then
			handleJumping(p,false,true,true,"hold")
		end
	end
end

return weirdShroom