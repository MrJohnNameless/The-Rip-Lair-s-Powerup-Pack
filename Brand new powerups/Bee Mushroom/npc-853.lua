local npcManager = require("npcManager")
local beeMushroom = require("powerups/beeMushroom")
local mushroom = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local beeMushroom = cp.addPowerup("Bee Mushroom", "powerups/beeMushroom", npcID)
cp.transformWhenSmall(npcID, 9)

local flowerSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 0,
	width = 32,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	speed = 1.5,
	iswalker = true,
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
	luahandlesspeed = true,
}

npcManager.setNpcSettings(flowerSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

function mushroom.onInitAPI()
	registerEvent(mushroom, "onPostNPCCollect")
	Cheats.register("needabeeshroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = beeMushroom.settings.aliases,
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function mushroom.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	
	if v.forcedState == 2 then p.reservePowerup = 0 return end
	if not p.data.beeMushroom then return end
	local data = p.data.beeMushroom
end

return mushroom