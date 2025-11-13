local npcManager = require("npcManager")

local metalShader = Shader()
metalShader:compileFromFile(nil, Misc.resolveFile("metalShader.frag"))

local metalCap = {}
local npcID = NPC_ID

metalCap.settings = {
	duration = 20,
	music = "metalMario.ogg",

	playerMaxJumpForce = {
		[CHARACTER_MARIO] = 12,
		[CHARACTER_LUIGI] = 14,
		[CHARACTER_PEACH] = 12,
		[CHARACTER_TOAD] = 10,
	},

	playerMaxSpeed = 3,
	playerMaxJumpForce = 12,
	playerGravity = 0.2,
}

local metalCapNPCSettings = {
	id = npcID,
	gfxheight = 16,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 16,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 0,
	score = SCORE_1000,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
	powerup = true,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	ignorethrownnpcs = true,
	notcointransformable = true,
}

npcManager.setNpcSettings(metalCapNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

local sm64_star = Misc.resolveFile("sm64_star.wav")

function metalCap.onInitAPI()
	registerEvent(metalCap, "onTick")
	registerEvent(metalCap, "onDraw")
	registerEvent(metalCap, "onTickEnd")
	registerEvent(metalCap, "onNPCHarm")
	registerEvent(metalCap, "onNPCCollect")
	registerEvent(metalCap, "onExit")
	registerEvent(metalCap, "onPlayerHarm")
	registerEvent(metalCap, "onPlayerKill")

	Cheats.register("needametalcap",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"metalhead", "throughthejetstream", "strangeisntit"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
		end)
	})
end

local function deInitDataForCap(p)
	p.data.frogOrPenguinSuitDisableWater = nil

	p.data.metalcapPowerupsubmerged = nil
	p.data.metalcapPowerupcapTimer = nil
	p.data.metalcapPowerupstoredJumpTimer = nil
	p.data.metalcapPowerupflashTimer = nil
	p.data.metalcapPowerupstartMusic = nil
	p.data.metalcapisMetalCap = nil
	p.data.metalcapQuakeTimer = nil
end

function metalCap.onPlayerHarm(e, p)
	if p.data.metalcapPowerupcapTimer then
		e.cancelled = true
	end
end

function metalCap.onPlayerKill(e,p)
	if not p.data.metalcapPowerupcapTimer then return end

	Audio.resetMciSections()
	deInitDataForCap(p)
end

function metalCap.onExit()
	for i,p in ipairs(Player.get()) do
		deInitDataForCap(p)
	end
end

local restrictMovement = {}

function metalCap.onTick()
	for i,p in ipairs(Player.get()) do
		if p.data.metalcapPowerupcapTimer then

			local data = p.data
			local config = metalCap.settings
			
			if data.metalcapPowerupcapTimer == 0 and data.metalcapPowerupstartMusic then
				Audio.SeizeStream(-1)
				Audio.MusicStopFadeOut(300)

				data.metalcapPowerupstartMusic = false
			elseif data.metalcapPowerupcapTimer == 30 then
				Audio.MusicOpen(config.music)
				Audio.MusicPlay()
			elseif data.metalcapPowerupcapTimer == (lunatime.toTicks(config.duration) - 100) then
				Audio.MusicStopFadeOut(1000)

				if metalcapPowerupflashTimer == 0 then
					metalcapPowerupflashTimer = 1
				else
					metalcapPowerupflashTimer = 0
				end
			elseif data.metalcapPowerupcapTimer >= lunatime.toTicks(config.duration) then
				Audio.resetMciSections()
				deInitDataForCap(p)

				return
			end
			
			if p.powerup == 1 then p.powerup = 2 end
			
			data.metalcapPowerupcapTimer = data.metalcapPowerupcapTimer + 1
			
			--Invincibility code taken from MegaDood's Invincibility Leaf
			p:mem(0x140, FIELD_WORD, 1)
			p:mem(0x142, FIELD_BOOL, true)
			
			for _,v in ipairs(Colliders.getColliding{a = p, b = NPC.HITTABLE, btype = Colliders.NPC, filter = starmanFilter, collisionGroup = p.collisionGroup}) do
				v:harm(HARM_TYPE_EXT_HAMMER);
			end

			-- Break blocks

			for _,b in ipairs(Block.getIntersecting(p.x + (p.speedX * 0.5), p.y + (p.speedY * 0.75), p.x + p.width + (p.speedX * 0.5), p.y + p.height + (p.speedY * 0.685))) do
							if not b.isHidden and not b.layerObj.isHidden and b.layerName ~= "Destroyed Blocks" and b:mem(0x5A, FIELD_WORD) ~= -1 then 
					if Block.MEGA_SMASH_MAP[b.id] then 
							b:remove(true)
										SFX.play(3)
					end
				end
			end

			if p:mem(0x36, FIELD_BOOL) and p:mem(0x34, FIELD_WORD) == 2 then 
				p:mem(0x11E, FIELD_BOOL, false) --Disable swimming
				
				if p.mount == 0 then --Mount check in order to allow dismounting underwater
					p:mem(0x120, FIELD_BOOL, false)
				end
				
				data.metalcapPowerupsubmerged = true
			
				if p:isGroundTouching() then --Set up jumping underwater
					if p:mem(0x11C, FIELD_WORD) < Defines.jumpheight - 1 then
						p:mem(0x11C, FIELD_WORD, 0)
					end
					
					if p.keys.jump == 1 or p.keys.altJump == 1 then
						SFX.play(1)
						p:mem(0x11C, FIELD_WORD, Defines.jumpheight)
					end
				end
				
				--Handle jumping underwater
				if p:mem(0x11C, FIELD_WORD) > 0 then
					if p.keys.jump == nil or p.keys.altJump == nil then
						p:mem(0x11C, FIELD_WORD, 0)
					else
						p:mem(0x11C, FIELD_WORD, p:mem(0x11C, FIELD_WORD) - 1)
						p.speedY = Defines.jumpspeed / 2.25
					end
				end
				
				--Limit the player's X and Y speeds
				p.speedX = p.speedX / 1.03
				p.speedY = p.speedY + .02
				
				--Get the player's remaining jump time for use when coming out of water
				data.metalcapPowerupstoredJumpTimer = p:mem(0x11C, FIELD_WORD)
			else
				if data.metalcapPowerupsubmerged == true then
					if p:mem(0x11C, FIELD_WORD) ~= data.metalcapPowerupstoredJumpTimer then
						p:mem(0x11C, FIELD_WORD, 0)
					end
				end

				-- Make the player bulky

				local onGround = p:isOnGround()

				if p.forcedState == FORCEDSTATE_NONE and p.deathTimer == 0 then
					if p:mem(0x11C,FIELD_WORD) > config.playerMaxJumpForce[p.character] then
						p:mem(0x11C,FIELD_WORD, config.playerMaxJumpForce[p.character])
					end

					if p.keys.right then
						p.speedX = p.speedX - 0.02
					elseif p.keys.left then
						p.speedX = p.speedX + 0.02
					end

					p.speedX = math.clamp(p.speedX,-config.playerMaxSpeed, config.playerMaxSpeed)

					p:mem(0x00,FIELD_BOOL,false) -- disable tanooki toad's double jump
					p:mem(0x168,FIELD_FLOAT,0) -- p-speed
					p:mem(0x16C,FIELD_BOOL,false) -- has p-speed
					p:mem(0x16E,FIELD_BOOL,false) -- is flying

					if not onGround and p.speedY > 0 then
						p.speedY = p.speedY + config.playerGravity
					end

					-- Quake effects

						if not onGround then
						p.data.metalcapQuakeTimer = p.data.metalcapQuakeTimer + 1
						end

						if p.data.metalcapQuakeTimer >= 12 and onGround then
						p.data.metalcapQuakeTimer = 0

						Defines.earthquake = math.max(Defines.earthquake, 4)
							SFX.play(Misc.resolveSoundFile("bowlingball"), 2)

						local s = Effect.spawn(10, p.x + p.width * 0.5, p.y + p.height)
						s.x = s.x - s.width * 0.5
						s.y = s.y - s.height * 0.5
						s.speedX = -3	

						local s = Effect.spawn(10, p.x + p.width * 0.5, p.y + p.height)
						s.x = s.x - s.width * 0.5
						s.y = s.y - s.height * 0.5
						s.speedX = 3	
						end
				end
			end

			if restrictMovement[p.idx] then
				p.keys.up = nil
				p.keys.left = nil
				p.keys.right = nil
				p.keys.down = nil
				p.keys.run = nil
				p.keys.jump = nil
				p.keys.altRun = nil
				p.keys.altJump = nil
			end
		end
	end
end

function metalCap.onTickEnd()
	for i,p in ipairs(Player.get()) do
		if p.data.metalcapPowerupcapTimer then
			local data = p.data
			
			if p.frame >= 40 then -- Jump animation handling
				if p.speedY < 0 then
					p:setFrame(4)
				else
					p:setFrame(5)
				end
			end
			
			if p:mem(0x36, FIELD_BOOL) == false and p:mem(0x34, FIELD_WORD) ~= 2 then --Do stuff once the player is out of water
				if data.metalcapPowerupsubmerged then
					data.metalcapPowerupsubmerged = false
					
					if p.keys.jump == true or p.keys.altJump == true then
						p:mem(0x11C, FIELD_WORD, data.metalcapPowerupstoredJumpTimer / 2)
						if p:mem(0x11C, FIELD_WORD) ~= data.metalcapPowerupstoredJumpTimer then
							p.speedY = Defines.jumpspeed
						else
							
						end
					end
					
					p:mem(0x11E, FIELD_BOOL, true) --Re-enable jumping outside of water
					p:mem(0x120, FIELD_BOOL, true)
				end
			end
		end
	end
end

function metalCap.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function metalCap.onNPCCollect(eventObj, v, p)
	if npcID ~= v.id or v.isGenerator then return end
	
	SFX.play(sm64_star)
	
	p.data.frogOrPenguinSuitDisableWater = true
	
	Misc.givePoints(NPC.config[v.id].score, {x = v.x, y = v.y}, true)
	
	--Reset the metal cap timer if already in that state, otherwise start the whole metal cap event
	if p.data.metalcapPowerupcapTimer and p.data.metalcapPowerupcapTimer > 0 then
		p.data.metalcapPowerupcapTimer = 0
	else
		-- Init data values!!!
	
		p.data.metalcapPowerupsubmerged = false
		p.data.metalcapPowerupcapTimer = 0
		p.data.metalcapPowerupstoredJumpTimer = 0
		p.data.metalcapPowerupflashTimer = 0
		p.data.metalcapPowerupstartMusic = true
		p.data.metalcapQuakeTimer = 0
	end
end

function metalCap.onDraw()
	for i,p in ipairs(Player.get()) do
		
		local enabled = 0
		local speed = 0

		local config = metalCap.settings

		if p.data.metalcapPowerupcapTimer then
			if p.data.metalcapPowerupcapTimer < 60 then speed = 8 else speed = 4 end
			
			if (p.data.metalcapPowerupcapTimer < 60 and not p.data.metalcapisMetalCap) or p.data.metalcapPowerupcapTimer >= (lunatime.toTicks(config.duration) - 128) then
				enabled = math.floor(p.data.metalcapPowerupcapTimer / speed) % 2
			else
				enabled = 1
				p.data.metalcapisMetalCap = true
			end
			
			--Stop the player's movement like they're transforming
			if not p.data.metalcapisMetalCap then
				if speed == 8 then
					restrictMovement[p.idx] = true
					p.speedX = 0
				end
			end
			
			if p.data.metalcapPowerupcapTimer >= 61 and restrictMovement[p.idx] then restrictMovement[p.idx] = false end
			
			p:render{
				x = p.x,
				shader = metalShader,
				uniforms = {
					enabled = enabled,
				},
			}
		end
	end
end

return metalCap