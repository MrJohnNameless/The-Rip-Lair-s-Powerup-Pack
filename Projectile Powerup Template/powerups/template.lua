
--[[
		Projectile Powerup template by MrNameless & Marioman2007
				
			A customPowerups template script that helps to
		streamline the process of making projectile throwing powerups
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
						 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	Version 3.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local template = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

template.projectileID = 13
template.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
template.basePowerup = PLAYER_FIREFLOWER
template.cheats = {"needatemplate","put-your-own","cheat-names-here!"}
template.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
template.settings = {
	exampleSetting = true,
	-- put your own settings here!
}

-- runs when customPowerups is done initializing the library
function template.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	template.spritesheets = {
		template:registerAsset(CHARACTER_MARIO, "mario-template.png"),
		template:registerAsset(CHARACTER_LUIGI, "luigi-template.png"),
		template:registerAsset(CHARACTER_PEACH, "peach-template.png"),
		template:registerAsset(CHARACTER_TOAD,  "toad-template.png"),
		template:registerAsset(CHARACTER_LINK,  "link-template.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	template.iniFiles = {
		template:registerAsset(CHARACTER_MARIO, "mario-template.ini"),
		template:registerAsset(CHARACTER_LUIGI, "luigi-template.ini"),
		template:registerAsset(CHARACTER_PEACH, "peach-template.ini"),
		template:registerAsset(CHARACTER_TOAD,  "toad-template.ini"),
		template:registerAsset(CHARACTER_LINK,  "link-template.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	template.gpImages = {
		template:registerAsset(CHARACTER_MARIO, "template-groundPound-1.png"),
		template:registerAsset(CHARACTER_LUIGI, "template-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {11, 11, 11, 11, 12, 12, 12, 12} -- the animation frames for shooting a fireball

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and (p.mount == 0 or p.mount == MOUNT_BOOT)
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

function template.onInitAPI()
	-- register your events here!
	--registerEvent(template,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function template.onEnable(p)	
	p.data.template = {
		projectileTimer = 0, -- don't remove this unless you know what you're doing
		
		-- put your own values here!
		exampleValue = 1,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function template.onDisable(p)	
	p.data.template = nil
end

-- runs when the powerup is active, passes the player
function template.onTickPowerup(p) 
	if not p.data.template then return end
	local data = p.data.template
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
	-- disables shooting the projectile of the respective basegame powerup used
    if p.mount < 2 and not linkChars[p.character] then 
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then
		p:mem(0x162, FIELD_WORD, 2)
    end

   if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end
	
	-- handles shooting the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p:mem(0x50, FIELD_BOOL)) and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			template.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		
		-- handles projectile shooting while spinjumping
		if p:mem(0x50, FIELD_BOOL) and p.holdingNPC == nil then
			-- put your own code here!
		end
		
		-- handles making the projectile be held if the player pressed altRun & is a SMB2 character
		if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			SFX.play(18)
			
			-- put your own code here!
			
		elseif linkChars[p.character] then -- handles shooting as link/snake/samus
			if p:mem(0x12E,FIELD_BOOL) then -- if ducking, have the npc not rise higher
				v.speedY = -2
			else
				v.speedY = -5
			end
			v.x = v.x + (16 * dir) -- adjust the npc a bit to look like it's being shot out of link's sword
			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
			
			-- put your own code here!
			
			SFX.play(82)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -6 + speedYMod
			else
				v.speedY = -4
			end
			
			v.isProjectile = true
			v.direction = dir
			v.speedX = ((NPC.config[v.id].speed + 1) + p.speedX/3.5) * dir
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			
			-- put your own code here!
			
			SFX.play(18)
		end
        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
end

function template.onTickEndPowerup(p)
	if not p.data.template then return end
	
	local data = p.data.template
	
	-- put your own code here!
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and p.mount == 0 and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

function template.onDrawPowerup(p)
	if not p.data.template then return end
	local data = p.data.template
	-- put your own code here!
end

-- handles drawing the powerup when the player is in the overworld
function template.onDrawPowerupOverworld(p)
	-- put your own code here!
end

return template