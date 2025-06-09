
local basePowerupList = table.map{9,14,34, 169, 170, 182, 183, 184, 185, 186, 187, 249, 264, 277, 287}

local randomIDs = {793,794}

function onStart()
    for i,b in Block.iterate() do
		if basePowerupList[b.contentID - 1000] then
			local content = RNG.irandomEntry(randomIDs)
			b.contentID = content + 1000
			b:mem(0x06,FIELD_WORD, content + 1000)
		end
	end
	for i,n in NPC.iterate() do
		if basePowerupList[n.id] then
			local id = RNG.irandomEntry(randomIDs)
			local config = NPC.config[id]
			local newCoordsX = (n.spawnX + n.spawnWidth) - config.width 
			local newCoordsY = (n.spawnY + n.spawnHeight) - config.height
			n.id, n.spawnId = id,id
			n.spawnX, n.x = newCoordsX,newCoordsX 
			n.spawnY, n.y = newCoordsY,newCoordsY
			n.spawnWidth,n.width = config.width,config.width
			n.spawnHeight,n.height = config.height,config.height
		elseif basePowerupList[n.ai1] then
			n.ai1 = RNG.irandomEntry(randomIDs)
			n.spawnAi1 = n.ai1
		end
	end
end

