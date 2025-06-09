local npcManager = require("npcManager")
local metalShader = Shader()
metalShader:compileFromFile(nil, Misc.resolveFile("metalShader.frag"))
local template = {}
local npcID = NPC_ID

local templateSettings = {
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

npcManager.setNpcSettings(templateSettings)
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

function template.onInitAPI()
	npcManager.registerEvent(npcID, template, "onTickNPC")
	registerEvent(template, "onTick")
	registerEvent(template, "onDraw")
	registerEvent(template, "onTickEnd")
	registerEvent(template, "onNPCHarm")
	registerEvent(template, "onNPCCollect")
	registerEvent(template, "onExit")
	registerEvent(template, "onPlayerKill")
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

function template.onPlayerKill(e,p)
	if not p.data.metalcapPowerupcapTimer then return end
	Audio.resetMciSections()
	p.data.frogOrPenguinSuitDisableWater = nil
	p.data.metalcapPowerupsubmerged = nil
	p.data.metalcapPowerupcapTimer = nil
	p.data.metalcapPowerupstoredJumpTimer = nil
	p.data.metalcapPowerupflashTimer = nil
	p.data.metalcapPowerupstartMusic = nil
	p.data.metalcapisMetalCap = nil
end

function template.onExit()
	for i,p in ipairs(Player.get()) do
		p.data.frogOrPenguinSuitDisableWater = nil
		p.data.metalcapPowerupsubmerged = nil
		p.data.metalcapPowerupcapTimer = nil
		p.data.metalcapPowerupstoredJumpTimer = nil
		p.data.metalcapPowerupflashTimer = nil
		p.data.metalcapPowerupstartMusic = nil
		p.data.metalcapisMetalCap = nil
	end
end

local restrictMovement = false

function template.onTick(p)
	
	for i,p in ipairs(Player.get()) do
		if not p.data.metalcapPowerupcapTimer then return end

		local data = p.data
		
		if data.metalcapPowerupcapTimer == 0 and data.metalcapPowerupstartMusic then
			Audio.SeizeStream(-1)
			Audio.MusicStopFadeOut(300)
			data.metalcapPowerupstartMusic = false
		elseif data.metalcapPowerupcapTimer == 30 then
			Audio.MusicOpen("metalMario.ogg")
			Audio.MusicPlay()
		elseif data.metalcapPowerupcapTimer == 1150 then
			Audio.MusicStopFadeOut(1000)
			if metalcapPowerupflashTimer == 0 then
				metalcapPowerupflashTimer = 1
			else
				metalcapPowerupflashTimer = 0
			end
		elseif data.metalcapPowerupcapTimer == 1250 then
			Audio.resetMciSections()
			p.data.frogOrPenguinSuitDisableWater = nil
			p.data.metalcapPowerupsubmerged = nil
			p.data.metalcapPowerupcapTimer = nil
			p.data.metalcapPowerupstoredJumpTimer = nil
			p.data.metalcapPowerupflashTimer = nil
			p.data.metalcapPowerupstartMusic = nil
			p.data.metalcapisMetalCap = nil
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
		end
	end
	
	if restrictMovement then
		player.keys.up = nil
		player.keys.left = nil
		player.keys.right = nil
		player.keys.down = nil
		player.keys.run = nil
		player.keys.jump = nil
		player.keys.altRun = nil
		player.keys.altJump = nil
	end
	
end

function template.onTickEnd(p)
	for i,p in ipairs(Player.get()) do
		if not p.data.metalcapPowerupcapTimer then return end

		local data = p.data
		
		if p.frame >= 40 then -- Jump animation handling
			if p.speedY < 0 then
				p:setFrame(4)
			else
				p:setFrame(3)
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

function template.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function template.onNPCCollect(eventObj, v, p)
	if npcID ~= v.id or v.isGenerator then return end
	
	SFX.play(sm64_star)
	
	p.data.frogOrPenguinSuitDisableWater = true
	
	Misc.givePoints(NPC.config[v.id].score, {x = v.x, y = v.y}, true)
	
	--Reset the metal cap timer if already in that state, otherwise start the whole metal cap event
	if p.data.metalcapPowerupcapTimer and p.data.metalcapPowerupcapTimer > 0 then
		p.data.metalcapPowerupcapTimer = 0
	else
		p.data.metalcapPowerupsubmerged = false
		p.data.metalcapPowerupcapTimer = 0
		p.data.metalcapPowerupstoredJumpTimer = 0
		p.data.metalcapPowerupflashTimer = 0
		p.data.metalcapPowerupstartMusic = true
	end
	
end

function template.onDraw(p)
	for i,p in ipairs(Player.get()) do
		local enabled = 0
		local speed = 0
		if not p.data.metalcapPowerupcapTimer then return end
		
		if p.data.metalcapPowerupcapTimer < 60 then speed = 8 else speed = 4 end
		
		if (p.data.metalcapPowerupcapTimer < 60 and not p.data.metalcapisMetalCap) or p.data.metalcapPowerupcapTimer >= 1122 then
			enabled = math.floor(lunatime.tick() / speed) % 2
		else
			enabled = 1
			p.data.metalcapisMetalCap = true
		end
		
		--Stop the player's movement like they're transforming
		if not p.data.metalcapisMetalCap then
			if speed == 8 then
				restrictMovement = true
				p.speedX = 0
			end
		end
		
		if p.data.metalcapPowerupcapTimer == 61 then restrictMovement = false end
		
		p:render{
			x = p.x,
			shader = metalShader,
			uniforms = {
				enabled = enabled,
			},
		}
	end
end

return template