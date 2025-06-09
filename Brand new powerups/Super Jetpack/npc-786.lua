local npcManager = require("npcManager")
local cp = require("customPowerups")
local powerup = require("powerups/superJetpack")
local jetpack = {}
local npcID = NPC_ID

powerup.powerupID = npcID

local superJetpack = cp.addPowerup("Super Jetpack", "powerups/superJetpack", npcID)
cp.transformWhenSmall(npcID, 9)

local jetpackSettings = {
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
	nogravity = true,
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

npcManager.setNpcSettings(jetpackSettings)
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

function jetpack.onInitAPI()
	npcManager.registerEvent(npcID, jetpack, "onTickNPC")
	registerEvent(jetpack, "onNPCHarm")
	registerEvent(jetpack, "onNPCCollect")
end

function jetpack.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	if v.despawnTimer <= 0 -- Despawned
	or v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then return end
	
	v.speedY = math.sin(lunatime.tick() / 12) * 0.5
	if lunatime.tick() % 12 == 0 then
		local e = Effect.spawn(npcID,v)
		e.y = (v.y + v.height) + e.height * 0.5
		e.speedY = RNG.random(1,3)
		e.animationFrame = RNG.randomInt(0,1)
	end
end


function jetpack.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

function jetpack.onNPCCollect(token,v,p)
	if v.id ~= npcID then return end
	if not p then return end
	if cp.getCurrentPowerup(p) ~= powerup then return end
	if not p.data.superJetpack then return end
	Effect.spawn(10,v)
	p.data.superJetpack.bar.value = 1
	SFX.play(23)
	SFX.play(7)
end


return jetpack