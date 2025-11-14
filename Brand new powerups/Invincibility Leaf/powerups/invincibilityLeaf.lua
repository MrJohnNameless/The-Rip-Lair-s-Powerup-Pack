local leaf = {}
local cp = require("customPowerups")

local activePlayer
local checkedForLevelEnd = false

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function leaf.onInitPowerupLib()
	leaf.spritesheets = {
		leaf:registerAsset(1, "invincibilityLeaf-mario.png"),
		leaf:registerAsset(2, "invincibilityLeaf-luigi.png"),
		leaf:registerAsset(3, "invincibilityLeaf-peach.png"),
		leaf:registerAsset(4, "invincibilityLeaf-toad.png"),
	}
end

leaf.basePowerup = PLAYER_LEAF
leaf.forcedStateType = 2

leaf.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

registerEvent(leaf, "onExit", "onExit")

function leaf.onExit()
	if activePlayer and cp.getCurrentName(activePlayer) == "Invincibility Leaf" then cp.setPowerup(4, activePlayer, true) end
end

function leaf.onEnable(p)
end

function leaf.onDisable(p)
end

leaf.ignore = {};
leaf.ignore[108] = true;

local function starmanFilter(v)
	return Colliders.FILTER_COL_NPC_DEF(v) and not leaf.ignore[v.id];
end

function leaf.onTickPowerup(p)
	p:mem(0x140, FIELD_WORD, 2);
	p:mem(0x142, FIELD_WORD, 0);
	activePlayer = p
	
	for _,v in ipairs(Colliders.getColliding{a = p, b = NPC.HITTABLE, btype = Colliders.NPC, filter = starmanFilter, collisionGroup = p.collisionGroup}) do
		v:harm(HARM_TYPE_EXT_HAMMER);
	end
end

function leaf.onInitAPI()
    registerEvent(leaf, "onTick")
    cp = require("customPowerups")
end

function leaf.onTick()
    if checkedForLevelEnd then return end

    if Level.endState() ~= 0 then
        checkedForLevelEnd = true

        for _, p in ipairs(Player.get()) do
            if cp.getCurrentPowerup(p) == leaf then
                cp.setPowerup(4, p, true)

                for i = 1, 10 do
                    local e =  Effect.spawn(80, p.x - 8 + RNG.random(p.width + 8), p.y - 4 + RNG.random(p.height + 8))
                    e.speedX = RNG.random(6) - 3
                    e.speedY = RNG.random(6) - 3
                end
            end
        end
    end
end

return leaf