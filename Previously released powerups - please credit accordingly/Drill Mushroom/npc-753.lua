local npcManager = require("npcManager")
local powerup = require("powerups/drill")
local sampleNPC = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local drill = cp.addPowerup("Drill", "powerups/drill", npcID)
drill.applyDefaultSettings()
cp.transformWhenSmall(npcID, 9)

local sampleNPCSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	width = 32,
	height = 32,
	frames = 3,
	framestyle = 0,
	framespeed = 6,
	luahandlesspeed = true,
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

npcManager.setNpcSettings(sampleNPCSettings)
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

function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	registerEvent(sampleNPC, "onNPCHarm")
	Cheats.register("needadrill",{
		isCheat = true,
		activateSFX = 12,
		aliases = powerup.aliases,
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function sampleNPC.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	if v.heldIndex ~= 0 
	or v.isProjectile   
	or v.forcedState > 0
	then return end
	
	v.speedX = 1.8 * v.direction
end

function sampleNPC.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

return sampleNPC