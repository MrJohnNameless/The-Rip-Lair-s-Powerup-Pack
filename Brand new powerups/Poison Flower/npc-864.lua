local npcManager = require("npcManager")
local poison = require("powerups/poisonFlower")
local poisonFlower = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local poisonFlower = cp.addPowerup("poisonFlower", "powerups/poisonFlower", npcID)
cp.transformWhenSmall(npcID, 9)

local poisonSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
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

npcManager.setNpcSettings(poisonSettings)
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

function poisonFlower.onInitAPI()
	registerEvent(poisonFlower, "onPostNPCCollect")
	-- Cheats.register("needapoisonflower",{
		-- isCheat = true,
		-- activateSFX = 12,
		-- aliases = poison.aliases,
		-- onActivate = (function() 
			-- for i,p in ipairs(Player.get()) do
				-- p.reservePowerup = npcID
			-- end
		-- end)
	-- })
end

function poisonFlower.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	
	if v.forcedState == 2 then p.reservePowerup = 0 return end
	
	-- put your own code here!

end

return poisonFlower