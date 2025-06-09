
--[[
				jumpingLui.lua by MrNameless
				
			 A customPowerups script that brings over
			the Jumping Lui from Mario Forever to SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	SleepyVA - Made & provided Jumping Lui sprites for Mario, Luigi, Peach, & Link
	buttersoap_ - Made & provided Jumping Lui sprites for Toad
	Murphmario - Made & provided the sprite for the Jumping Lui NPC
	
	Horikwawa Otane - Made classexpander.lua, which chunks of code from that was used here to draw afterimages of mounts.
	Emral - Made the original afterimages.lua which this script uses a modified version in order to be accurate to Mario Forever (https://www.smbxgame.com/forums/viewtopic.php?t=25809)
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local wasMuted1 = false
local wasMuted2 = false

local jumpingLui = {}

jumpingLui.settings = {
	rngJumpheight = false, -- should the jumpheight be random? (false by default)
	allowAfterImages = true, -- should the player be allowed to emit after images when in midair? (true by default)
	afterImagePriority = -26, -- (requires Emral's afterimages.lua) what priority should the after images be drawn on? (26 by default)
}

jumpingLui.basePowerup = PLAYER_FIRE
jumpingLui.items = {}
jumpingLui.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
jumpingLui.cheats = {"needajumpinglui","lunalui","jumpforjoy","jumpupsuperstar","jumpmenplus","jumpmenx2"}

-- runs when customPowerups is done initializing the library
function jumpingLui.onInitPowerupLib()
	jumpingLui.spritesheets = {
		jumpingLui:registerAsset(CHARACTER_MARIO, "mario-jumpingLui.png"),
		jumpingLui:registerAsset(CHARACTER_LUIGI, "luigi-jumpingLui.png"),
		jumpingLui:registerAsset(CHARACTER_PEACH, "peach-jumpingLui.png"),
		jumpingLui:registerAsset(CHARACTER_TOAD,  "toad-jumpingLui.png"),
		jumpingLui:registerAsset(CHARACTER_LINK,  "link-jumpingLui.png"),
		false,
		jumpingLui:registerAsset(CHARACTER_WARIO, "wario-jumpingLui.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	jumpingLui.iniFiles = {
		jumpingLui:registerAsset(CHARACTER_MARIO, "mario-jumpingLui.ini"),
		jumpingLui:registerAsset(CHARACTER_LUIGI, "luigi-jumpingLui.ini"),
		jumpingLui:registerAsset(CHARACTER_PEACH, "peach-jumpingLui.ini"),
		jumpingLui:registerAsset(CHARACTER_TOAD,  "toad-jumpingLui.ini"),
		jumpingLui:registerAsset(CHARACTER_LINK,  "link-jumpingLui.ini"),
		false,
		jumpingLui:registerAsset(CHARACTER_WARIO, "wario-jumpingLui.ini"),
	}
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	template.gpImages = {
		template:registerAsset(CHARACTER_MARIO, "jumpingLui-groundPound-1.png"),
		template:registerAsset(CHARACTER_LUIGI, "jumpingLui-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- jump heights for mario, luigi, peach, toad, link, ""megaman"", & wario respectively
local jumpheights = {40,45,40,35,40,nil,40}

-- calls in a modified version Emral's afterimages if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=25809)
local afterimages
pcall(function() afterimages = require("afterimages_jumpingLui") end)

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
	local shouldJump = false
	local holdingJump = p.keys.jump or p.keys.altJump
	local tappingJump = p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED
	
	if ((inputCheck == "tap" and tappingJump) or (inputCheck == "hold" and holdingJump))
	and p.mount ~= MOUNT_CLOWNCAR
	and p:mem(0x26,FIELD_WORD) == 0	
	then
		shouldJump = true
	end
		
	if (p.mount ~= 0 and p.keys.altJump == KEYS_PRESSED) or ((isOnGround(p) or forceJump) and shouldJump) then
		Audio.sounds[1].muted = true
		Audio.sounds[33].muted = true
		if allowSpin  -- lessens the jumpheight when spinjumping
		and p.keys.altJump and p.mount == 0
		and p.character ~= CHARACTER_PEACH then 
			finalHeight = jumpheights[p.character] - 10
			p:mem(0x50,FIELD_BOOL, true)
			if playSFX then SFX.play(33) end
		elseif p.mount == 0 then
			finalHeight = jumpheights[p.character]
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

-- adds an after image to whatever mount the player's riding (excluding the clown car lol)
local function addMount(self, x, y, color, width, height, frame, img, sceneCoords, priority,lifetime)
	--Compute frame y coordinate and height, in texture space
	local fy = (frame*height)/img.height;
	local fh = height/img.height;
	--Draw the sprite
	afterimages.addAfterImage{
		vertexCoords = 	{x, y, x + width, y, x + width, y + height, x, y + height},
		textureCoords = {0, fy, 1, fy, 1, fy+fh, 0, fy+fh},
		primitive = Graphics.GL_TRIANGLE_FAN,
		texture = img,
		sceneCoords = sceneCoords,
		priority = priority,
		color = color,
		lifetime = lifetime,
	}
end

function jumpingLui.onInitAPI()
	registerEvent(jumpingLui, "onBlockHit")
	registerEvent(jumpingLui, "onNPCHarm")
	registerEvent(jumpingLui, "onNPCTransform")
end

-- runs once when the powerup gets activated, passes the player
function jumpingLui.onEnable(p)
	local wasMuted1 = Audio.sounds[1].muted
	local wasMuted2 = Audio.sounds[33].muted
	p.data.jumpingLui = {
		luiTimer = 0,
		wasGrounded = true,
		wasMounted = false,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function jumpingLui.onDisable(p)
	p.data.jumpingLui = nil
end

-- runs when the powerup is active, passes the player
function jumpingLui.onTickPowerup(p)
	if not p.data.jumpingLui then return end -- check if the powerup is currenly active
	
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end
	
	if p.forcedState ~= 0 then return end
	local data = p.data.jumpingLui
	
	data.luiTimer = data.luiTimer + 1
	
	-- replaces the default SMBX jump with a replica that allows extended jumpheights
	if Level.winState() == 0 then
		handleJumping(p,true,false,true,"tap")
	end
		
	if p:mem(0x11C,FIELD_WORD) <= 0 and not isOnGround(p) then
		p.speedY = p.speedY + 0.1
	end
end

-- runs when the powerup is active, passes the player
function jumpingLui.onTickEndPowerup(p)
	if not p.data.jumpingLui then return end -- check if the powerup is currenly active
	if p.forcedState ~= 0 then return end
	if isOnGround(p) then return end
	
	local data = p.data.jumpingLui
	
	if not afterimages or not jumpingLui.settings.allowAfterImages then return end
	
	if data.luiTimer % 4 ~= 0 then return end -- only display afterimages every 4 frames
	
	local dir = p.direction
	
	-- handles drawing an afterimage of a boot
	if p.mount == MOUNT_BOOT then
		local mountFrame = p:mem(0x110, FIELD_WORD)
	
		--Flip the direction of the boot if we need to
		if d == 1 and mountFrame < 2 then
			mountFrame = mountFrame + 2
		elseif d == -1 and mountFrame >= 2 then
			mountFrame = mountFrame - 2
		end
		--Draw the boot
		
		-- Fixes an annoying issue regarding peach's sprite peeking out of the bottom of the boot
		local peachOffset = 0
		if p.character == CHARACTER_PEACH then
			peachOffset = 6
		end
		addMount(p, p.x + p.width*0.5 - 16, (p.y + p.height-30) + peachOffset, nil, 32, 32, mountFrame, Graphics.sprites.hardcoded["25-"..p.mountColor].img, true, jumpingLui.settings.afterImagePriority,32)
	-- handles drawing an afterimage of yoshi
	elseif p.mount == MOUNT_YOSHI then -- if ridin
		local bodyframe = p:mem(0x7A, FIELD_WORD)
		local headframe = p:mem(0x72, FIELD_WORD)
		local headoffset = p:mem(0x6E,FIELD_WORD)
					
		--Flip the direction of yoshi's BODY if we need to
		if dir == 1 and bodyframe < 7 then
			bodyframe = bodyframe + 7
		elseif dir == -1 and bodyframe >= 7 then
			bodyframe = bodyframe - 7
		end
				
		--Flip the direction of yoshi's HEAD if we need to
		if dir == 1 and headframe < 5 then
			headframe = headframe + 5
			headoffset = -headoffset - 8
		elseif dir == -1 and headframe >= 5 then
			headframe = headframe - 5
			headoffset = -headoffset - 8
		end
		--Draw Yoshi's body
		addMount(p, p.x - 4, p.y + p:mem(0x78, FIELD_WORD), nil, 32, 32, bodyframe, Graphics.sprites.yoshib[p.mountColor].img, true, jumpingLui.settings.afterImagePriority -.2,32)
		--Draw Yoshi's head
		addMount(p, p.x + headoffset,p.y + p:mem(0x70,FIELD_WORD),nil, 32,32, headframe,Graphics.sprites.yoshit[p.mountColor].img,true, jumpingLui.settings.afterImagePriority -.2,32)
	end
	
	-- draws an afterimage of the player's held NPC
	if p.holdingNPC then
		afterimages.create(p.holdingNPC, 32, Color.black .. 1, false, -30 - 0.1)
	end

	-- draws an afterimage of the player themselves
	if not (p:mem(0x12E,FIELD_BOOL) and p.mount == MOUNT_BOOT) then 
		afterimages.create(p, 32, Color.black .. 1, false, jumpingLui.settings.afterImagePriority -.1) 
	end
end

-- runs when the powerup is active, passes the player
function jumpingLui.onDrawPowerup(p)
	return
end


-- the following chunks of code all refreshes the player's jump replica

function jumpingLui.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "Player" then return end
	if harm ~= 1 and harm ~= 8 then return end
	if cp.getCurrentPowerup(c) ~= jumpingLui or not c.data.jumpingLui then return end 	
	handleJumping(c,false,true,false,"hold")
end

-- check if a player was right above the NPC whenever it was transformed by a jump/sword harmtype
function jumpingLui.onNPCTransform(v,oldID,harm)
	if harm ~= 1 and harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if cp.getCurrentPowerup(p) == jumpingLui and p.data.jumpingLui then
			-- refreshes the player's jump replica
			handleJumping(p,false,true,false,"hold")
		end
	end
end

-- check if a player was right above the noteblock whenever it was hit from above
function jumpingLui.onBlockHit(token,v,upper,p)
	if v.id ~= 55 or not upper then return end
	for _,p in ipairs(Player.getIntersecting(v.x,v.y - 4,v.x + v.width,v.y + v.height)) do  -- refreshes the player's jump replica after hitting a note block
		if cp.getCurrentPowerup(p) == jumpingLui and p.data.jumpingLui then
			handleJumping(p,false,true,true,"hold")
		end
	end
end

return jumpingLui