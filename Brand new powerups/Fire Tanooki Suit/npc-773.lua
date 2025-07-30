--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local powerup = require("powerups/fireTanooki")

--Create the library table
local fireTanooki = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

local cp = require("customPowerups")
local fireTanooki = cp.addPowerup("Fire Tanooki", "powerups/fireTanooki", npcID)

--Defines NPC config for our NPC. You can remove superfluous definitions.
local fireTanookiSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 32,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 2,
	--Frameloop-related
	frames = 1,
	framestyle = 0,
	framespeed = 8, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1,
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
	score = SCORE_1000,
	isinteractable = true,
	sparkEffect = 859,
}

--Applies NPC settings
npcManager.setNpcSettings(fireTanookiSettings) 



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

function fireTanooki.onInitAPI()
	npcManager.registerEvent(npcID, fireTanooki, "onTickNPC")
	Cheats.register("needafiretanooki",{
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

function fireTanooki.onTickNPC(v)
	if Defines.levelFreeze or v.forcedState > 0 then return end
	
	local data = v.data 
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		data.timer = 0
		return
	end
	if not data.initialized then
		data.initialized = true
		data.timer = data.timer or 0
	end

	data.timer = data.timer + 1

	if data.timer == 16 then

		local e = Effect.spawn(NPC.config[v.id].sparkEffect, v.x + RNG.randomInt(0, v.width), v.y + RNG.randomInt(0, v.height))
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
		data.timer = 0
	end
end

--Custom local definitions below
--Gotta return the library table!
return fireTanooki

