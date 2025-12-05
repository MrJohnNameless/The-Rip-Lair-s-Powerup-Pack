local npcManager = require("npcManager")

local vanishShader = Shader()
vanishShader:compileFromFile(nil, Misc.resolveFile("vanishShader.frag"))

local vanishCap = {}
local npcID = NPC_ID

vanishCap.settings = {
	duration = 20,
	music = "powerfulMario.ogg",

	intangibleBlocks = {115, 687, 1283, 1284, 1285, 1286, 1287, 1288, 1289, 1290, 1291, npcID --[[The custom Grate Block]]},
}

local vanishCapNPCSettings = {
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
	notcointransformable = true
}

npcManager.setNpcSettings(vanishCapNPCSettings)
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

function vanishCap.onInitAPI()
	registerEvent(vanishCap, "onTick")
	registerEvent(vanishCap, "onDraw")
	registerEvent(vanishCap, "onDrawEnd")
	registerEvent(vanishCap, "onNPCHarm")
	registerEvent(vanishCap, "onNPCCollect")
	registerEvent(vanishCap, "onExit")
	registerEvent(vanishCap, "onPlayerHarm")
	registerEvent(vanishCap, "onPlayerKill")

	Cheats.register("needavanishcap",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"underthemoat", "imshy"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
		end)
	})
end

local function deInitDataForCap(p)
	p.data.vanishcapPowerupcapTimer = nil
	p.data.vanishcapPowerupstartMusic = nil
	p.data.vanishcapisvanishcap = nil

	Misc.groupsCollide["vanishPlayer"]["vanishBlock"] = true
end

function vanishCap.onPlayerHarm(e, p)
	if p.data.vanishcapPowerupcapTimer then
		e.cancelled = true
	end
end

function vanishCap.onPlayerKill(e,p)
	if not p.data.vanishcapPowerupcapTimer then return end

	Audio.resetMciSections()
	deInitDataForCap(p)
end

function vanishCap.onExit()
	for i,p in ipairs(Player.get()) do
		deInitDataForCap(p)
	end
end

local restrictMovement = {}

function vanishCap.onTick()
	for i,p in ipairs(Player.get()) do
		if p.data.vanishcapPowerupcapTimer then

			local data = p.data
			local config = vanishCap.settings
			
			if data.vanishcapPowerupcapTimer == 0 and data.vanishcapPowerupstartMusic then
				Audio.SeizeStream(-1)
				Audio.MusicStopFadeOut(300)

				data.vanishcapPowerupstartMusic = false
			elseif data.vanishcapPowerupcapTimer == 30 then
				Audio.MusicOpen(config.music)
				Audio.MusicPlay()
			elseif data.vanishcapPowerupcapTimer == (lunatime.toTicks(config.duration) - 100) then
				Audio.MusicStopFadeOut(1000)
			elseif data.vanishcapPowerupcapTimer >= lunatime.toTicks(config.duration) then
				Audio.resetMciSections()
				deInitDataForCap(p)

				return
			end
			
			if p.powerup == 1 then p.powerup = 2 end
			
			data.vanishcapPowerupcapTimer = data.vanishcapPowerupcapTimer + 1
			
			--Invincibility code taken from MegaDood's Invincibility Leaf
			p:mem(0x140, FIELD_WORD, 1)
			p:mem(0x142, FIELD_BOOL, true)

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

function vanishCap.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function vanishCap.onNPCCollect(eventObj, v, p)
	if npcID ~= v.id or v.isGenerator then return end
	
	SFX.play(sm64_star)
	
	Misc.givePoints(NPC.config[v.id].score, {x = v.x, y = v.y}, true)
	
	--Reset the vanish cap timer if already in that state, otherwise start the whole vanish cap event
	if p.data.vanishcapPowerupcapTimer and p.data.vanishcapPowerupcapTimer > 0 then
		p.data.vanishcapPowerupcapTimer = 0
	else
		-- Init data values!!!

		p.data.vanishcapPowerupcapTimer = 0
		p.data.vanishcapPowerupstartMusic = true
		p.collisionGroup = "vanishPlayer"

		for _,block in ipairs(Block.get(vanishCap.settings.intangibleBlocks)) do
			block.collisionGroup = "vanishBlock"
			Misc.groupsCollide["vanishPlayer"]["vanishBlock"] = false
		end
	end
	
end

function vanishCap.onDrawEnd()
	for i,p in ipairs(Player.get()) do
		if (p.frame == -50 * p.direction * p.direction) or (p.frame == -50 * p.direction) then p.data.vanishCapVanishPlayer = true else p.data.vanishCapVanishPlayer = false end
	end
end

function vanishCap.onDraw()
	for i,p in ipairs(Player.get()) do
		
		if p.data.vanishCapVanishPlayer then return end
		
		local enabled = 0
		local speed = 0

		local config = vanishCap.settings

		if p.data.vanishcapPowerupcapTimer then
			
			if p.data.vanishcapPowerupcapTimer < 60 then speed = 8 else speed = 4 end
			
			if (p.data.vanishcapPowerupcapTimer < 60 and not p.data.vanishcapisvanishcap) or p.data.vanishcapPowerupcapTimer >= (lunatime.toTicks(config.duration) - 128) then
				enabled = math.floor(p.data.vanishcapPowerupcapTimer / speed) % 2
			else
				enabled = 1
				p.data.vanishcapisvanishcap = true
			end
			
			--Stop the player's movement like they're transforming
			if not p.data.vanishcapisvanishcap then
				if speed == 8 then
					restrictMovement[p.idx] = true
					p.speedX = 0
				end
			end
			
			if p.data.vanishcapPowerupcapTimer >= 61 and restrictMovement[p.idx] then restrictMovement[p.idx] = false end
			
			if p.frame ~= 50 then p.data.vanishcapFrame = p.frame end
			
			if enabled == 1 then
				p:render{
					frame = p.data.vanishcapFrame,
					direction = p.direction,
					powerup = p.powerup,
					mount = p.mount,
					character = p.character,
					x = p.x,
					y = p.y,
					color = Color.white .. 0.5,
					drawplayer = true,
					ignorestate = false,
					sceneCoords = true,
					priority = -25,
					shader = vanishShader,
					uniforms = {
						enabled = enabled,
					},
				}
				p.frame = 50 
			end
		end
	end
end

return vanishCap