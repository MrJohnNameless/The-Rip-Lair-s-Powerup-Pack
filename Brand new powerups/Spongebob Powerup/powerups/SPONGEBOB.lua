--[[
			Spongebob Powerup by MrNameless & SPONGEBOB
				
		A customPowerups script that adds the hit character Spongebob
			from the hit show "Spongebob Squarepants™" into SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	SuperSledgeBro - made the underwear mario sprites which were used as a base for the sprites (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=36601)
	DeltomX3 - made the Krabby Patty powerup sprite used for this powerup (https://www.youtube.com/@deltomX3)
	SleepyVA - helped with making the sprite of the hydrodynamic spatula used here.
	pmf_anon - made the original bubble blowing sprite from the SMB3 bubble flower mario which was used here (https://discord.com/channels/139415900288843776/834833125317672990/1198981130666397737)
	Fair Play Labs - made the original SFX from Nickelodeon All Star Brawl 2 which was ripped for this powerup (https://store.steampowered.com/app/2017080/Nickelodeon_AllStar_Brawl_2/) 
	ProSounds - provided the Spongebob laughing SFX used when collecting the powerup (https://www.youtube.com/watch?v=_gIWQr-bIlU)
	Mr. C - ripped the sprites of the Spongebob NPC used here (https://www.spriters-resource.com/game_boy_advance/spongebobsquarepantsthemovie/sheet/29746/)
	SPONGEBOB - SPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOBSPONGEBOB
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local playerBuffer = Graphics.CaptureBuffer(100, 100)

local spunchbop = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

spunchbop.projectileID = 1000
spunchbop.forcedStateType = 1 -- 0 for instant, 2 for normal/flickering, 3 for poof/raccoon
spunchbop.basePowerup = PLAYER_FIREFLOWER
spunchbop.cheats = {"needaspongebob","needakrabbypatty","needaspingebill","imspongebob","imready","itsthebestdayever","youaskedforit","62cents"}
spunchbop.settings = {
	maxCharge = 400, -- how much is the player able to charge their abilities (400 by default)
	fishbowlSpeedcap = 9, -- what is the maximum speed the player can reach? (9 by default)
}


-- runs when customPowerups is done initializing the library
function spunchbop.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	spunchbop.spritesheets = {
		spunchbop:registerAsset(CHARACTER_MARIO, "mario-SPONGEBOB.png"),
		--spunchbop:registerAsset(CHARACTER_LUIGI, "luigi-template.png"),
		--spunchbop:registerAsset(CHARACTER_PEACH, "peach-template.png"),
		--spunchbop:registerAsset(CHARACTER_TOAD,  "toad-template.png"),
		--spunchbop:registerAsset(CHARACTER_LINK,  "link-template.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	spunchbop.iniFiles = {
		spunchbop:registerAsset(CHARACTER_MARIO, "mario-SPONGEBOB.ini"),
		--spunchbop:registerAsset(CHARACTER_LUIGI, "luigi-template.ini"),
		--spunchbop:registerAsset(CHARACTER_PEACH, "peach-template.ini"),
		--spunchbop:registerAsset(CHARACTER_TOAD,  "toad-template.ini"),
		--spunchbop:registerAsset(CHARACTER_LINK,  "link-template.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the spunchbop powerup
	spunchbop.gpImages = {
		spunchbop:registerAsset(CHARACTER_MARIO, "template-groundPound-1.ini"),
		spunchbop:registerAsset(CHARACTER_LUIGI, "template-groundPound-2.ini"),
	}
	--]]
end

local STATE_NORMAL = 0
local STATE_BUBBLE = 1
local STATE_SPATULA = 2
local STATE_FISHBOWL = 3

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

-- calls in Emral's afterimages if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=25809)
local afterimages
pcall(function() afterimages = require("afterimages") end)

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p.standingNPC -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or p:mem(0x36,FIELD_BOOL) -- is underwater
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function unOccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and not p:mem(0x50,FIELD_BOOL) -- spinjumping
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function getPlayerSide(p)
	local side
	if p.direction == DIR_LEFT then
		side = p.x -- sets the coord on the left edge of the player's hurtbox
	elseif p.direction == DIR_RIGHT then 
		side = p.x + p.width -- sets the coord on the right edge of the player's hurtbox
	end
	return side
end

-- handles stopping the charge SFX
local function stopSFX(sfx)
	if not sfx then return end
	if not sfx.isValid or not sfx:isplaying() then return end
	sfx:stop()
end

local function handleHitbox(p,left,right,top,bottom,hitboxWidth,canCombo)
	if not p.data.spongebob then return end
	local data = p.data.spongebob

	if p.direction == -1 then
		left = left - hitboxWidth + math.min(p.speedX,0)
	else
		right = right + hitboxWidth + math.max(p.speedX,0)
	end
	
	local hittedSomething = false
	-- handles hitting blocks
	for _,block in Block.iterateIntersecting(left, top, right, bottom) do 
	-- If the block should be broken, destroy it
		if (not block.isHidden and not block:mem(0x5A, FIELD_BOOL)) and not Block.LAVA_MAP[block.id] and not Block.PLAYER_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
			if Block.MEGA_SMASH_MAP[block.id] then
				if block.contentID > 0 then
					block:hit(false, p)
				else
					block:remove(true)
				end
			elseif Block.MEGA_HIT_MAP[block.id] or (Block.SOLID_MAP[block.id] and not Block.SLOPE_MAP[block.id]) then
				block:hit(false, p)
			end
		end
	end
	
	-- handles hitting NPCs
	for _, npc in NPC.iterateIntersecting(left, top, right, bottom) do
		if (not npc.friendly) and npc.despawnTimer > 0 and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 then
			if NPC.COLLECTIBLE_MAP[npc.id] and not NPC.POWERUP_MAP[npc.id] and npc:mem(0x14E,FIELD_WORD) == 0 then -- lets the hammer collect coins
				npc:collect(p)
			elseif NPC.HITTABLE_MAP[npc.id] then
				if canCombo then -- handles incrementing the combo score
					local oldScore = NPC.config[npc.id].score
					NPC.config[npc.id].score = 2 + data.attackCombo
					npc:harm(3)
					NPC.config[npc.id].score = oldScore
					data.attackCombo = math.min(data.attackCombo + 1, 8)
				else
					npc:harm(3)
				end
			end
		end
	end
end 

function spunchbop.onInitAPI()
	-- register your events here!
	--registerEvent(spunchbop,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function spunchbop.onEnable(p)	
	p.data.spongebob = {
		projectileTimer = 0, -- don't remove this
		-- put your own values here!
		state = STATE_NORMAL,
		fishbowlSprite = {},
		spatulaSprite = Sprite{
			texture = Graphics.loadImageResolved("powerups/hydroSpatula.png"),
			pivot = Sprite.align.BOTTOM,
			frames = 2,
			x = getPlayerSide(p) + (p.width * p.direction),
			y = p.y + p.height * 0.5,
		},
		bubbleSprite = Sprite{
			texture = Graphics.sprites.npc[spunchbop.projectileID].img,
			pivot = Sprite.align.CENTER,
			frames = 2,
			x = getPlayerSide(p) + (p.width * p.direction),
			y = p.y + p.height * 0.5,
		},
		chargeSFX = SFX.play("powerups/nasb2charge.ogg",0),--SFX.create{sound = Misc.resolveSoundFile("powerups/nasb2charge.ogg"),
		canUseFishbowl = true,
		canUseSpatula = true,
		actionCooldown = 0,
		attackCombo = 0,
		fishbowlCharge = 0,
		fishbowlTimer = 0,
		fishbowlDuration = 0,
		fishbowlScale = 0,
		spatulaCharge = 0,
		spatulaScale = 0,
		spatulaTimer = 0,
		spatulaDuration = 0,
		bubbleCharge = 0,
		bubbleTimer = 0,

	}
	for i = 1,2,1 do 
		p.data.spongebob.fishbowlSprite[i] = Sprite{
			texture = Graphics.loadImageResolved("powerups/fishbowl-"..p.character..".png"),
			pivot = Sprite.align.CENTER,
			frames = 2,
			x = getPlayerSide(p) + (p.width * p.direction),
			y = p.y + p.height * 0.5,
		}
	end
	stopSFX(p.data.spongebob.chargeSFX)
	if lunatime.tick() > 1 then
		SFX.play("powerups/spongebob-laugh.ogg")
	end
end

-- runs once when the powerup gets deactivated, passes the player
function spunchbop.onDisable(p)	
	stopSFX(p.data.spongebob.chargeSFX)
	p.data.spongebob = nil
end

-- runs when the powerup is active, passes the player
function spunchbop.onTickPowerup(p) 
	if not p.data.spongebob then return end -- check if the powerup is currenly active
	local data = p.data.spongebob
	local settings = spunchbop.settings
	data.actionCooldown = math.max(data.actionCooldown - 1, 0)
	
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

	if not unOccupied(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then 
		data.state = STATE_NORMAL
		data.attackCombo = 0
		data.fishbowlCharge = 0
		data.fishbowlTimer = 0
		data.fishbowlSprite[1].rotation = 0
		p:mem(0x12E,FIELD_WORD,0) -- keeps the player ducked
		
		data.spatulaCharge = 0
		data.spatulaTimer = 0
		
		data.bubbleCharge = 0
		data.bubbleTimer = 0
		data.actionCooldown = 5
		stopSFX(data.chargeSFX)
	end
	
	if isOnGround(p) then
		data.canUseFishbowl = true
		data.canUseSpatula = true
	end
	
	local charge = 0
	
	data.SpongebobStanding = false
	
	for _,n in ipairs(NPC.get()) do
		if (p.standingNPC ~= nil and p.standingNPC.idx == n.idx) and NPC.config[n.id].grabtop then
			data.SpongebobStanding = true
		end
	end
	
	------------ FISHBOWL CHARGING ------------
	if not data.isHoldingRun and data.actionCooldown <= 0 and data.fishbowlCharge < settings.maxCharge
	and data.spatulaCharge <= 0 and data.bubbleCharge <= 0 and data.canUseFishbowl
	and p:mem(0x12E,FIELD_BOOL) and (p.keys.run or p.keys.altRun) and not data.SpongebobStanding and data.state == STATE_NORMAL then
		if data.fishbowlCharge <= 0 and not data.chargeSFX:isplaying() then
			data.chargeSFX = SFX.play("powerups/nasb2charge.ogg",1,0)
		end
		p.keys.jump = KEYS_UP
		p.keys.altJump = KEYS_UP
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		data.fishbowlCharge = math.min(data.fishbowlCharge + 2, settings.maxCharge)
		charge = data.fishbowlCharge
		p.speedX = p.speedX * 0.85
		p.speedY = -Defines.player_grav + 0.1	--math.clamp(p.speedY - (Defines.player_grav + 0.01),-Defines.player_grav - 0.01,3)
	elseif data.fishbowlCharge > 0 and data.state == STATE_NORMAL then
		data.state = STATE_FISHBOWL
		p.speedY = -0.1
		data.fishbowlCharge = math.max(data.fishbowlCharge, 100)
		data.fishbowlTimer = data.fishbowlCharge
		p:mem(0x12E,FIELD_WORD,1) -- keeps the player ducked
		stopSFX(data.chargeSFX)
		SFX.play("powerups/nasb2fishbowl.ogg",100)
		data.fishbowlCharge = 0
		data.canUseFishbowl = false
	end
	------------ END OF FISHBOWL CHARGING ------------
	
	------------ SPATULA CHARGING ------------
	if not data.isHoldingJump and data.actionCooldown <= 0 
	and data.fishbowlCharge <= 0 and data.bubbleCharge <= 0 and not p:mem(0x12E,FIELD_BOOL)
	and data.canUseSpatula and not isOnGround(p) and p:mem(0x11C,FIELD_WORD) <= 0 
	and (p.keys.jump or p.keys.altJump) and data.spatulaCharge < settings.maxCharge and data.state == STATE_NORMAL then
		if data.spatulaCharge <= 0 and not data.chargeSFX:isplaying() then
			data.chargeSFX = SFX.play("powerups/nasb2charge.ogg",1,0)
		end
		p.keys.jump = KEYS_UP
		p.keys.altJump = KEYS_UP
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		data.spatulaCharge = math.min(data.spatulaCharge + 2, settings.maxCharge)
		charge = data.spatulaCharge
		p.speedX = p.speedX * 0.85
		p.speedY = -Defines.player_grav + 0.1	--math.clamp(p.speedY - (Defines.player_grav + 0.01),-Defines.player_grav - 0.01,3)
	elseif data.spatulaCharge > 0 and data.state == STATE_NORMAL then
		data.state = STATE_SPATULA
		p.speedY = -0.1
		data.canUseSpatula = false
		data.spatulaTimer = data.spatulaCharge
		data.spatulaDuration = math.floor(data.spatulaCharge*0.25)
		data.spatulaCharge = 0
		stopSFX(data.chargeSFX)
		SFX.play("powerups/nasb2spatula.ogg")
	end
	------------ END OF SPATULA CHARGING ------------
	
	------------ BUBBLE CHARGING ------------
	if not data.isHoldingRun and data.actionCooldown <= 0 
	and data.fishbowlCharge <= 0 and data.spatulaCharge <= 0 and not p:mem(0x12E,FIELD_BOOL)
	and (p.keys.run and not p.keys.altRun) and data.state == STATE_NORMAL then
		if data.bubbleCharge <= 0 and not data.chargeSFX:isplaying() then
			data.state = STATE_NORMAL
			data.spatulaCharge = 0
			data.spatulaTimer = 0
			data.chargeSFX = SFX.play("powerups/nasb2charge.ogg",1,0)
		end
		data.bubbleCharge = math.min(data.bubbleCharge + 2, settings.maxCharge)
		p.keys.left = KEYS_UP
		p.keys.right = KEYS_UP
		p.keys.jump = KEYS_UP
		p.keys.altJump = KEYS_UP
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		p.keys.down = KEYS_UP
		charge = data.bubbleCharge
	elseif data.bubbleCharge > 0 and data.state == STATE_NORMAL then
		data.state = STATE_BUBBLE
		data.chargeSFX:stop()
		if data.bubbleCharge >= 32 then
			local dir = p.direction
			local v = NPC.spawn(
				spunchbop.projectileID,
				data.bubbleSprite.x,
				data.bubbleSprite.y, p.section, false, true
			)
			v.data.scale = data.bubbleCharge * 0.0175
			v.isProjectile = true
			v.speedX = ((NPC.config[v.id].speed + 1) * dir) + p.speedX/3.5
			v.direction = dir
			v:mem(0x156, FIELD_WORD, 32) -- gives the NPC i-frames
			SFX.play("powerups/nasb2bubble.ogg")
		end
		data.bubbleTimer = 32
		data.actionCooldown = 16
		data.bubbleCharge = 0
	end
	------------ END OF BUBBLE CHARGING ------------
	
	-- spawns sparkle effects/stops the charging
	if charge > 0 and ((charge < settings.maxCharge and lunatime.tick() % 4 == 0) or (charge >= settings.maxCharge and lunatime.tick() % 16 == 0)) then
		Effect.spawn(80,p.x + RNG.random(0,p.width),p.y + RNG.random(0,p.height))
	elseif charge >= settings.maxCharge then
		stopSFX(data.chargeSFX)
	end

	-- used to make sure the player can only charge spatula when they aren't holding down either jump buttons
	if p.keys.jump or p.keys.altJump then
		data.isHoldingJump = true
	else
		data.isHoldingJump = false
	end
	
	-- used to make sure the player can only charge fishbowl & bubble shooting when they aren't holding down either run buttons
	if p.keys.run or p.keys.altRun then
		data.isHoldingRun = true
	else
		data.isHoldingRun = false
	end
	
	if data.state == STATE_NORMAL then 
		return 
	end
	
	------------ FISHBOWL HANDLING ------------
	if data.state == STATE_FISHBOWL and data.fishbowlTimer > 0 and p:mem(0x148, FIELD_WORD) == 0 and p:mem(0x14C, FIELD_WORD) == 0 then
		p.keys.left = KEYS_UP
		p.keys.right = KEYS_UP
		p.keys.down = KEYS_UP
		data.fishbowlTimer = math.max(data.fishbowlTimer - 4,0)
		data.fishbowlSprite[1].rotation = data.fishbowlSprite[1].rotation + 45 * p.direction
		p.speedX = math.min(math.abs(p.speedX) + 1,settings.fishbowlSpeedcap) * p.direction
		p.speedY = math.min(p.speedY - (Defines.player_grav * 0.75), 1)
		handleHitbox(
			p,
			p.x,
			p.x + p.width + 4,
			p.y - 4,
			p.y + p.height + 4,
			0,
			true
		)
	elseif data.state == STATE_FISHBOWL then
		data.state = STATE_NORMAL
		p:setFrame(7)
		p.speedX = p.speedX * 0.75
		p:mem(0x12E,FIELD_WORD,0)
		Routine.run(function()
			p:mem(0x12E,FIELD_BOOL, true)
		end)
		data.attackCombo = 0
		data.fishbowlSprite[1].rotation = 0
		data.fishbowlCharge = 0
		data.fishbowlTimer = 0
	end
	------------ END OF FISHBOWL HANDLING ------------
	
	------------ SPATULA HANDLING ------------
	if data.state == STATE_SPATULA and data.spatulaTimer > 0 and p.speedY < 0 then
		data.spatulaTimer = math.max(data.spatulaTimer - 4,0)
		if data.spatulaDuration > 0 then
			p.speedY = -10 -- math.max(p.speedY - 6 ,-12)
			data.spatulaDuration = math.max(data.spatulaDuration - 4,0)
		end
		handleHitbox(
			p,
			p.x,
			p.x + p.width,
			p.y - data.spatulaSprite.height,
			p.y + p.width*0.15,
			0,
			true
		)
		p.keys.down = KEYS_UP
	elseif data.state == STATE_SPATULA then
		data.state = STATE_NORMAL
		data.attackCombo = 0
		data.spatulaTimer = 0
	end
	------------ END OF SPATULA HANDLING ------------
	
	------------ BUBBLE-SHOOTING HANDLING ------------
	if data.state == STATE_BUBBLE and data.bubbleTimer > 0 then
		data.bubbleTimer = math.max(data.bubbleTimer - 1,0)
		p.keys.down = KEYS_UP
		p:setFrame(21)
	elseif data.state == STATE_BUBBLE then
		data.state = STATE_NORMAL
	end
	------------ END OF BUBBLE-SHOOTING HANDLING ------------
end

function spunchbop.onTickEndPowerup(p)
	if not p.data.spongebob then return end -- check if the powerup is currently active
	local data = p.data.spongebob
	local fishbowlX = p.x + p.width * 0.25
	local fishbowlY = p.y + p.height * 0.25
	data.fishbowlSprite[1].x = fishbowlX
	data.fishbowlSprite[1].y = fishbowlY
	data.fishbowlSprite[1].scale = vector(1 * p.direction,1) --100 * p.direction
	data.spatulaSprite.x = getPlayerSide(p) - (2 * p.direction)
	data.spatulaSprite.y = p.y
	data.bubbleSprite.x = getPlayerSide(p) + ((data.bubbleSprite.width*0.25) * p.direction)
	data.bubbleSprite.y = p.y + p.height * 0.5
	if data.fishbowlTimer > 0  then
		data.fishbowlScale = math.min(data.fishbowlScale + 0.15,1)
		p:mem(0x140,FIELD_WORD,math.max(p:mem(0x140,FIELD_WORD),2))
		if lunatime.tick() % 4 == 0 then
			if afterimages then -- handles emitting afterimages
				afterimages.addAfterImage{
					texture = data.fishbowlSprite[1].texture,
					x = fishbowlX - data.fishbowlSprite[1].width/2,
					y = fishbowlY - data.fishbowlSprite[1].height/2,
					width = 100,
					height = 100,
					texOffsetX = 0,
					texOffsetY = 0.5,
					lifetime = 65,
					priority = -49,
					color = Color.fromHexRGB(0x7080C8),
					angle = data.fishbowlSprite[1].rotation,
					sceneCoords = true,
					animWhilePaused = false

				}
			end
			--Misc.dialog(data.fishbowlSprite[1].rotation)
			Effect.spawn(80,fishbowlX + RNG.random(0,p.width),fishbowlY + RNG.random(0,p.height))
		end
	else
		data.fishbowlScale = math.max(data.fishbowlScale - 0.25,0)
	end
	data.fishbowlSprite[2].x = fishbowlX
	data.fishbowlSprite[2].y = fishbowlY
	data.fishbowlSprite[2].scale = vector(data.fishbowlScale,data.fishbowlScale)
	if data.spatulaTimer > 0 or data.spatulaCharge > 0 then
		p:setFrame(21)
		data.spatulaScale = math.min(data.spatulaScale + 0.25,1) -- makes
	else
		data.spatulaScale = math.max(data.spatulaScale - 0.05,0)
	end
	
	if data.bubbleTimer > 0 then
		p:setFrame(11)
	end
	
	data.spatulaSprite.scale = vector(data.spatulaScale,data.spatulaScale)
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = unOccupied(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
end

local starmanShader = Shader()
starmanShader:compileFromFile(nil,Misc.multiResolveFile("starman.frag","shaders/npc/starman.frag"))

local metalShader = Shader()
metalShader:compileFromFile(nil, Misc.resolveFile("metalShader.frag") or nil)

local vanishShader = Shader()
vanishShader:compileFromFile(nil, Misc.resolveFile("vanishShader.frag") or nil)

function spunchbop.onDrawPowerup(p)
	if not p.data.spongebob then return end -- check if the powerup is currently active
	local data = p.data.spongebob
	--[[
	-- shows the player's hitbox (for debug purposes only)
	local c = Colliders.Box(p.x, p.y, p.width, p.height) 
	c:Draw(Color.red .. 0.5)
	--]]
	local frame = 1
	local timer = 0
	
	local shader,uniforms
	local color = Color.white
	if not p.hasStarman then
		if p.data.metalcapPowerupcapTimer then
			shader = metalShader
		elseif p.data.vanishcapPowerupcapTimer then
			shader = vanishShader
		end
	elseif p.hasStarman then
		shader = starmanShader
		uniforms = {time = lunatime.tick()*2}
	elseif Defines.cheat_shadowmario then
		color = Color.black
	end
	
	-- sets the player frame & timer depending on what action is charging
	if data.fishbowlCharge > 0 then
		frame = 7
		timer = data.fishbowlCharge
	elseif data.spatulaCharge > 0 then
		frame = 21
		timer = data.spatulaCharge
	elseif data.bubbleCharge > 0 then
		frame = 11
		timer = data.bubbleCharge
	end
	
	if data.spatulaCharge > 0 or data.spatulaTimer > 0 or data.spatulaScale > 0 then
		local spatulaAnim = {1,2}
		data.spatulaSprite:draw{	
			frame = spatulaAnim[1 + math.floor(data.spatulaTimer * 0.6) % data.spatulaSprite.frames],
			sceneCoords = true,
			priority = -45 + 0.01,
			color = color,shader = shader,uniforms = uniforms,
			
		}
	end
	
	-- hides the player & override it with a sprite replica that allows rotation
	local height = p:getCurrentPlayerSetting().hitboxHeight
	-- redraws the player & rotates them according to the direction of the wall they're running on
	for i = 1,2,1 do
		if data.fishbowlTimer > 0 then
			data.fishbowlSprite[2].rotation = data.fishbowlSprite[1].rotation
			data.fishbowlSprite[i]:draw{
				frame = i,
				sceneCoords = true,
				color = color,shader = shader,uniforms = uniforms,
			}
			if data.fishbowlTimer > 0 then
				p:setFrame(-50 * p.direction) 
			end
		end
	end
		
	if data.fishbowlCharge <= 0 and data.bubbleCharge <= 0 and data.spatulaCharge <= 0 then return end
	p:setFrame(-50*p.direction)
	p:render{
		frame = frame,
		x = p.x + math.sin(timer * (1 * timer)),
		color = color,shader = shader,uniforms = uniforms,
	}
	if data.bubbleCharge > 0 then
		data.bubbleSprite.scale = vector(data.bubbleCharge*0.0175,data.bubbleCharge*0.0175)
		data.bubbleSprite:draw{
			sceneCoords = true,
			priority = -25 - 0.01,
			color = color,shader = shader,uniforms = uniforms,
		}
	end
end

return spunchbop