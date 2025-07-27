local npcManager = require("npcManager")
local fuzzyAI = require("npcs/ai/yifuzzy")
local drugshroom = {}
local npcID = NPC_ID

local drugshroomSettings = {
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
	
	dizzytransitiontime = 2,
	dizzytime = 30,
	dizzystrength = 10
}

npcManager.setNpcSettings(drugshroomSettings)
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

function drugshroom.onInitAPI()
	registerEvent(drugshroom, "onPostNPCCollect")
	Cheats.register("needadrugshroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"needaseizure","ilovecrack","epilepticwarning","touch420get420","snoopdogg","porygon"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				if Graphics.getHUDType(p.character) == Graphics.HUD_ITEMBOX then
					p.reservePowerup = npcID
				else
					local n = NPC.spawn(
						npcID,
						camera.x + camera.width/2 - NPC.config[npcID].width/2,
						camera.y + 32,
						p.section
					)
					n.forcedState = 2
				end
			end
			return true
		end)
	})
end

function drugshroom.onPostNPCCollect(v,p)
	if v.id ~= npcID then return end
	if not p then return end
	SFX.play("weed.ogg")
	fuzzyAI.getDizzy(NPC.config[npcID])
end

return drugshroom