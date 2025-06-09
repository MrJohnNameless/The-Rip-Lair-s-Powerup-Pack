--Blockmanager is required for setting basic Block properties
local blockManager = require("blockManager")
local utils = require("blocks/blockutils")

--Create the library table
local sampleBlock = {}
--BLOCK_ID is dynamic based on the name of the library file
local blockID = BLOCK_ID

--Defines Block config for our Block. You can remove superfluous definitions.
local samplsampleBlockettings = {
	id = blockID,
	--Frameloop-related
	frames = 1,
	framespeed = 8, --# frames between frame change

	--Identity-related flags:
	--semisolid = false, --top-only collision
	--sizable = false, --sizable block
	--passthrough = false, --no collision
	--bumpable = false, --can be hit from below
	--lava = false, --instakill
	--pswitchable = false, --turn into coins when pswitch is hit
	--smashable = 0, --interaction with smashing NPCs. 1 = destroyed but stops smasher, 2 = hit, not destroyed, 3 = destroyed like butter

	--floorslope = 0, -1 = left, 1 = right
	--ceilingslope = 0,

	--Emits light if the Darkness feature is active:
	--lightradius = 100,
	--lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	--lightcolor = Color.white,

	--Define custom properties below
}

--Applies blockID settings
blockManager.setBlockSettings(samplsampleBlockettings)

--Register the vulnerable harm types for this Block. The first table defines the harm types the Block should be affected by, while the second maps an effect to each, if desired.

--Custom local definitions below
local breakables = {13, 265}

--local sidecollider = Colliders.Box(v.x - 1, v.y, v.width + 2, v.y - 1)

--Register events
function sampleBlock.onInitAPI()
	blockManager.registerEvent(blockID, sampleBlock, "onTickEndBlock")
	registerEvent(sampleBlock, "onPostNPCKill")
	blockManager.registerEvent(blockID, sampleBlock, "onCollideBlock")
	--registerEvent(sampleBlock, "onBlockHit")
end

function sampleBlock.onTickEndBlock(v)
	 -- Don't run code for invisible entities
	if v.isHidden or v:mem(0x5A, FIELD_BOOL) then return end
	
	local data = v.data
end

local function idfilter(v)
	return v.id == blockID and not v.isHidden and not v:mem(0x5A, FIELD_BOOL)
end

function sampleBlock.onPostNPCKill(v, rsn)
	if rsn ~= 4 and rsn ~= 3 then return end
	
	for _,w in ipairs(utils.checkNPCCollisions(v, idfilter)) do
		sampleBlock.onCollideBlock(w, v)
	end
end

function sampleBlock.onCollideBlock(w, v)	
	if (v.__type == "NPC") then
		if table.icontains(breakables, v.id) then
			v:kill(HARM_TYPE_PROJECTILE)
			w:remove()
			SFX.play(3)
			SFX.play(4)
			Animation.spawn(100, w.x + (w.width/2), w.y + (w.height/2))
		end
	end
end

--Gotta return the library table!
return sampleBlock