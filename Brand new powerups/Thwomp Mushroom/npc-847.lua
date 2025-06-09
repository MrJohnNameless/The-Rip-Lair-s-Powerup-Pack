local npcManager = require("npcManager")
local thwompMushroom = require("powerups/thwompMushroom")
local mushroom = {}
local npcID = NPC_ID

local cp = require("customPowerups")
local thwompMushroom = cp.addPowerup("Thwomp Mushroom", "powerups/thwompMushroom", npcID)
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
	npcManager.registerEvent(npcID, mushroom, "onTickNPC")
	Cheats.register("needathwompshroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = thwompMushroom.settings.aliases,
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function mushroom.onTickNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		data.timer = 0
		data.initialized = true
		data.hopCount = 0
	end
	
	if v.collidesBlockBottom then
		data.timer = data.timer + 1
		v.speedX = 0
		
		if data.timer >= 60 then
			data.hopCount = data.hopCount + 1
			if data.hopCount == 1 then
				v.speedX = 3.55 * v.direction
			elseif data.hopCount == 2 then
				v.speedX = -3.55 * v.direction
			elseif data.hopCount == 3 then
				v.speedX = 3.55 * v.direction
			elseif data.hopCount == 4 then
				v.speedX = -3.55 * v.direction
				data.hopCount = 0
			end
			data.timer = 0
			v.speedY = -10
		end
	end
	
	if v.speedY ~= 0 then
		v.speedY = v.speedY + 0.3
	end
	--v.speedX = 1.7999999523163 * v.direction
end

function mushroom.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	
	if v.forcedState == 2 then p.reservePowerup = 0 return end
	if not p.data.thwompMushroom then return end
	local data = p.data.thwompMushroom
end

return mushroom