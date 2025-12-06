local npcManager = require("npcManager")

local iceBlock = {}
local npcID = NPC_ID

function iceBlock.onInitAPI()
    npcManager.registerEvent(npcID, iceBlock, "onTickEndNPC")
	registerEvent(iceBlock, "onPostNPCKill")
end

function iceBlock.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.initialized = true
		SFX.play("yi_freeze.ogg")
	end
end

function iceBlock.onPostNPCKill(v,reason)
	if v.id == npcID then
		SFX.play("yi_icebreak.ogg")
	end
end

return iceBlock