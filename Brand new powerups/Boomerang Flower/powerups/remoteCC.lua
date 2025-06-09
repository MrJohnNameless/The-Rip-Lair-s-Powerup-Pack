-- [[ Presented by Novarender ]] --
-- [[  Remote Coin Collection ]] --
-- [[ For all your greedy needs! Wah hah ha! ]] ==

local starcoin = require("npcs/ai/starcoin")

local rCC = {credits = "Novarender", version = "v1.1"}

rCC.givesLivesAt = 100 --Coin value to get another life at. Resets coin count when that happens. Set to false to disable
rCC.capCoins = false   --Caps coins at this value. Set to false to disable. Can override givesLivesAt; not necessary if givesLivesAt is set.
--Note: These options only affect coins or lives granted by this script itself. Supernova Services and co. will not be held liable for any coins or lives granted using a third party source.

rCC.coin = table.map{10, 33, 88, 103, 138, 152, 251, 252, 253, 258, 274, 310, 378} --All coins that can be collected by this script. I didn't include bonus items like Cherries or Minigame Coins.
rCC.blueCoin  = table.map{252, 258}
rCC.redCoin   = table.map{253}  --The kind that gives 20 coins
rCC.rupee     = table.map{251, 252, 253}
rCC.sonicRing = table.map{152}
rCC.yoshiCoin = table.map{274}
rCC.starcoin  = table.map{310}
rCC.dashcoin  = table.map{378}

local ADR_COINS = 0x00B2C5A8
local ADR_LIVES = 0x00B2C5AC

rCC.activeDashCoins = {} --I had to simulate dash coins because whyy x2 gang
function rCC.onInitAPI()
    registerEvent(rCC, "onTickEnd")
end

local function memCoins(val) --Get coin count + can set coin count to 'val'
    if val then
        mem(ADR_COINS, FIELD_WORD, val)
        return val
    end
    return mem(ADR_COINS, FIELD_WORD)

    --Old version with memCoins(val, add) --Sets value if add is false
        -- local current = mem(ADR_COINS, FIELD_WORD)
        -- if val then
        --     if add then
        --         current = current + val
        --     else
        --         current = val
        --     end
        --     mem(ADR_COINS, FIELD_WORD, current)
        -- end
        -- return current
end
local function memLives(val) --Get life counter + can increase lives by 'val'
    if val then
        mem(ADR_LIVES, FIELD_FLOAT, mem(ADR_LIVES, FIELD_FLOAT) + val)
    end
    return mem(ADR_LIVES, FIELD_FLOAT)
end
local function tablify(val)
    if type(val) ~= "table" then
        val = {val}
    end
    return val
end

function rCC.giveCoins(amt) --Returns new coin count
    local count = memCoins() + amt

    if rCC.capCoins and count > rCC.capCoins then
        count = math.max(count - amt, rCC.capCoins)  --Keeps coin count if it was over the limit beforehand (from another source)
    end
    if rCC.givesLivesAt and count >= rCC.givesLivesAt then
        memLives(math.floor(count/rCC.givesLivesAt)) --Works with any hundred coins (update: no longer goes by hundreds, but a custom value)
        count = memCoins(count % rCC.givesLivesAt)
        SFX.play(15) --1up
    end

    memCoins(count)
    return count
end
function rCC.canCollectCoin(v)
    return v.isValid and rCC.coin[v.id] and not v.isHidden and not v.friendly and not v:mem(0x64, FIELD_BOOL) and v:mem(0x138, FIELD_WORD) == 0 and v:mem(0x122, FIELD_WORD) == 0 --Last three: Isn't a generator, is not in a container, is not already dead. The last one is due to a glitch related to time stop where the NPC doesn't fully register as dead.
end
function rCC.collectDashCoin(v)
    v:transform(v.ai1 or NPC.config[v.id].defaultcontents, true, true)
    SFX.play(29)
    v.speedX = 0
    v.speedY = 0  
end
function rCC.simDashCoin(v, w) --Assumes v can be collected. w is an object (or objects) that can intersect with it, preventing it from transforming yet. [optional; leave blank to instantly turn to a coin]
    if not v.data.dashSim then
        v.data.dashSim = {}
    end
    local d = v.data.dashSim
    
    if not w then
        rCC.collectDashCoin(v)
        return
    end

    if not d.intersecting then
        d.intersecting = true

        if type(w) ~= "table" then
            w = {w}
        end

        local coin = {npc = v, collectors = w}
        table.insert(rCC.activeDashCoins, coin)
    end
end

function rCC.collect(v, w) --w is the object collecting the coin; optional (used mainly for dash coin)
    if not rCC.canCollectCoin(v) then return end
    local d = v.data
    local c = NPC.config[v.id]

    if rCC.dashcoin[v.id] then --Dash/popup coins
        rCC.simDashCoin(v, w)
        return
    end

    if rCC.starcoin[v.id] then --Starcoins do their own thing
        starcoin.collect(v)
    else
        local amount = 0
        
        if rCC.redCoin[v.id] then            --Red rupee
            amount = Defines.coin20Value
        elseif rCC.blueCoin[v.id] then       --Blue coins/rupees
            amount = Defines.coin5Value
        elseif not rCC.yoshiCoin[v.id] then  --All other coins that actually give coins
            amount = Defines.coinValue
        end
        rCC.giveCoins(amount)

        local points = 1
        if rCC.yoshiCoin[v.id] then
            points = c.score --jank!!
            c.score = c.score + 1 --Replicate basegame point combo
            if c.score > 14 then
                c.score = 14
            end
        end
        
        Misc.givePoints(points, {x = v.x+v.width/2, y = v.y+v.height/2}, true)
        
        if rCC.rupee[v.id] then
            SFX.play(81)
        elseif rCC.sonicRing[v.id] then
            SFX.play(56)
        elseif rCC.yoshiCoin[v.id] then
            SFX.play(59)
        else
            SFX.play(14) --Coin noises intensifies
        end
        
        Effect.spawn(78, v.x+v.width/2, v.y+v.height/2)
    end
    
    v:kill()
end

function rCC.onTickEnd() --Time to simulate some pop up coins...
    if Defines.levelFreeze then return end
        
    for k = #rCC.activeDashCoins, 1, -1 do
        local v = rCC.activeDashCoins[k]

        local collides
        for _,w in ipairs(v.collectors) do 
            if Colliders.collide(v.npc, w) then --Any colliding?                                    going once going twice
                collides = true --Get outta here!                                                                                                                       sold to the guy with a mustache!
                break
            end
        end
        if not collides then
            v.npc.data.dashSim = {}
            rCC.collectDashCoin(v.npc)
            table.remove(rCC.activeDashCoins, k)
        end
    end
end

return rCC --All done!