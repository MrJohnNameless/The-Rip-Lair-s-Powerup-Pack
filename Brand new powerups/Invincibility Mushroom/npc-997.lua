local npcManager = require("npcManager")

local Invincishroom = {}
local npcID = NPC_ID

Invincishroom.enableAssistSpawn = true
Invincishroom.deathsRequired = 5
Invincishroom.particleEffects = true

local InvincishroomSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	width = 32,
	height = 32,
	gfxoffsety = 2,
	speed = 0,
	frames = 13,
	framestyle = 0,
	framespeed = 6,
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
	ignorethrownnpcs = true,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = true,
	notcointransformable = true,
	jumphurt = false, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	grabside=false,
	grabtop=false,
	isinteractable = true,
}

npcManager.setNpcSettings(InvincishroomSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
	}
);

GameData.__invincishroomDeaths = GameData.__invincishroomDeaths or {};
GameData.__invincishroomDeaths[Level.filename()] = GameData.__invincishroomDeaths[Level.filename()] or {};
local deathCount = GameData.__invincishroomDeaths[Level.filename()]

local invinciPlayers = {}
local sparkles = {}

function Invincishroom.onInitAPI()
	registerEvent(Invincishroom, "onStart")
	registerEvent(Invincishroom, "onDraw")
	registerEvent(Invincishroom, "onNPCCollect")
	registerEvent(Invincishroom, "onNPCHarm")
	registerEvent(Invincishroom, "onPostPlayerKill")
	registerEvent(Invincishroom, "onExitLevel")

	Cheats.register("needaninvincibilitymushroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"needainvincibilitymushroom", "needaninvincibilityshroom", "needainvincibilityshroom", "needaninvincishroom", "needainvincishroom"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function Invincishroom.onStart() 
	for i,p in ipairs(Player.get()) do
		if (deathCount[p.idx] and deathCount[p.idx] >= Invincishroom.deathsRequired) and Invincishroom.enableAssistSpawn then
			local n = NPC.spawn(npcID, p.x+p.width/2, p.y)
			n.x = n.x - (n.width * 0.5)
			n.y = n.y - n.height
			n.speedY = -7

			SFX.play(7)
		end
	end
end

function Invincishroom.onDraw()
	for k,p in ipairs(invinciPlayers) do
		if p.deathTimer == 0 then
			local priority
			local wid = "-".. (p.width*0.5)..":"..(p.width*0.5)
			local hei = "-"..(p.height*0.5)..":"..(p.height*0.5)

			if p.forcedState == 3 then
				priority = -70
			else
				priority = -25
			end

			p:mem(0x140, FIELD_WORD, 2)
			p:mem(0x142, FIELD_WORD, 0);

			if sparkles[p.idx] and Invincishroom.particleEffects then
				sparkles[p.idx]:setParam("xOffset",wid)
				sparkles[p.idx]:setParam("yOffset",hei)
				sparkles[p.idx]:Draw(priority)
			end
		end
	end
end

function Invincishroom.onNPCCollect(eventObj, v, p)
	if v.id ~= npcID or v.isGenerator then return end

	local e = Effect.spawn(294,v.x + v.width*0.5,v.y + v.height*0.5)
	SFX.play("invincishroom.ogg")

	if not invinciPlayers[p] then
		table.insert(invinciPlayers, p)

		if not sparkles[p.idx] then
			sparkles[p.idx] = Particles.Emitter(0, 0, Misc.resolveFile("particles/p_starman_sparkle.ini"))
			sparkles[p.idx]:Attach(p)
		end
	end
end

function Invincishroom.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

function Invincishroom.onPostPlayerKill(p)
	deathCount[p.idx] = (deathCount[p.idx] or 0) + 1
end

function Invincishroom.onExitLevel(win)
	if win > 0 then
		for i,p in ipairs(Player.get()) do
			deathCount[p.idx] = nil
		end
	end
end

return Invincishroom