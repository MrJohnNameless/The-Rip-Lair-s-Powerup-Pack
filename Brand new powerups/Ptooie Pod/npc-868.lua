local npcManager = require("npcManager")
local smallSwitch = require("npcs/ai/smallswitch")
local powerup = require("powerups/ptooieSuit")

local ptooie = {}

local npcID = NPC_ID

powerup.projectileID = npcID

npcManager.registerHarmTypes(npcID, 
	{
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_HELD,
		HARM_TYPE_NPC
	}, {
		[HARM_TYPE_PROJECTILE_USED]=235,
		[HARM_TYPE_TAIL]=235,
		[HARM_TYPE_HELD]=235
	}
);

npcManager.setNpcSettings({
	id = npcID,
	gfxheight = 28,
	gfxwidth = 28,
	width = 28,
	height = 28,
	frames = 2,
	framestyle = 0,
	jumphurt = 1,
	nogravity = 0,
	nohurt=true,
	jumphurt = true,
	noblockcollision = 1,
	ignorethrownnpcs = true,
	nofireball=true,
	noiceball=true,
	noyoshi=true,
	maxspeed = 4,
	bubbleFlowerImmunity = true,
	
	bounceOnHit = powerup.settings.bounceOnHit or false,
})

local coloredSwitches = table.map{451,452,453,454,606,607}

function ptooie.onInitAPI()
	npcManager.registerEvent(npcID, ptooie, "onTickEndNPC")
end

function ptooie.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze -- Frozen by stopwatches
	or v.despawnTimer <= 0 -- Despawned
	or v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		return
	end
	
	local data = v.data
	
	--Initialize
	if not data.initialized then
		data.killCombo = 2
		data.initialized = true
	end

	-- Yoinked from Basegame Wario/WarioRewrite's code lol
	for _,b in Block.iterateIntersecting(v.x-2,v.y-2,v.x+v.width+2,v.y+v.height+2) do
		-- If block is visible
		if b.isHidden == false and b:mem(0x5A, FIELD_BOOL) == false and not Block.SEMISOLID_MAP[b.id] then
			-- If the block can be broken
			if Block.MEGA_SMASH_MAP[b.id] then 
				-- don't break the brittle block if there's somehing inside it
				if b.contentID > 0 then 
					b:hitWithoutPlayer(false)
				else
				-- otherwise, break it
					b:remove(true)
				end
			end
		end
	end

	for _, n in NPC.iterateIntersecting(v.x-2,v.y-2,v.x+v.width+2,v.y+v.height+2) do -- handles hitting NPCs
		if n.isValid and (not n.friendly) and n.despawnTimer > 0 and (not n.isGenerator) 
		and n.forcedState == 0 and n.heldIndex == 0 and n.id ~= npcID then
			if NPC.HITTABLE_MAP[n.id] then
				if not NPC.MULTIHIT_MAP[n.id] then
					local oldScore = NPC.config[n.id].score
					NPC.config[n.id].score = data.killCombo
					n:harm(3)
					NPC.config[n.id].score = oldScore
					if data.killCombo >= 11 then data.killCombo = 9 end
					data.killCombo = math.min(data.killCombo + 1, 11)
				else
					n:harm(3)
				end
			elseif NPC.SWITCH_MAP[n.id] then
				if coloredSwitches[n.id] then -- presses the SMBX2 lua-based switches
					smallSwitch.press(n)
				else -- presses the 1.3 switches
					n:harm(1)
				end
				v.speedY = -Defines.npc_grav
			end
			if NPC.config[npcID].bounceOnHit then
				v.speedY = -4
			end
		end
	end

end

return ptooie