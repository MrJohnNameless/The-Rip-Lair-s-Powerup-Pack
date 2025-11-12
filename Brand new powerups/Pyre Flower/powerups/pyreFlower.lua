local pyre = {}

pyre.projectileID = 799
pyre.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
pyre.basePowerup = PLAYER_FIREFLOWER
pyre.cheats = {"needapyreflower","thebiggerthebetter"}
pyre.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
pyre.settings = {
	exampleSetting = true,
	-- put your own settings here!
}

-- runs when customPowerups is done initializing the library
function pyre.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	pyre.spritesheets = {
		pyre:registerAsset(CHARACTER_MARIO, "mario-pyre.png"),
		pyre:registerAsset(CHARACTER_LUIGI, "luigi-pyre.png"),
		pyre:registerAsset(CHARACTER_PEACH, "peach-pyre.png"),
		pyre:registerAsset(CHARACTER_TOAD,  "toad-pyre.png"),
		pyre:registerAsset(CHARACTER_LINK,  "link-pyre.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	pyre.iniFiles = {
		pyre:registerAsset(CHARACTER_MARIO, "mario-pyre.ini"),
		pyre:registerAsset(CHARACTER_LUIGI, "luigi-pyre.ini"),
		pyre:registerAsset(CHARACTER_PEACH, "peach-pyre.ini"),
		pyre:registerAsset(CHARACTER_TOAD,  "toad-pyre.ini"),
		pyre:registerAsset(CHARACTER_LINK,  "link-pyre.ini"),
	}
	
	pyre.gpImages = {
		pyre:registerAsset(CHARACTER_MARIO, "pyre-groundPound-1.png"),
		pyre:registerAsset(CHARACTER_LUIGI, "pyre-groundPound-2.png"),
	}
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {70, 75, 80, 75, 80}

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
        and (not p.isDucking or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function pyre.onInitAPI()
	-- register your events here!
	--registerEvent(pyre,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function pyre.onEnable(p)	
	p.data.pyre = {
		lastDirection = p.direction * -1, -- don't remove this unless you know what you're doing
		
		-- put your own values here!
		exampleValue = 1,
	}
	p:mem(0x162, FIELD_WORD,5) -- prevents link from accidentally shooting a base projectile when getting the powerup via a sword
end

-- runs once when the powerup gets deactivated, passes the player
function pyre.onDisable(p)	
	p.data.pyre = nil
end

-- runs when the powerup is active, passes the player
function pyre.onTickPowerup(p) 
	if not p.data.pyre then return end
	local data = p.data.pyre
	
	if not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end
	if p.isSpinJumping and p:isOnGround() then return end
	 
	if linkChars[p.character] then
		p:mem(0x162,FIELD_WORD,math.max(p:mem(0x162,FIELD_WORD),2))
		if p:mem(0x162,FIELD_WORD) > 2 then return end
	else
		if p:mem(0x160, FIELD_WORD) > 0 then return end
	end

	local flamethrowerActive = Cheats.get("flamethrower").active
	local tryingToShoot = (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED or p.isSpinJumping) 
	
	if (p.keys.run == KEYS_DOWN) and flamethrowerActive then 
		tryingToShoot = true
	end
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if (tryingToShoot and not linkChars[p.character]) or p:mem(0x14, FIELD_WORD) == 2 then
        local dir = p.direction
		
		-- spawns the projectile itself
        local v = NPC.spawn(
			pyre.projectileID,
			p.x + p.width/2 + (p.width/2) * dir + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		v.direction = dir
		v.ai1 = p.character - 1
		v.ai2 = math.abs(p.speedX/3.5)
		
		-- handles shooting as link/snake/samus
		if linkChars[p.character] then 
			-- shoot less higher when ducking
			if p.isDucking then
				v.speedY = -2
			else
				v.speedY = -5
			end
			v.x = v.x + (16 * dir)
			p:mem(0x162, FIELD_WORD,projectileTimerMax[p.character] + 2)
			SFX.play(82)
			if flamethrowerActive then
				p:mem(0x162, FIELD_WORD,2)
			end
			return
		end
		-- handles making the projectile be held if the player is a SMB2 character & pressed altRun 
		if smb2Chars[p.character] and p.holdingNPC == nil and p.keys.altRun then 
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
		else -- handles normal shooting
			if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
				local speedYMod = p.speedY * 0.1 -- adds extra vertical speed depending on how fast you were going vertically
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				v.speedY = -4 + speedYMod
			else
				v.speedY = 4
			end
			p:mem(0x118, FIELD_FLOAT,110) -- set the player to do the shooting animation
		end
		p:mem(0x160, FIELD_WORD,projectileTimerMax[p.character])
		SFX.play(18)

		if flamethrowerActive then
			p:mem(0x160, FIELD_WORD,30)
		end
    end
end

function pyre.onTickEndPowerup(p)
	if not p.data.pyre then return end
	local data = p.data.pyre
	
	if not p.isSpinJumping then
		data.lastDirection = p.direction * -1
	end
	p:mem(0x54,FIELD_WORD,data.lastDirection) -- prevents a base powerup's projectile from shooting while spinjumping
	
	-- put your own code here!
	
end

function pyre.onDrawPowerup(p)
	if not p.data.pyre then return end
	local data = p.data.pyre
	-- put your own code here!
end

-- handles drawing the powerup when the player is in the overworld
function pyre.onDrawPowerupOverworld(p)
	-- put your own code here!
end

return pyre