
--[[
				miniMushroom.lua by MrNameless
				
			A customPowerups script that brings over
		the Mini Mushroom from the NSMB series into SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also informed MrNameless on how to make a system to overwrite the player's current frame to allow rotation & such.
	38A / 5438a38a - made the original mini mushroom playable sprites used here.
	AwesomeZack - made the powerup NPC sprite for the mini mushroom. (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=27528)
	DeltomX3 - made the powering up SFX used when the player gets a mini mushroom.
	
	Version 3.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local jumper = require("powerups/customJumps")

local miniMush = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function miniMush.onInitPowerupLib()
	miniMush.spritesheets = {
		miniMush:registerAsset(CHARACTER_MARIO, "mario-miniMushroom.png"),
		miniMush:registerAsset(CHARACTER_LUIGI, "luigi-miniMushroom.png"),
		miniMush:registerAsset(CHARACTER_PEACH, "peach-miniMushroom.png"),
		miniMush:registerAsset(CHARACTER_TOAD, "toad-miniMushroom.png"),
	}

	miniMush.iniFiles = {
		miniMush:registerAsset(CHARACTER_MARIO, "mario-miniMushroom.ini"),
		miniMush:registerAsset(CHARACTER_LUIGI, "luigi-miniMushroom.ini"),
		miniMush:registerAsset(CHARACTER_PEACH, "peach-miniMushroom.ini"),
		miniMush:registerAsset(CHARACTER_TOAD, "toad-miniMushroom.ini"),
	}
end

miniMush.basePowerup = PLAYER_SMALL
miniMush.items = {}
miniMush.collectSounds = {
    upgrade = Misc.resolveFile("powerups/mini-mushroom-grow.ogg"),
    reserve = 12,
}
miniMush.cheats = {"needaminimushroom","weelad","littlebabyman","yomamasoshort","honeyishrunktheplumbers","howstheweatherdownthere","andtheysaiditwasimpossible"}
miniMush.settings = {
	allowWallRun = true, -- should the player be allowed to run up walls while mini? (true by default)
	allowSpinjumpHarm = true, -- should the player still be able to harm NPCs by spinjumping while mini? (true by default)
	allowPeachSpinjump = true, -- should be peach be given the ability to spinjump while mini? (true by default)
	allowWaterRun = true, -- should the player be allowed to run on water while mini? (true by default)
	requiredWaterSpeed = 1, -- how much horizontal speed must the player reach to be able to walk on water (1 by default)
	whitelistedNPCs = table.map{311,312,313,314,315,316,316,318,446,447,448,449,467,466} -- which npc IDs can you harm no matter what when you're mini?
}

local testMenu
if Misc.inEditor() then
	testMenu = require("engine/testmodemenu")
end

local beachKoopaIDs = {
	[109] = 117,
	[110] = 118,
	[111] = 119,
	[112] = 120,
}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- jump heights for mario, luigi, peach, toad, & link respectively
local jumpheights = {30,25,30,30,30}

local smwCostumes = table.map{"SMW-MARIO","SMW-LUIGI","SMW-TOAD","SMW-WARIO","SMM2-MARIO","SMM2-LUIGI","SMM2-TOAD","SMM2-TOADETTE"} -- ,"SMW-TODD?"}

local pauseFix = 0 -- needed to fix an issue regarding pausing with the editor's test menu

-- calls in Emral's anotherwalljump if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

local function notTouchingBounds(p)
	local section = Section(p.section)
	local bounds = section.boundary
	return (
		p.x > bounds.left + 2
		and p.x + p.width < bounds.right - 2
	)
end

local function canWallClimb(p)
	return (
		p.mount == 0
		and p.forcedState == 0
		and not p:mem(0x36,FIELD_BOOL) -- not underwater
		and notTouchingBounds(p) -- not trying to wallrun on the section's boundaries
		and (math.abs(p.data.miniMushroom.lastSpeedX) >= 4 or p.data.miniMushroom.isWallRunning) -- running fast enough
		and (p.keys.run or p.keys.altRun)
		and p:mem(0x14A, FIELD_WORD) == 0 -- not hitting a ceiling
		and (
			(p:mem(0x14C, FIELD_WORD) ~= 0 and p.keys.right) -- wall running to the right
			or (p:mem(0x148, FIELD_WORD) ~= 0 and p.keys.left) -- wall running to the left
		) 
		and not (GP and GP.isPounding(p)) -- not ground pounding
	)
end

function miniMush.onInitAPI()
	registerEvent(miniMush,"onNPCHarm")
	registerEvent(miniMush,"onNPCTransform")
	registerEvent(miniMush,"onBlockHit")
end

-- runs once when the powerup gets activated, passes the player
function miniMush.onEnable(p)
	jumper.registerPowerup(cp.getCurrentName(p),jumpheights)
	p.keys.run = KEYS_UP
	p.keys.altRun = KEYS_UP
	Defines.player_grabSideEnabled = false -- prevents the player from holding items
	Defines.player_grabTopEnabled = false -- prevents the player from holding items
	Defines.player_grabShellEnabled = false -- prevents the player from holding items
	p.data.miniMushroom = {
		originalCoords = vector(p.x,p.y), -- for fixing an annoying issue regarding pausing with the editor's test menu
		isWallRunning = false,
		onWater = false,
		canFloat = false,
		wasInPipe = false,
		wallTimer = 0,
		wallJumpLeeway = 0,
		weightLoss = p:attachWeight(-2), -- makes the player lose weight
		wallRunDirection = p.direction,
		lastSpeedX = p.speedX,
	}
	if lunatime.tick() > 1 then
		p.x = p.data.miniMushroom.originalCoords.x
		p.y = p.data.miniMushroom.originalCoords.y + p.height
	end

end

-- runs once when the powerup gets deactivated, passes the player
function miniMush.onDisable(p)
	Audio.sounds[1].muted = false
	Audio.sounds[33].muted = false
	p:detachWeight(p.data.miniMushroom.weightLoss) -- resets the player's weight by default
	Defines.player_grabSideEnabled = nil
	Defines.player_grabTopEnabled = nil
	Defines.player_grabShellEnabled = nil
	
	p.data.miniMushroom = nil
end

-- runs when the powerup is active, passes the player
function miniMush.onTickPowerup(p)
	if cp.getCurrentPowerup(p) ~= miniMush or not p.data.miniMushroom then return end
	
	--p:mem(0x154,FIELD_WORD,-2) -- prevents the player from picking up any items (I would've used this if it didn't mess with specific player animations not playing)
	
	local data = p.data.miniMushroom
	
	if data.isWallRunning and aw then
		aw.preventWallSlide(p) -- prevents the anotherwalljump from running when wall-running
	end
	
	if p.mount == MOUNT_BOOT then
		p.keys.down = KEYS_PRESSED
		if p.forcedState == FORCEDSTATE_PIPE then
			data.wasInPipe = true
		elseif data.wasInPipe then
			p:mem(0x15C,FIELD_WORD, 60)
			data.wasInPipe = false
		end
	end
	
	-- gives the player slower fallspeed
	if p.speedY > 0 and p.forcedState == 0 and p.mount == 0
	and not p:mem(0x36,FIELD_BOOL) and not p:mem(0x0C,FIELD_BOOL) then 
		local modifier = 0.8
		if p.character == CHARACTER_LUIGI then
			modifier = 0.7
		end
		p.speedY = math.max(p.speedY - Defines.player_grav * modifier, Defines.player_grav)
	end
end

-- runs when the powerup is active, passes the player
function miniMush.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= miniMush or not p.data.miniMushroom then return end 
	
	local data = p.data.miniMushroom
	
	-- deals with fixing an annoying issue regarding pausing with the editor's test menu
	if pauseFix > 0 then
		pauseFix = pauseFix - 1
		p.x,p.y = data.originalCoords.x,data.originalCoords.y
	else
		data.originalCoords = vector(p.x,p.y)
	end
	
	-- stops wallrunning when hitting a ceiling (fallback if onBlockHit fails to detect touching a ceiling)
	if p:mem(0x14A, FIELD_WORD) ~= 0 then 
		data.isWallRunning = false
	end

	-- handles wall-JUMPING
	local skipWallrun = false
	-- using wallJumpLeeway instead to allow some leniency in pressing the inputs needed to walljump
	if data.wallJumpLeeway > 0  and (p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED) then
		p.speedX = -6 * data.wallRunDirection
		p.speedY = -8
		p.keys.left = KEYS_UP
		p.keys.right = KEYS_UP
		data.wallJumpLeeway = 0
		data.isWallRunning = false
		skipWallrun = true
		Routine.run(function() -- delays jump handling check by 2 frames/ticks
			Routine.skip()
			Routine.skip()
			if p.keys.altJump then
				p:mem(0x50,FIELD_BOOL, true)
				SFX.play(33)
			else
				SFX.play(1)
			end
		end)
		p:mem(0x18,FIELD_BOOL, data.canFloat) -- gives peach back her float if she didn't use it before wall-running
	elseif data.wallJumpLeeway > 0 then
		data.wallJumpLeeway = data.wallJumpLeeway - 1
	end

	-- handles wall-RUNNING
	if miniMush.settings.allowWallRun and canWallClimb(p) and not skipWallrun then
		if not data.isWallRunning then
			data.canFloat = p:mem(0x18,FIELD_BOOL) -- stores peach's spinjump if she hasn't used it before wall-running
			p:mem(0x18,FIELD_BOOL,false) -- stops peach from being able to float
			p:mem(0x50,FIELD_BOOL,false) -- stops spinjumping
			p:mem(0x1C,FIELD_WORD,0) -- stops peach's float
			p.speedY = math.abs(data.lastSpeedX) * -1 -- converts the player's x speed into wall-running speed
			data.wallRunDirection = p.direction
			data.isWallRunning = true
		end
		data.wallTimer = data.wallTimer + 1 -- updates the timer for the wall running animation
		data.wallJumpLeeway = 8
		p.speedY = math.max(math.min(p.speedY -(Defines.player_grav * 1.15), -4.5), -6) -- makes the player "run" upwards with a minimum running speed of -4.5
	elseif data.isWallRunning then -- if the player fully ran up to the top of a wall without walljumping 
		if p.direction == data.wallRunDirection and not (p.keys.jump or p.keys.altJump) and (p.keys.left or p.keys.right) and (p.keys.run or p.keys.altRun) then
			-- gives the player back their original speedX + some extra speed from running up a wall
			p.speedX = data.lastSpeedX + math.abs(p.speedY) * p.direction
			p.speedY = 6 -- needed to immediately get the player on the floor upon running up a wall
			data.wallJumpLeeway = 0
			p:mem(0x18,FIELD_BOOL, data.canFloat) -- gives peach back her float if she didn't use it before wall-running
		end
		data.wallTimer = 0 -- resets the timer for the wall running animation back to 0
		data.isWallRunning = false
	else
		data.lastSpeedX = p.speedX
	end

	data.onWater = false
	if miniMush.settings.allowWaterRun then
		-- handles water RUNNING
		for k, l in ipairs(Liquid.getIntersecting(p.x,p.y,p.x+p.width,p.y+p.height + 2 + p.speedY/2)) do 
			-- if the player's above water & is running fast enough
			if not p:mem(0x36,FIELD_BOOL) and p.mount == 0 
			and p:mem(0x11C,FIELD_WORD) <= 0 and p.y + p.height < l.y + 2
			and (math.abs(p.speedX) >= miniMush.settings.requiredWaterSpeed - 0.5) then -- speed check has to be 5.5 because peach has a slower max speed of 5.58 for some god forsaken reason
				p:mem(0x50,FIELD_BOOL, false)
				p.y = l.y - 2 - p.height
				p.speedY = -Defines.player_grav
				data.onWater = true
				if lunatime.tick() % 5 == 0 then -- spawn a water splashing effect every 3 frames
					local e = Effect.spawn(114, (p.x + p.width*0.5), l.y) 
					e.xAlign = 0.5
					e.x = (e.x - (e.width * 0.5)) - (p.width * p.direction)
					e.y = l.y - (e.height)
				end
			end
		end
	end
	
	-- needed to prevent showing jumping frames when running on water
	if data.onWater and p.frame == 3 then 
		p.frame = 2
	end
end

-- runs when the powerup is active, passes the player
function miniMush.onDrawPowerup(p)
	local playerBuffer = Graphics.CaptureBuffer(100, 100)
	playerBuffer:clear(-100)

	if not p.data.miniMushroom then return end
	local data = p.data.miniMushroom
	
	-- deals with fixing an annoying issue regarding pausing
	if (testMenu and testMenu.active) then	
		pauseFix = 2
		p.x,p.y = data.originalCoords.x,data.originalCoords.y
	end
	
	local animation = {1,2} -- running animation for mario & luigi
	
	if smwCostumes[Player.getCostume(p.character)] then -- running animation for the SMW costumes
		animation = {17,16}
	elseif smb2Chars[p.character] then -- running animation for peach & toad
		animation = {1,2,3,2}
	end
	
	if p.mount == MOUNT_BOOT or p.mount == MOUNT_CLOWNCAR then
		p:setFrame(-50 * p.direction)
	end
	
	if data.isWallRunning then
		local frame = animation[1 + math.floor(data.wallTimer * 0.6) % #animation] -- sets the animation frame depending on the wallTimer
		-- hides the player & override it with a sprite replica that allows rotation
		p:setFrame(-50 * p.direction) 
		p:render{
			frame = frame,
			target = playerBuffer,
			x = 50 - p.width/2,
			y = 50 - p.height/2,
			mount = p.mount,
			sceneCoords = false,
		}
		-- redraws the player & rotates them according to the direction of the wall they're running on
		Graphics.drawBox{ 
			texture = playerBuffer,
			x = (p.x + p.width/2) - ((p.width/3 - 2) * p.direction), 
			y = p.y + p.height/2, -- tweaks needed
			sceneCoords = true,
			centered = true,
			rotation = (90 * -p.direction)
		}
	end
	
end

-- the following chunks of code all refreshes the player's jump replica
function miniMush.onNPCHarm(token,v,harm,c)
	if NPC.config[v.id].iscustomswitch then return end
	
	if not c or type(c) ~= "Player" then return end
	if harm ~= 1 and (harm ~= 8 and not miniMush.settings.allowSpinjumpHarm) then return end
	if cp.getCurrentPowerup(c) ~= miniMush or not c.data.miniMushroom then return end 
	
	if (harm == 1 or (harm == 8 and not miniMush.settings.allowSpinjumpHarm) or (GP and GP.isPounding(c))) 
	and c.mount == 0 and not miniMush.settings.whitelistedNPCs[v.id] then
		token.cancelled = true
		SFX.play(2)
	end
end

-- check if a player was right above the NPC whenever it was transformed by a jump/sword harmtype
function miniMush.onNPCTransform(v,oldID,harm)
	if harm ~= 1 and (harm ~= 8 and not miniMush.settings.allowSpinjumpHarm) then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if cp.getCurrentPowerup(p) == miniMush and p.data.miniMushroom then
			-- attempts to """cancel""" the npc from changing into it's new id
			if not miniMush.settings.whitelistedNPCs[v.id] then
				Routine.run(function()	-- nameless's notes: making a method of "cancelling" a transformation was utter HELL I HATED MAKING THIS SO MUCH
					v.dontMove = v:mem(0x4A, FIELD_BOOL) -- prevents the npc from losing their dontMove property
					local oldScore = NPC.config[v.id].score
					NPC.config[v.id].score = 0
					p:mem(0x56, FIELD_WORD, 0) -- prevents the player from gaining score
					Routine.skip() -- delays the intersect check & score reverting by 1 frame/tick
					v.x = v.x + v.width
					v.y = v.y + v.height
					v:transform(oldID,false)
					v.x = v.x - v.width
					v.y = v.y - v.height
					local intersect = NPC.getIntersecting(v.x - 2,v.y - 2,v.x + v.width + 2,v.y + v.height + 2)
					for i,n in ipairs(intersect) do 
						if i == #intersect then
							if n.isValid and not n.isHidden and n.id == beachKoopaIDs[v.id] then
								n:kill(9) -- deals with SMW koopa shells & killing the beach koopa spawned by it's shell
							end
						end
					end
					local effects = Effect.getIntersecting(v.x - 2,v.y - 2,v.x + v.width + 2,v.y + v.height + 2) 
					for i,e in ipairs(effects) do
						if i == #effects - 1 then
							e.animationFrame = -999
							e.timer = 0	-- deals with hiding the poof effect spawned by a SMW koopa when it transform
						end
					end
					NPC.config[v.id].score = oldScore -- gives the npc id back it's original score
				end)
			end
		end
	end
end

function miniMush.onBlockHit(token,v,above,p)
	-- this code however stops the player from wall running upon hitting a block above them
	if p and not above then 
		if cp.getCurrentPowerup(p) == miniMush and p.data.miniMushroom then
			p.keys.left = KEYS_UP
			p.keys.right = KEYS_UP
			p.data.miniMushroom.isWallRunning = false
		end
	end
end

return miniMush