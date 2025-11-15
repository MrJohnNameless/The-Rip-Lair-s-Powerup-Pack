local leaf = {}
local cp = require("customPowerups")

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

local powerupRevert = require("powerupRevert")
powerupRevert.register(leaf.name, leaf.basePowerup)

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
	
	for _,v in ipairs(Colliders.getColliding{a = p, b = NPC.HITTABLE, btype = Colliders.NPC, filter = starmanFilter, collisionGroup = p.collisionGroup}) do
		v:harm(HARM_TYPE_EXT_HAMMER);
	end
end

return leaf