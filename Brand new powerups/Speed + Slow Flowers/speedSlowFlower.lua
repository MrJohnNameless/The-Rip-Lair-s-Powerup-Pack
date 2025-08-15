local slowAndSpeed = {}

local afterimages
pcall(function() afterimages = require("afterimages") end)

slowAndSpeed.allFlowersMap = {}

slowAndSpeed.slowFlowerMap = {}
slowAndSpeed.speedFlowerMap = {}

function slowAndSpeed.register(npcID, isSpeedFlower)
        slowAndSpeed.allFlowersMap[npcID] = true

        if isSpeedFlower then
                slowAndSpeed.speedFlowerMap[npcID] = true
        else
                slowAndSpeed.slowFlowerMap[npcID] = true
        end
end

local originalSpeed = nil
local ogMusicSpeed = nil
local ogMusicTempo = nil

local oldScore = 0
local oldCoins = 0

local timer = 0
local timerSpeed = 1

local speedDir = 0

-- -1 = Slowed down, 0 = normal, 1 = Speed up

-- Taken from MDA's Big Coins
local coinsPointer = 0x00B2C5A8
local livesPointer = 0x00B2C5AC

local function addCoins(amount)
    	mem(coinsPointer,FIELD_WORD,(mem(coinsPointer,FIELD_WORD)+amount))

    	if mem(coinsPointer,FIELD_WORD) >= 100 then
        	if mem(livesPointer,FIELD_FLOAT) < 99 then
            		mem(livesPointer,FIELD_FLOAT,(mem(livesPointer,FIELD_FLOAT)+math.floor(mem(coinsPointer,FIELD_WORD)/100)))
            		SFX.play(15)

            		mem(coinsPointer,FIELD_WORD,(mem(coinsPointer,FIELD_WORD)%100))
        	else
            		mem(coinsPointer,FIELD_WORD,99)
        	end
    	end
end

function slowAndSpeed.onInitAPI()
	registerEvent(slowAndSpeed, "onTick")
	registerEvent(slowAndSpeed, "onNPCCollect")
        registerEvent(slowAndSpeed, "onExitLevel")
        registerEvent(slowAndSpeed, "onPlayerKill")
end

function slowAndSpeed.slowDownTime()
        if speedDir == 0 then 
                originalSpeed = Misc.GetEngineSpeed()

                if Audio.MusicGetSpeed() ~= -1 then ogMusicSpeed = Audio.MusicGetSpeed() end
                if Audio.MusicGetTempo() ~= -1 then ogMusicTempo = Audio.MusicGetTempo() end
        end

        Misc.SetEngineSpeed(0.5)

        speedDir = -1
        timer = 750
        timerSpeed = 2
end

function slowAndSpeed.speedUpTime()
        if speedDir == 0 then 
                originalSpeed = Misc.GetEngineSpeed()

                if Audio.MusicGetSpeed() ~= -1 then ogMusicSpeed = Audio.MusicGetSpeed() end
                if Audio.MusicGetTempo() ~= -1 then ogMusicTempo = Audio.MusicGetTempo() end
        end

        Misc.SetEngineSpeed(2)

        speedDir = 1
        timer = 750
        timerSpeed = 0.5
end

function slowAndSpeed.resetStuff()
        speedDir = 0
        timer = 0
        timerSpeed = 1
end

function slowAndSpeed.onTick()
        timer = timer - timerSpeed

	-- Timer stuff
        if timer == 20 then SFX.play("smw-runout.ogg") end
        if speedDir ~= 0 and timer <= 0 then 
                slowAndSpeed.resetStuff()
                SFX.play(34)
                for k,p in ipairs(Player.get()) do
                        local e = Effect.spawn(131,p.x + p.width*0.5,p.y + p.height*0.5)
                        e.x = e.x - e.width*0.5
                        e.y = e.y - e.height*0.5
                end
        end

	-- Manage music
        if speedDir == -1 then
                if Audio.MusicGetSpeed() ~= -1 then Audio.MusicSetSpeed(0.75) end
                if Audio.MusicGetTempo() ~= -1 then Audio.MusicSetTempo(0.75) end
        elseif speedDir == 1 then
                if Audio.MusicGetSpeed() ~= -1 then Audio.MusicSetSpeed(1.5) end
                if Audio.MusicGetTempo() ~= -1 then Audio.MusicSetTempo(1.5) end
        else    
                if originalSpeed ~= nil then
                        Misc.SetEngineSpeed(originalSpeed)
                        originalSpeed = nil
                end
                if ogMusicSpeed ~= nil then
                        Audio.MusicSetSpeed(ogMusicSpeed)
                        ogMusicSpeed = nil
                end
                if ogMusicTempo ~= nil then
                        Audio.MusicSetTempo(ogMusicTempo)
                        ogMusicTempo = nil
                end
        end

	-- Triple points and coins
	if speedDir ~= 0 then
		if Misc.score() ~= oldScore then
			local scoreDiff = (Misc.score() - oldScore)
			Misc.score(scoreDiff * 2)
			oldScore = Misc.score()
		end

		if Misc.coins() ~= oldCoins then
			local coinsDiff = (Misc.coins() - oldCoins)
			addCoins(coinsDiff * 2)
			oldCoins = Misc.coins()
		end
	else
		oldScore = Misc.score()
		oldCoins = Misc.coins()
	end

	-- Afterimages!
        if afterimages then
                for k,p in ipairs(Player.get()) do
			if p.frame ~= -50 * p.direction then
                        	if speedDir == -1 then
                                	afterimages.create(p, 20, Color.fromHexRGB(0x48B8D0), true, -49)
                        	elseif speedDir == 1 then
                                	afterimages.create(p, 20, Color.fromHexRGB(0xC80058), true, -49)
                        	end
			end
                end
        end
end

-- Reset stuff
function slowAndSpeed.onExitLevel()
        if speedDir ~= 0 then slowAndSpeed.resetStuff() end
end

function slowAndSpeed.onPlayerKill()
        if speedDir ~= 0 then slowAndSpeed.resetStuff() end
end

function slowAndSpeed.onNPCCollect(eventObj, v, player)
        if not slowAndSpeed.allFlowersMap[v.id] then return end

        local e = Effect.spawn(131,v.x + v.width*0.5,v.y + v.height*0.5)
        e.x = e.x - e.width*0.5
        e.y = e.y - e.height*0.5
        SFX.play(34)

	if slowAndSpeed.slowFlowerMap[v.id] then
                if speedDir == 0 then
                        slowAndSpeed.slowDownTime()
                elseif speedDir == 1 then
                        slowAndSpeed.resetStuff()
                end
        elseif slowAndSpeed.speedFlowerMap[v.id] then
                if speedDir == 0 then
                        slowAndSpeed.speedUpTime()
                elseif speedDir == -1 then
                        slowAndSpeed.resetStuff()
                end
        end
end

return slowAndSpeed