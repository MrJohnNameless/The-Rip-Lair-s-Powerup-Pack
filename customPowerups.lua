--[[
    By Marioman2007 [v1.3.1] (unreleased LATEST)
    uses code from anotherpowerup.lua by Emral
]]

SaveData.customPowerups = SaveData.customPowerups or {}

local pm = require("playerManager")
local npcManager = require("npcManager")

local savedata = SaveData.customPowerups

local cp = {}

cp.powerUpForcedState = 754   -- used when transforming to/from a custom powerup

cp.FORCEDSTATE_TYPE_NONE = 0
cp.FORCEDSTATE_TYPE_NORMAL = 1
cp.FORCEDSTATE_TYPE_POOF = 2


local testMenuWasActive = false
local wasPaused = false
local savedataCleared = false
local storedPowerupName = nil

local powerMap = {}
local powerNames = {}
local itemMap = {}
local blacklistedChars = {}
local playerData = {}
local mapAssetsLoaded = {}

local registeredAssets = {}
local registeredFilenames = {}

local transformations = {}
local apFields = {"apSounds", "onTick", "onTickEnd", "onDraw"}
local apFieldsReplacement = {"collectSounds", "onTickPowerup", "onTickEndPowerup", "onDrawPowerup"}

local apdl
local GP
local respawnRooms
local testModeMenu

if not isOverworld then
    pcall(function() apdl = require("anotherPowerDownLibrary") end)
    pcall(function() GP = require("GroundPound") end)
    pcall(function() respawnRooms = require("respawnRooms") end)
end

if Misc.inEditor() and not isOverworld then
    testModeMenu = require("engine/testmodemenu")
end

respawnRooms = respawnRooms or {respawnSettings = {respawnPowerup = 1}}

local defaultItemMap = {
    [9]   = PLAYER_BIG,
    [184] = PLAYER_BIG,
    [185] = PLAYER_BIG,
    [249] = PLAYER_BIG,
    [250] = PLAYER_BIG,

    [14]  = PLAYER_FIREFLOWER,
    [182] = PLAYER_FIREFLOWER,
    [183] = PLAYER_FIREFLOWER,

    [264] = PLAYER_ICE,
    [277] = PLAYER_ICE,

    [34]  = PLAYER_LEAF,
    [169] = PLAYER_TANOOKIE,
    [170] = PLAYER_HAMMER,
}

local defaultPowerupMap = {
    [PLAYER_SMALL]      = 0,
    [PLAYER_BIG]        = 9,
    [PLAYER_FIREFLOWER] = 14,
    [PLAYER_ICE]        = 264,
    [PLAYER_LEAF]       = 34,
    [PLAYER_TANOOKIE]   = 169,
    [PLAYER_HAMMER]     = 170,
}

local vanillaForcedStateTypes = {
    [PLAYER_BIG]        = cp.FORCEDSTATE_TYPE_NORMAL,
    [PLAYER_FIREFLOWER] = cp.FORCEDSTATE_TYPE_NORMAL,
    [PLAYER_ICE]        = cp.FORCEDSTATE_TYPE_NORMAL,
    [PLAYER_LEAF]       = cp.FORCEDSTATE_TYPE_POOF,
    [PLAYER_TANOOKIE]   = cp.FORCEDSTATE_TYPE_POOF,
    [PLAYER_HAMMER]     = cp.FORCEDSTATE_TYPE_POOF,
}


------------------------
-- Internal Functions --
------------------------

local forcedStateFuncs = {
    [cp.FORCEDSTATE_TYPE_NORMAL] = function(p, data, t)
        if t == 50 then
            return true
        end

        local frame = math.floor(t / 5) % 2

        if frame == 0 and not data.assetLoaded then
            data.assetLoaded = true
            cp.setPowerup(data.newPowerup, p, true)
            
        elseif frame == 1 and data.assetLoaded then
            data.assetLoaded = false
            cp.setPowerup(data.oldPowerup, p, true)
        end
    end,

    [cp.FORCEDSTATE_TYPE_POOF] = function(p, data, t)
        if t == 16 then
            return true
        end
    end
}

local function callEvent(currentPowerup, name, ...)
    if currentPowerup and currentPowerup[name] then
        currentPowerup[name](...)
    end
end

local function getPowerupFile(lib, tableName, character, defaultFile)
    if lib._usesNormalMethod then
        return lib[tableName][character] or defaultFile
    end

    local filename = lib[tableName][character]

    if not filename then
        return defaultFile
    end

    local asset = lib:getAsset(character, filename)

    if not asset and defaultFile then
        registeredAssets[character].__default[filename] = defaultFile
        return defaultFile
    end

    return asset
end

local function loadAssets(lib, p)
    if not lib then
        return
    end

    Misc.loadCharacterHitBoxes(p.character, lib.basePowerup, getPowerupFile(
        lib, "iniFiles", p.character, pm.getHitboxPath(p.character, lib.basePowerup)
    ))

    Graphics.sprites[pm.getName(p.character)][lib.basePowerup].img = getPowerupFile(
        lib, "spritesheets", p.character, pm.getCostumeImage(p.character, lib.basePowerup)
    )

    local gpImage = getPowerupFile(lib, "gpImages", p.character, nil)

    if GP and gpImage then
        GP.overrideRenderData(p, {texture = gpImage, frameX = 0})
    end
end

local function resetAssets(id, character, p)
    Misc.loadCharacterHitBoxes(character, id, pm.getHitboxPath(character, id))
    Graphics.sprites[pm.getName(character)][id].img = pm.getCostumeImage(character, id)

    if GP then
        GP.overrideRenderData(p, {})
    end
end

local function SFXPlay(lib, name)
    if lib and lib.collectSounds and lib.collectSounds[name] then
        SFX.play(lib.collectSounds[name])
    end
end

local function loadFile(key, file, character, costumeName, name)
    local f = file
    local typ = name .. "-ini"
    local canAddFile = true

    if string.find(file, ".png") then
        f = Graphics.loadImage(file)
        typ = name .. "-img"
        canAddFile = (f.width == 1000 and f.height == 1000)
    end

    registeredAssets[character][costumeName][key] = f

    -- this is for overworld compatibility
    if registeredFilenames[character] == nil then
        registeredFilenames[character] = {}
    end

    if registeredFilenames[character][costumeName] == nil then
        registeredFilenames[character][costumeName] = {}
    end

    if canAddFile then
        registeredFilenames[character][costumeName][typ] = file
    end
end

local function registerAsset(powerup, character, filename)
    registeredAssets[character] = registeredAssets[character] or {__default = {}}

    for k, costumeName in ipairs(pm.getCostumes(character)) do
        registeredAssets[character][costumeName] = registeredAssets[character][costumeName] or {}

        local path1 = costumeName.."\\".. string.format(powerup.costumePathFormat, filename)
        local path2 = "costumes\\"..pm.getName(character).."\\"..costumeName.."\\".. string.format(powerup.costumePathFormat, filename)

        for k, path in ipairs{path1, path2} do
            local file = Misc.resolveFile(path)

            if file then
                loadFile(filename, file, character, costumeName, powerup.name)
                break
            end
        end
    end

    local file = Misc.resolveFile(string.format(powerup.pathFormat, filename))

    if file then
        loadFile(filename, file, character, "__default", powerup.name)
    end

    return filename
end

local function getAsset(powerup, character, key)
    local costumeName = pm.getCostume(character)
    local asset = registeredAssets[character].__default[key]

    if costumeName then
        asset = registeredAssets[character][costumeName][key] or asset
    end

    return asset
end

local function fixHitboxOnMap(p)
    if not savedata.registeredFilenames then
        return
    end

    if not savedata[p.idx] or not savedata[p.idx][p.character] then
        return
    end
    
    local stored = savedata.registeredFilenames
    local costumeName = pm.getCostume(p.character) or "__default"

    if stored[p.character] and stored[p.character][costumeName] then
        local iniFile = stored[p.character][costumeName][savedata[p.idx][p.character] .. "-ini"]

        if iniFile then
            Misc.loadCharacterHitBoxes(p.character, p.powerup, iniFile)
        end

        local imgFile = stored[p.character][costumeName][savedata[p.idx][p.character] .. "-img"]

        if imgFile then
            Graphics.sprites[pm.getName(p.character)][p.powerup].img = Graphics.loadImage(imgFile)
        end
    end
end

local function dropItem(id)
    if isOverworld or not id then
        return
    end

    if Graphics.getHUDType(player.character) == Graphics.HUD_ITEMBOX then
        player.reservePowerup = id
    else
        local n = NPC.spawn(
            id,
            camera.x + camera.width/2 - NPC.config[id].width/2,
            camera.y + 32,
            player.section
        )

        n:mem(0x138, FIELD_WORD, 2)
    end
end

local function initData(p)
    playerData[p.idx] = {
        currentPowerup = nil,
        oldPowerup = nil,
        newPowerup = nil,

        oldCharacter = p.character,
        assetLoaded = false,
        checkedThisFrame = false,
        inForcedState = false,
        currentForcedstate = 0,
        storedPos = nil,
    }

    savedata[p.idx] = savedata[p.idx] or {}
end

local function getPowerupReplacement(character, powerName)
    if not powerName then
        return nil
    end

    local replacement = blacklistedChars[character] or {}

    if type(replacement) == "string" then
        return replacement
    elseif replacement[powerName] ~= nil then
        return replacement[powerName]
    end

    return nil
end


----------------------------
-- External Use Functions --
----------------------------

-- makes a powerup made for anotherpowerup usable for custom powerup
function cp.convertApPowerup(lib)
    for k, field in ipairs(apFields) do
        if lib[field] then
            lib[apFieldsReplacement[k]] = lib[field]
            lib[field] = nil
        end
    end

    for character, img in pairs(lib.spritesheets) do
        lib.iniFiles[character] = lib.iniFiles[character] or Misc.resolveFile(pm.getName(character).."-"..lib.name..".ini")
    end

    lib._forceProjectileTimer = true
end

-- makes the powerup transform to the given powerup when the player is small
function cp.transformWhenSmall(id, replacement)
    transformations[id] = replacement
end

-- returns the current powerup
function cp.getCurrentPowerup(p)
    if not p then
        p = player
    end

    if p.idx <= 0 then
        return
    end

    return playerData[p.idx].currentPowerup
end

-- returns the name of the current powerup
function cp.getCurrentName(p)
    local currentPowerup = cp.getCurrentPowerup(p)

    if currentPowerup then
        return currentPowerup.name
    end

    return p.powerup
end

-- returns the id of the current powerup
function cp.getCurrentID(p)
    local currentPowerup = cp.getCurrentPowerup(p)

    if currentPowerup then
        return currentPowerup.id
    end

    return p.powerup
end

-- adds a item id or a list of ids to a powerup
function cp.addItem(name, items)
    if not name or not powerMap[name] then
        error("Powerup named '"..name.."' does not exist.")
    end

    local lib = powerMap[name]

    if type(items) == "number" then
        items = {items}
    end

    for k, v in ipairs(items) do
        if not itemMap[v] then
            table.insert(lib.items, v)
            itemMap[v] = name
        end
    end
end

-- adds a powerup, do not use the doConversion and id arguments
function cp.addPowerup(name, lib, items, doConversion, id)
    if type(name) == "table" then
        lib = name.lib
        items = name.items
        doConversion = name.doConversion
        id = name.id
        name = name.name
    end

    if not name then
        error("Invalid name for a powerup.", 2)
        return
    end

    local libPath = lib or name

    if type(libPath) ~= "string" then
        error("Invalid library path.", 2)
        return
    end

    lib = require(libPath)
    items = items or {}

    lib.name = name
    lib.id = id or (#powerNames + 7) -- for the default powerups
    
    lib.items = lib.items or {}
    lib.basePowerup = lib.basePowerup or PLAYER_FIREFLOWER
    lib.collectSounds = lib.collectSounds or lib.apSounds or {upgrade = 6, reserve = 12}
    lib.forcedStateType = lib.forcedStateType or cp.FORCEDSTATE_TYPE_NORMAL
    lib.dontGoToReserve = lib.dontGoToReserve or false

    lib._usesNormalMethod = (lib.spritesheets ~= nil or lib.iniFiles ~= nil)

    lib.spritesheets = lib.spritesheets or {}
    lib.iniFiles = lib.iniFiles or {}
    lib.gpImages = lib.gpImages or {}
    lib.cheats = lib.cheats or {}

    lib.registerAsset = registerAsset
    lib.getAsset = getAsset

    -- these are used to register powerup assets which can be replaced by costumes, "%s" is automatically replaced by the filename
    -- by default assets are checked in the "powerups" folder if no costume is active
    -- if a costume is active, the assets are checked in "costume/character/costumeName"
    lib.pathFormat = lib.pathFormat or "powerups/%s"
    lib.costumePathFormat = lib.costumePathFormat or "%s"

    table.insert(powerNames, name)
    powerMap[name] = lib

    if doConversion then
        cp.convertApPowerup(lib)
    end

    for k, v in ipairs(lib.items) do
        itemMap[v] = name
    end

    cp.addItem(lib.name, items)

    if lib.cheats[1] and lib.items[1] then
        local aliases = table.iclone(lib.cheats)

        table.remove(aliases, 1)

        Cheats.register(lib.cheats[1], {
            onActivate = (function() 
                dropItem(lib.items[1])
                return true
            end),

            activateSFX = 12,
            aliases = aliases,
        })
    end

    if lib.onInitPowerupLib then
        lib.onInitPowerupLib()
    end

    --[[
    if not isOverworld and not savedataCleared then
        savedata.powerupList = {}
        savedataCleared = true
    end

    if not isOverworld then
        table.insert(savedata.powerupList, {name = name, lib = libPath, items = items, doConversion = doConversion, id = id})
    end
    ]]

    return lib
end

-- sets the powerup
function cp.setPowerup(name, p, noEffects)
    if not p or p.idx <= 0 then
        return
    end

    local data = playerData[p.idx]
    local replacement = getPowerupReplacement(p.character, name)

    if replacement ~= nil then
        name = replacement
    end

    if not data or name == "__none__" then
        return
    end

    local lib = powerMap[name]
    local currentPowerup = data.currentPowerup
    local enablePowerup = false

    -- check if the powerup exists
    if type(name) ~= "number" and not lib then
        error("Powerup named '"..name.."' does not exist.", 2)
        return
    end

    -- return early if trying to set an already active powerup
    if currentPowerup and currentPowerup.name == name then
        if not noEffects then
            SFXPlay(currentPowerup, "reserve")
        end

        return
    end

    -- don't go in a forcedstate if the powerup doesn't want to
    if lib and lib.forcedStateType == cp.FORCEDSTATE_TYPE_NONE and not noEffects then
        SFXPlay(currentPowerup, "upgrade")
        noEffects = true
    end

    -- handle hitboxes
    if p.powerup == 1 and lib and lib.basePowerup > 1 then
        local ps1 = PlayerSettings.get(pm.getBaseID(p.character), 1)
        local ps2 = PlayerSettings.get(pm.getBaseID(p.character), 2)

        p.powerup = 2
        p.height = ps2.hitboxHeight
        p.y = p.y - (ps2.hitboxHeight - ps1.hitboxHeight)
    end

    -- handle powerup
    if not data.currentPowerup and lib and vanillaForcedStateTypes[p.powerup] == cp.FORCEDSTATE_TYPE_POOF and not noEffects and not data.inForcedState then
        p.powerup = 2
    end

    -- play effects
    if not noEffects then
        enablePowerup = true

        if not data.inForcedState then
            data.oldPowerup = cp.getCurrentName(p)
        end
    elseif not data.inForcedState then
        enablePowerup = true
    end

    -- disable the old custom powerup
    if currentPowerup then
        resetAssets(currentPowerup.basePowerup, p.character, p)

        if not data.inForcedState then
            callEvent(currentPowerup, "onDisable", p, noEffects)
        end
    end

    -- finally set the new powerup
    data.currentPowerup = lib
    currentPowerup = data.currentPowerup

    if lib then
        p.powerup = lib.basePowerup
        savedata[p.idx][p.character] = lib.name
        loadAssets(currentPowerup, p)
    else
        p.powerup = name
        savedata[p.idx][p.character] = nil

        if not (p.powerup == 2 and p.isMega) then
            resetAssets(p.powerup, p.character, p)
        end
    end

    if not noEffects and not data.inForcedState then
        data.newPowerup = cp.getCurrentName(p)
    end

    -- call the onEnable event and play effects
    if enablePowerup then
        if not noEffects then
            p.forcedState = cp.powerUpForcedState
            p.forcedTimer = 0
            data.storedPos = vector(p.x + p.width/2, p.y + p.height)
            data.inForcedState = true
            data.currentForcedstate = (lib and lib.forcedStateType) or vanillaForcedStateTypes[p.powerup]
            SFXPlay(currentPowerup, "upgrade")

            if data.currentForcedstate == cp.FORCEDSTATE_TYPE_POOF then
                p:mem(0x142, FIELD_BOOL, true)

                local e = Effect.spawn(10, p.x + p.width/2, p.y + p.height/2)
                e.x = e.x - e.width/2
                e.y = e.y - e.height/2
            end
        end

        callEvent(currentPowerup, "onEnable", p, noEffects)
    end
end

-- blacklists a character from using a powerup/all powerups, you can optionally specify a replacement powerup
function cp.blacklistCharacter(character, name, replacement)
    if name and type(blacklistedChars[character]) ~= "string" then
        blacklistedChars[character] = blacklistedChars[character] or {}
        blacklistedChars[character][name] = replacement or "__none__"
    else
        blacklistedChars[character] = replacement or "__none__"
    end
end

-- whitelists a character for using a powerup/all powerups
function cp.whitelistCharacter(character, name)
    if type(blacklistedChars[character]) == "string" then
        blacklistedChars[character] = nil
    elseif name then
        blacklistedChars[character][name] = nil
    end
end

-- returns the custom data table of the player
function cp.getData(idx)
    if idx then
        return playerData[idx]
    end

    return playerData
end

-- returns a list of powerup names
function cp.getNames()
    return powerNames
end

-- returns a table of powerup libraries indexed by names, if name is provided, it will return the powerup of that name
function cp.getPowerupByName(n)
    return powerMap[n]
end

-- returns a powerup by an item
function cp.getPowerupByItem(id)
    return itemMap[id]
end

-- checks if the current displayed powerup is the customPowerup
function cp.canDrawStuff(p)
    if not apdl then
        return true
    end

    local canDraw = (p.forcedState ~= apdl.customForcedState)

    if not canDraw then
        canDraw = (math.floor(p.forcedTimer / 5) % 2) == 0
    end

    return canDraw
end


-----------------------------
-- Compatibility Functions --
-----------------------------

-- These functions are here to have compatibility with powerups made from anotherpowerup.lua
-- Use their counterparts if you're not working with anotherpowerup

-- counterpart: cp.addPowerup(name, lib, items)
function cp.registerPowerup(name)
    cp.addPowerup(name, name, nil, true)
end

-- counterpart: cp.transformWhenSmall(id, replacement)
function cp.registerItemTier(id)
    cp.transformWhenSmall(id, 9)
end

-- counterpart: cp.setPowerup(name, p, noEffects)
function cp.setPlayerPowerup(appower, silent, thisPlayer)
    cp.setPowerup(appower.name, thisPlayer or player, silent)
end

-- counterpart: cp.getCurrentName(p)
function cp.getPowerup(p)
    cp.getCurrentName(p or player)
end


-----------------------
-- Local Functions --
-----------------------

local function handleChanges(p, data, currentPowerup)
    if data.checkedThisFrame then
        return
    end

    if p.isMega and currentPowerup then
        cp.setPowerup(2, p, true)
        currentPowerup = nil
    end
    
    if data.oldCharacter ~= p.character then
        if not isOverworld then
            if currentPowerup then
                resetAssets(currentPowerup.basePowerup, data.oldCharacter, p)
                callEvent(currentPowerup, "onDisable", p, true)
            end

            cp.setPowerup(savedata[p.idx][p.character] or p.powerup, p, true)
            currentPowerup = data.currentPowerup
            loadAssets(currentPowerup, p)
            callEvent(currentPowerup, "onEnable", p, true)

            data.oldCharacter = p.character
        else
            fixHitboxOnMap(p)
        end
    end

    local isInApdlForcedState = false

    if apdl then
        isInApdlForcedState = p.forcedState == apdl.customForcedState
    end

    if currentPowerup and p.powerup ~= currentPowerup.basePowerup and not isInApdlForcedState --[[and p.forcedState == 0 and p.deathTimer == 0]] then
        cp.setPowerup(p.powerup, p, true)
    end

    data.checkedThisFrame = true
end

local function exitForcedState(p, data)
    cp.setPowerup(data.newPowerup, p, true)

    data.oldPowerup = nil
    data.newPowerup = nil
    data.assetLoaded = false
    data.inForcedState = false
    data.currentForcedstate = 0
    data.storedPos = nil

    p.forcedState = 0
    p.forcedTimer = 0
    p:mem(0x140, FIELD_WORD, 50)
end


-- REMOVE AT YOUR OWN RISK
for char = 11, 16 do
    cp.blacklistCharacter(char)
end


-----------------------
-- Library Functions --
-----------------------

-- register events
function cp.onInitAPI()
    registerEvent(cp, "onStart")
    registerEvent(cp, "onDraw")
    registerEvent(cp, "onDrawEnd")

    if not isOverworld then
        registerEvent(cp, "onTick")
        registerEvent(cp, "onTickEnd")
        registerEvent(cp, "onNPCCollect", "onNPCCollect", false)
        registerEvent(cp, "onBlockHit")
        registerEvent(cp, "onPostPlayerKill")
        registerEvent(cp, "onExitLevel")
    end
end

-- code to allow respawnRooms use a custom powerup as the respawn powerup
function respawnRooms.onPreReset(fromRespawn)
    local power = cp.getPowerupByName(respawnRooms.respawnSettings.respawnPowerup)

    if power and fromRespawn then
        cp.setPowerup(power.name, player, true)
        storedPowerupName = power.name
        respawnRooms.respawnSettings.respawnPowerup = power.basePowerup
    end
end

function respawnRooms.onPostReset(fromRespawn)
    if storedPowerupName and fromRespawn then
        respawnRooms.respawnSettings.respawnPowerup = storedPowerupName
    end
end


-- force powerups to mushrooms
function cp.onBlockHit(e, v, upper, p)
    local nextID = transformations[v.contentID - 1000]
    
    if e.cancelled or not nextID or v.data._custom_alreadyCancelled then
        return
    end

    if not p then
        for _, n in NPC.iterateIntersecting(v.x - 1, v.y - 1, v.x + v.width + 1, v.y + v.height + 1) do
			if n:mem(0x132,FIELD_WORD) > 0 and n.isProjectile then
				p = Player(n:mem(0x132,FIELD_WORD))
                break
			end
		end
    end

    p = p or player

    if p.powerup == 1 then
        local oldContentID = v.contentID
		v.contentID = nextID + 1000
        v.data._custom_alreadyCancelled = true
        v:hit(upper, p)
        e.cancelled = true
	end
end


-- carry powerups between levels
function cp.onStart()
    --[[
    if isOverworld and savedata.powerupList then
        for k, args in ipairs(savedata.powerupList) do
            cp.addPowerup(args)
        end
    end
    ]]

    if isOverworld and savedata.registeredFilenames then
        Routine.run(function()
            Routine.skip()
            local stored = savedata.registeredFilenames

            for _, p in ipairs(Player.get()) do
                if savedata[p.idx] then
                    for char, powerName in pairs(savedata[p.idx]) do
                        local costumeName = pm.getCostume(char) or "__default"

                        if stored[char] and stored[char][costumeName] then
                            local iniFile = stored[char][costumeName][savedata[p.idx][char] .. "-ini"]
                            local imgFile = stored[char][costumeName][savedata[p.idx][char] .. "-img"]

                            if iniFile then
                                Misc.loadCharacterHitBoxes(char, p.powerup, iniFile)
                            end

                            Graphics.sprites[pm.getName(char)][p.powerup].img = Graphics.loadImage(imgFile)
                        end
                    end
                end
            end
        end)
    end

    for _, p in ipairs(Player.get()) do
        initData(p)

        if Misc.inEditor() then
            savedata[p.idx] = {}
        end

        if not isOverworld and savedata[p.idx][p.character] then
            cp.setPowerup(savedata[p.idx][p.character], p, true)
        end
    end
end

-- data initialization and forced state mangement
function cp.onTick()
    for _, p in ipairs(Player.get()) do
        if not playerData[p.idx] then
            initData(p)
        end

        local data = playerData[p.idx]
        local currentPowerup = data.currentPowerup

        callEvent(currentPowerup, "onTickPowerup", p)

        if (currentPowerup and currentPowerup._forceProjectileTimer and p.mount < 2) or p.forcedState == cp.powerUpForcedState then
            if p.character ~= CHARACTER_LINK then
                p:mem(0x160, FIELD_WORD, 3)
            else
                p:mem(0x162, FIELD_WORD, 29)
            end
        end

        if p.forcedState == cp.powerUpForcedState then
            p.forcedTimer = p.forcedTimer + 1

            local canExit = forcedStateFuncs[data.currentForcedstate](p, data, p.forcedTimer)

            if data.storedPos then
                p.x = data.storedPos.x - p.width/2
                p.y = data.storedPos.y - p.height
            end

            if canExit or p.isMega then
                exitForcedState(p, data)
            end
        end

        handleChanges(p, data, currentPowerup)
    end
end

-- character/powerup changes
function cp.onTickEnd()
    for _, p in ipairs(Player.get()) do
        local data = playerData[p.idx]
        
        if data then
            local currentPowerup = data.currentPowerup

            if p.forcedState == cp.powerUpForcedState and data.currentForcedstate == cp.FORCEDSTATE_TYPE_POOF then
                p:mem(0x142, FIELD_BOOL, true)
            end

            callEvent(currentPowerup, "onTickEndPowerup", p)

            handleChanges(p, data, currentPowerup)
        end
    end
end

-- character/powerup changes
function cp.onDrawEnd()
    for _, p in ipairs(Player.get()) do
        local data = playerData[p.idx]
        
        if data then
            handleChanges(p, data, data.currentPowerup)
        end
    end
end

-- test mode menu and overworld
function cp.onDraw()
    for _, p in ipairs(Player.get()) do
        local data = playerData[p.idx]

        if data then
            local currentPowerup = data.currentPowerup

            -- Fight test mode menu
            if currentPowerup and ((testModeMenu ~= nil and (testModeMenu.active or (not testModeMenu.active and testMenuWasActive))) or lunatime.tick() == 1 or lunatime.drawtick() == 1) then
                loadAssets(currentPowerup, p)
            end

            data.checkedThisFrame = false

            if isOverworld then
                if isOverworld and (Misc.isPaused() or (not Misc.isPaused() and wasPaused) or (Misc.isPaused() and not wasPaused) or not mapAssetsLoaded[p.character]) then
                    mapAssetsLoaded[p.character] = true
                    fixHitboxOnMap(p)
                end

                -- why not?
                callEvent(currentPowerup, "onDrawPowerupOverworld", p)
            else
                callEvent(currentPowerup, "onDrawPowerup", p)
            end
        end

        --[[
        Text.print("vanilla: "..p:mem(0x46, FIELD_WORD), 0, 0)
        Text.print(cp.getCurrentID(p), 0, 30)
        Text.print(savedata[p.idx][p.character],0,60)

        Graphics.drawBox{
            x = p.x, y = p.y,
            width = p.width,
            height = p.height,
            sceneCoords = true,
            color = Color.blue..0.5,
        }
        ]]
    end

    if testModeMenu ~= nil then
        testMenuWasActive = testModeMenu.active
    end

    wasPaused = Misc.isPaused()
end

local function setReserveItem(p, id)
    -- given item is a mushroom
    if defaultItemMap[id] == PLAYER_BIG then
        if p.reservePowerup == 0 then
            p.reservePowerup = id
        end

        return
    end

    -- given item is not a mushroom, you can override
    p.reservePowerup = id
end

-- item collection stuff
function cp.onNPCCollect(e, v, p)
    if not playerData[p.idx] or e.cancelled then
        return
    end

    if v.data._custom_thing then
        return
    end

    if p.isMega then
        if itemMap[v.id] and v:mem(0x138, FIELD_WORD) ~= 2 then
            Misc.givePoints(NPC.config[v.id].score, vector(p.x, p.y), true)
        end

        return
    end

    local data = playerData[p.idx]
    local currentPowerup = cp.getCurrentPowerup(p)
    local vanillaPower = defaultItemMap[v.id]
    local powerName = itemMap[v.id]
    local initalStateItem = p:mem(0x46, FIELD_WORD)
    local resetReservePowerup = false

    -- this was running for each collectible
    -- somehow this didn't break anything. bruh.
    if not powerName and not vanillaPower then
        return
    end

    -- handle replacements
    if getPowerupReplacement(p.character, powerName) == "__none__" then
        return
    end

    -- a powerup doesn't want to go to the basegame
    if powerName and cp.getPowerupByName(powerName).dontGoToReserve then
        cp.setPowerup(powerName, p)

        if p:mem(0x46, FIELD_WORD) > 0 then
            setReserveItem(p, p:mem(0x46, FIELD_WORD))
        end

        p:mem(0x46, FIELD_WORD, 0)
        p:mem(0x16, FIELD_WORD, p:mem(0x16, FIELD_WORD) + 1)

        if v:mem(0x138, FIELD_WORD) ~= 2 then
            Misc.givePoints(NPC.config[v.id].score, vector(p.x, p.y), true)
        end

        return
    end

    local powerID = cp.getCurrentName(p)

    if not currentPowerup and defaultItemMap[initalStateItem] ~= powerID then
        initalStateItem = defaultPowerupMap[powerID]
    elseif currentPowerup and itemMap[initalStateItem] ~= powerID and not currentPowerup.dontGoToReserve then
        initalStateItem = currentPowerup.items[1] or 0
    end

    p:mem(0x46, FIELD_WORD, initalStateItem)

    -- check if the npc collected sets the player's powerup to the base powerup of the current custom powerup
    if currentPowerup and vanillaPower--[[ == currentPowerup.basePowerup]] and vanillaPower ~= PLAYER_BIG then
        e.cancelled = true

        -- prevent the reserve item sfx from playing and also handle reserve box stuff
        local oldMuted = Audio.sounds[12].muted
        local oldReservePowerup = p.reservePowerup

        Audio.sounds[12].muted = true
        v.data._custom_thing = true
        v:collect(p)
        p.reservePowerup = oldReservePowerup

        if vanillaPower == currentPowerup.basePowerup then
            if vanillaPower == PLAYER_LEAF or vanillaPower == PLAYER_TANOOKIE then
                SFX.play(34)
            else
                SFX.play(6)
            end
        end

        p:mem(0x46, FIELD_WORD, initalStateItem)
        Audio.sounds[12].muted = oldMuted
    end

    local newPowerup = (vanillaPower or powerName)

    if data.inForcedState and newPowerup and newPowerup ~= data.newPowerup then
        exitForcedState(p, data)
    end

    -- prevent the vanilla forced states to take effect if we have a customPowerup
    if currentPowerup and vanillaPower and vanillaPower ~= PLAYER_BIG then
        p.forcedState = 0
        p.forcedTimer = 0
        cp.setPowerup(vanillaPower, p)

        if currentPowerup.dontGoToReserve and p.reservePowerup == 0 then
            resetReservePowerup = true
        end
    end

    -- update hearts and state item
    if vanillaPower or powerName then
        if Graphics.getHUDType(p.character) == Graphics.HUD_HEARTS and not vanillaPower then
            p:mem(0x16, FIELD_WORD, p:mem(0x16, FIELD_WORD) + 1)
        end

        if vanillaPower == PLAYER_BIG and p.powerup == 1 then
            p:mem(0x46, FIELD_WORD, v.id)

        elseif vanillaPower ~= PLAYER_BIG then
            if p.powerup > 1 and p:mem(0x46, FIELD_WORD) > 0 then
                setReserveItem(p, p:mem(0x46, FIELD_WORD))
            end

            p:mem(0x46, FIELD_WORD, v.id)
        end
    end

    -- set the player's powerup
    if powerName then
        if p.powerup == PLAYER_BIG and initalStateItem == 0 and p.reservePowerup == 0 then
            p.reservePowerup = 9
        end

        if not data.inForcedState then
            p.forcedState = 0
            cp.setPowerup(powerName, p)

            local thisPowerup = cp.getCurrentPowerup(p)

            if thisPowerup.dontGoToReserve then
                p:mem(0x46, FIELD_WORD, 0)
            else
                p:mem(0x46, FIELD_WORD, v.id)
            end
        end

        if v:mem(0x138, FIELD_WORD) ~= 2 then
            Misc.givePoints(NPC.config[v.id].score, vector(p.x, p.y), true)
        end
    end

    if p.reservePowerup ~= 0 then
        Routine.run(function()
            local oldReservePowerup = p.reservePowerup
            Routine.skip()
            p.reservePowerup = oldReservePowerup
        end)
    end

    if resetReservePowerup then
        p.reservePowerup = 0

        Routine.run(function()
            Routine.skip()
            p.reservePowerup = 0
        end)
    end
end

-- reset state item on death
function cp.onPostPlayerKill(p)
    p:mem(0x46, FIELD_WORD, 0)
end

-- reset powerup if in mario challenge
function cp.onExitLevel(w)
    savedata.registeredFilenames = registeredFilenames

    if Misc.inMarioChallenge() then
        for k, p in ipairs(Player.get()) do
            if cp.getCurrentPowerup(p) ~= nil then
                cp.setPowerup(2, p, true)
            end
        end

        return
    end
end

-- handle assets when a character changes their costume
function pm.onCostumeChange(character, costumeName)
    for _, p in ipairs(Player.get()) do
        if p.character == character and playerData[p.idx] then
            loadAssets(playerData[p.idx].currentPowerup, p)
        end
    end
end

return cp