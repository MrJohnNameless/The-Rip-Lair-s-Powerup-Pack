--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local ai = require("acorn_ai")
local powerup = require("ap_acorn")
--Create the library table
local acorn = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

local cp = require("customPowerups")
local Acorn = cp.addPowerup("Super Acorn", "ap_acorn", npcID)
cp.transformWhenSmall(npcID, 185)

--Defines NPC config for our NPC. You can remove superfluous definitions.
local acornNPCSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 34,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 1,
	framestyle = 0,
	framespeed = 8, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1.5,
	score = SCORE_1000,
	--Collision-related
	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.
	powerup = true,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,
	--Various interactions
	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = true, --Thrown NPC hurts other NPCs if false

	--Identity-related flags. Apply various vanilla AI based on the flag:
	iswalker = true,
	--isbot = false,
	--isvegetable = false,
	--isshoe = false,
	--isyoshi = false,
	isinteractable = true,
	--iscoin = false,
	--isvine = false,
	--iscollectablegoal = false,
	--isflying = false,
	--iswaternpc = false,
	--isshell = false,

	--Emits light if the Darkness feature is active:
	--lightradius = 100,
	--lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	--lightcolor = Color.white,

	--Define custom properties below
}

--Applies NPC settings
npcManager.setNpcSettings(acornNPCSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		--HARM_TYPE_PROJECTILE_USED,
		--HARM_TYPE_LAVA,
		--HARM_TYPE_HELD,
		--HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		--HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		--[HARM_TYPE_JUMP]=10,
		--[HARM_TYPE_FROMBELOW]=10,
		--[HARM_TYPE_NPC]=10,
		--[HARM_TYPE_PROJECTILE_USED]=10,
		--[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_HELD]=10,
		--[HARM_TYPE_TAIL]=10,
		--[HARM_TYPE_SPINJUMP]=10,
		--[HARM_TYPE_OFFSCREEN]=10,
		--[HARM_TYPE_SWORD]=10,
	}
);
--[[function swooper.onTickNPC(v)
	if Defines.levelFreeze then return end
	if v:mem(0x12A,FIELD_WORD) <= 0 then return end
	local data = v.data._basegame
	if v.ai1 == 1 and not data.hasplayed then
		data.hasplayed = true
		SFX.play(sfxFile)
	elseif v.ai1 == 0 and data.hasplayed then
		data.hasplayed = false
	end
end]]
--Custom local definitions below

function acorn.onInitAPI()
	npcManager.registerEvent(npcID, acorn, "onTickNPC")
	Cheats.register("needanacorn",{
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

function acorn.onTickNPC(v)
	if v:mem(0x138,FIELD_WORD) == 1 then
		v.direction = 1
	end
end

ai.register(npcID)

return acorn