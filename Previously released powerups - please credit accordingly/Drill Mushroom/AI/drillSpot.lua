local blockManager = require("blockManager")
local blockutils = require("blocks/blockutils")
local drillSpot = {}

SaveData.drillSpot = SaveData.drillSpot or {}
SaveData.drillSpot.count = SaveData.drillSpot.count or 0
SaveData.drillSpot.collectedCount = SaveData.drillSpot.collectedCount or 0
SaveData.drillSpot.levelData = SaveData.drillSpot.levelData or {} -- level filename map with total and collected count

SaveData.drillSpot.levelData[Level.filename()] = SaveData.drillSpot.levelData[Level.filename()] or {count = 0, collectedCount = 0, collectedMap = {}}

drillSpot.idList = {}
drillSpot.idMap = {}

drillSpot.collectSFX = {id = 73, volume = 1}

local savedata = SaveData.drillSpot
local levelData = savedata.levelData[Level.filename()]

local fieldList = {"id", "count", "speedX", "speedY", "direction", "ai1", "ai2", "ai3", "ai4", "ai5",
"layerName", "attachedLayerName", "activateEventName", "deathEventName", "talkEventName", "noMoreObjInLayer",
"legacyBoss", "friendly", "dontMove", "msg", "noblockcollision"}

function drillSpot.collect(v, offset, silent)
    offset = offset or vector(0, 0)
    
    local data = v.data
    local settings = data._settings
    local spawnedNPCs = {}

    if v.isHidden then return end

    --v.isHidden = true

    if Block.config[v.id].useSaveData and not levelData.collectedMap[settings.idx] then
        levelData.collectedMap[settings.idx] = true
        levelData.collectedCount = levelData.collectedCount + 1
        savedata.collectedCount = savedata.collectedCount + 1
    end

    for idx, item in ipairs(data.contents) do
        item.count = item.count or 1
        item.id = item.id or 10

        if item.id > 0 then
            for i = 1, math.max(item.count, 1) do
                local n = NPC.spawn(item.id, v.x + v.width/2 + offset.x, v.y + offset.y)

                n.x = n.x - n.width/2
                n.y = n.y - n.height

                -- apply settings
                for k, field in ipairs(fieldList) do
                    local setting = item[field]

                    if field ~= "id" and field ~= "count" and setting ~= nil then
                        n[field] = setting
                    end
                end

                table.insert(spawnedNPCs, n)
            end
        end
    end

    local sfx = drillSpot.collectSFX

    if sfx.id and not silent then
        SFX.play(sfx.id, sfx.volume or 1)
    end

    v:remove(false)

    return spawnedNPCs
end

function drillSpot.reset(v)
    v.layerName = "Default"
    v.isHidden = false
end

function drillSpot.register(id)
    if drillSpot.idMap[id] then return end
    
    blockManager.registerEvent(id, drillSpot, "onStartBlock")
    blockManager.registerEvent(id, drillSpot, "onCameraDrawBlock")

    table.insert(drillSpot.idList, id)
    drillSpot.idMap[id] = true
end

function drillSpot.onInitAPI()
    registerEvent(drillSpot, "onDraw")
end

function drillSpot.onStartBlock(v)
    local data = v.data
    local settings = data._settings

    settings.idx = settings.idx or 1

    if not settings.editorInput or settings.editorInput == "" then
        settings.editorInput = "{id = 10}"
    end

    local f, errorStr = loadstring([[return {]]..settings.editorInput.."}")

    if f == nil then
        error("Couldn't parse the bean hole's item table.")
    end

    data.contents = f()

    levelData.count = levelData.count + 1
    savedata.count = savedata.count + 1

    if levelData.collectedMap[settings.idx] and Block.config[v.id].useSaveData then
        levelData.collectedCount = levelData.collectedCount + 1
        savedata.collectedCount = savedata.collectedCount + 1
        --v.isHidden = true
        v:remove(false)
    end
end

function drillSpot.onCameraDrawBlock(v, camIdx)
	if (not blockutils.visible(Camera(camIdx),v.x,v.y,v.width,v.height)) or v.isHidden or v:mem(0x5A,FIELD_BOOL) then
		return
	end

    local data = v.data
    local config = Block.config[v.id]

    Graphics.drawImageToSceneWP(
        Graphics.sprites.block[v.id].img,
        v.x,
        v.y,
        config.priority
    )
end

function drillSpot.onDraw()
    for _, id in ipairs(drillSpot.idList) do
        blockutils.setBlockFrame(id, -999)
    end
end

return drillSpot