local npcManager = require("npcManager")

local pwing = {}
local npcID = NPC_ID

local pwingSettings = {
	id = npcID,

	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 1,
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
	isstationary = true,
	notcointransformable = true,

	-- Custom properties

	sparkEffect = 80,
	transformID = (npcID - 1),
}

npcManager.setNpcSettings(pwingSettings)
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

--Custom local definitions below
pwing.activePlayers = {}
pwing.activationTimer = {}

pwing.doGroundSparkleEffect = false -- If true, then the sparkle effect is set at all times, even while on the ground

local function isOnGroundRedigit(p) -- isOnGround, except redigit
    return (
        p.speedY == 0
        or p.standingNPC ~= nil
        or p:mem(0x48,FIELD_WORD) > 0 -- On a slope
    )
end

--Register events
function pwing.onInitAPI()
	npcManager.registerEvent(npcID, pwing, "onTickNPC")
	registerEvent(pwing, "onStart")
	registerEvent(pwing, "onTickEnd")
	registerEvent(pwing, "onDraw")
	registerEvent(pwing, "onNPCCollect")
	registerEvent(pwing, "onNPCHarm")
end

function pwing.onStart()
	Cheats.register("needapwing",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"strangeandwonderfulthing","flightmode","redbull"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function pwing.onTickEnd()
	for k,p in ipairs(pwing.activePlayers) do
		if pwing.activationTimer[p] ~= nil then
			if pwing.activationTimer[p] > 0 then
				pwing.activationTimer[p] = pwing.activationTimer[p] - 1
			end
		end

		if p.powerup == 4 or p.powerup == 5 then
			if (not isOnGroundRedigit(p) and p.keys.jump) or p.character ~= CHARACTER_LINK then
				p:mem(0x170, FIELD_WORD, 999)
			end
			--player:mem(0x02, FIELD_WORD, 20)
			
			--Disable sparkles while on the ground
			if not isOnGroundRedigit(p) then
				p:mem(0x16C, FIELD_BOOL, true)
				
				if p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) == 1 then --Check for shoe ground movement
					p:mem(0x16E, FIELD_BOOL, false)
				elseif p.mount == MOUNT_YOSHI then --If riding Yoshi, then replace raccoon flight with wings
					p:mem(0x66, FIELD_BOOL, true)
				elseif p.mount ~= MOUNT_CLOWNCAR then --Enable flight if the player is not walking with a shoe or in a clown car
					p:mem(0x16E, FIELD_BOOL, true)
				end
			elseif isOnGroundRedigit(p) and pwing.doGroundSparkleEffect then
				if RNG.random() * 10 > 9 then
					local e = Effect.spawn(80, p.x - 8 + RNG.random() * (p.width + (p.width / 2))-4,
										       p.y - 8 + RNG.random() * (p.height + (p.height/ 2) )-4)
					e.speedX = RNG.random() * 0.5 - 0.25
					e.speedY = RNG.random() * 0.5 - 0.25
				end
			end
		elseif p.forcedState ~= 5 and (pwing.activationTimer[p] ~= nil and pwing.activationTimer[p] == 0) then
			p:mem(0x66, FIELD_BOOL, false)
			table.remove(pwing.activePlayers, k)
		end
	end
end

function pwing.onDraw() -- Fix the player's default jump frame being drawn
	for k,p in ipairs(pwing.activePlayers) do
		if p.frame == 4 and p.character ~= 5 then
			p.frame = 19
		end
		--[[
		if player:isGroundTouching() and pwingSettings.doGroundSparkleEffect then
			player:mem(0x02, FIELD_WORD, 80)
		end]]
	end
end

function pwing.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	if NPC.config[v.id].sparkEffect and NPC.config[v.id].sparkEffect > 0 then
		if RNG.randomInt(1, 24) == 1 then
			local e = Effect.spawn(NPC.config[v.id].sparkEffect, v.x + RNG.randomInt(0, v.width), v.y + RNG.randomInt(0, v.height))
			e.x = e.x - e.width/2
			e.y = e.y - e.height/2
			e.speedY = -1.2
		end
	end
end

function pwing.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

function pwing.onNPCCollect(eventObj, v, p)
	if npcID ~= v.id or v.isGenerator then return end
	
	--pwing.active = true
	--pwing.activationTimer = 2

	if not pwing.activePlayers[p] then
		table.insert(pwing.activePlayers, p)
		pwing.activationTimer[p] = 2
	end

	z = NPC.spawn(NPC.config[v.id].transformID, p.x, p.y)
	z.animationFrame = -999
	z.animationTimer = 999
	z.speedX = p.speedX
	z.speedY = p.speedY
end

--Gotta return the library table!
return pwing