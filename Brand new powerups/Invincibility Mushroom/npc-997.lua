local npcManager = require("npcManager")
local invincishroom = require("Invincishroom")

local sampleNPC = {}
local npcID = NPC_ID

local sampleNPCSettings = {
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
npcManager.setNpcSettings(sampleNPCSettings)
npcManager.registerHarmTypes(npcID, {}, {})

function sampleNPC.onInitAPI()
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

return sampleNPC