local npcManager = require("npcManager")
local lifeShroom = {}
local npcID = NPC_ID

SaveData.playersToRevive = SaveData.playersToRevive or {}
local playersToRevive = SaveData.playersToRevive

local iconImage = Graphics.loadImageResolved("lifeShroomIcon.png")
lifeShroom.effectID = npcID

local health
pcall(function() health = require("customHealth") end)

local lifeShroomSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	score = 0,
	
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

	luahandlesspeed = true,
}

npcManager.setNpcSettings(lifeShroomSettings)
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

function lifeShroom.onInitAPI()
	npcManager.registerEvent(npcID, lifeShroom, "onTickEndNPC")
	registerEvent(lifeShroom, "onNPCCollect")
	registerEvent(lifeShroom, "onNPCHarm")
	registerEvent(lifeShroom, 'onDraw')
	registerEvent(lifeShroom, "onPlayerKill")
	Cheats.register("needalifemushroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"needalifeshroom","secondchance","mushroomofundying","reviveme"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function lifeShroom.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	if v.heldIndex ~= 0 
	or v.isProjectile   
	or v.forcedState > 0
	then return end
	
	v.speedX = 1.8 * v.direction
end

function lifeShroom.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

function lifeShroom.onDraw() -- custom HUD (not multiplayer compatible)
    	for k,p in ipairs(playersToRevive) do
		Graphics.draw{
			type = RTYPE_IMAGE,
			image = iconImage,
			x = 212,
			y = 26,
			sourceX = 0,
			sourceY = 0,
			sourceWidth = 16,
			sourceHeight = 16,
			priority = 5
		}
	end
end

function lifeShroom.onNPCCollect(eventObj, v, p)
	if v.id ~= npcID or v.isGenerator then return end

        local e = Effect.spawn(131,v.x + v.width*0.5,v.y + v.height*0.5)
        e.x = e.x - e.width*0.5
        e.y = e.y - e.height*0.5

	if not playersToRevive[p.idx] then
		table.insert(playersToRevive, p.idx)
		SFX.play(84)
	else
		Misc.givePoints(6, vector(v.x + (v.width/2),v.y), true)
		SFX.play(12)
	end
end

function lifeShroom.onPlayerKill(eventObj, p)
	if playersToRevive[p.idx] then
		if p.y >= p.sectionObj.boundary.bottom + 64 then table.remove(playersToRevive, p.idx) return end
		if health then health.set(1) end
		eventObj.cancelled = true
		Defines.earthquake = 8
		SFX.play("lifeShroom.ogg")
        	local e = Effect.spawn(lifeShroom.effectID,p.x + p.width*0.5,p.y + p.height*0.5)
        	e.x = e.x - e.width*0.5
        	e.y = e.y - e.height*0.5
	        for j = 1, RNG.randomInt(8, 24) do
                        local e = Effect.spawn(10,p.x + p.width*0.5,p.y + p.height*0.5)
                        e.x = e.x - e.width * 0.5
                        e.y = e.y - e.height * 0.5
		        e.speedX = RNG.random(-4, 4)
		        e.speedY = RNG.random(-4, 4)
	        end  
		p:mem(0x140, FIELD_WORD, 200)
		table.remove(playersToRevive, p.idx)
	end
end

return lifeShroom