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
	
	Version 2.5.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local jumper = require("powerups/customJumps")

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

-- jump heights for mario, luigi, peach, toad, & link respectively
local jumpheights = {35,40,35,30,35}

local function handleJumpSFX(p,allowSpinjumpSFX)
	local wasMuted1 = Audio.sounds[1].muted
	local wasMuted2 = Audio.sounds[33].muted

	Routine.run(function()
		if not p.data.weirdShroom or not p.data.weirdShroom.wasGrounded then return end
		Audio.sounds[1].muted = true
		Audio.sounds[33].muted = true
		Routine.skip()
		if p:mem(0x11C,FIELD_WORD) > 0 then
			if p.isSpinJumping and allowSpinjumpSFX then
				SFX.play(Misc.resolveFile("powerups/weirdSpinjump.ogg")) 
			else 
				SFX.play(Misc.resolveFile("powerups/weirdJump.ogg")) 
			end
		end
		Audio.sounds[1].muted = wasMuted1
		Audio.sounds[33].muted = wasMuted2
	end)
end

-- runs once when the powerup gets activated, passes the player
function weirdShroom.onEnable(p)
	jumper.registerPowerup(cp.getCurrentName(p),jumpheights)
	p.data.weirdShroom = {
		wasGrounded = false,
		jumpAnimTimer = 0,
	}
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
	
	if jumper.isOnGround(p) or (p.mount ~= 0 and p.keys.altJump) then
		p.data.weirdShroom.wasGrounded = true
	end
	
	if p.deathTimer == 0 and p.forcedState == 0 and p.grabTopTimer == 0 and (not p:isUnderwater())
	and p.data.weirdShroom.wasGrounded and (p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED) 
	then
		handleJumpSFX(p,true)
		p.data.weirdShroom.wasGrounded = false
	end

	if p.forcedState ~= 0 then return end
	
	if not p:mem(0x36,FIELD_BOOL) and not p:mem(0x0C,FIELD_BOOL) then
		if p:mem(0x11C,FIELD_WORD) <= 0 and p.speedY > 0 then
			p.speedY = p.speedY - (Defines.player_grav * 0.65)
		end

		if p:mem(0x11C,FIELD_WORD) == 1 and p.speedY < 0 and not p.isSpinJumping then
			SFX.play(Misc.resolveFile("powerups/weirdScuttle.ogg")) 
		end
	end
end

function weirdShroom.onDrawPowerup(p)
	if not p.data.weirdShroom then return end -- check if the powerup is currenly active

	if p:mem(0x11C,FIELD_WORD) > 0 and not p.isSpinJumping and p.speedY < 0 and p.frame == 4 then
		p.data.jumpAnimTimer = p.data.jumpAnimTimer + 1
		p.frame = ({4, 36, 46})[1 + math.floor(p.data.jumpAnimTimer / 3) % 3]
	else
		p.data.jumpAnimTimer = 0
	end
end

return weirdShroom