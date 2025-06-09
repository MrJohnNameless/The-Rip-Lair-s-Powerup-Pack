local inverted = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function inverted.onInitPowerupLib()
    inverted.spritesheets = {
        inverted:registerAsset(1, "inverted-mario.png"),
        inverted:registerAsset(2, "inverted-luigi.png"),
        inverted:registerAsset(3, "inverted-peach.png"),
        inverted:registerAsset(4, "inverted-toad.png"),
        inverted:registerAsset(5, "inverted-link.png"),
    }

    inverted.gpImages = {
        inverted:registerAsset(CHARACTER_MARIO, "inverted-groundPound-1.png"),
        inverted:registerAsset(CHARACTER_LUIGI, "inverted-groundPound-2.png"),
    }
end

inverted.basePowerup = PLAYER_BIG

inverted.collectSounds = {
    upgrade = SFX.open(Misc.resolveSoundFile("powerups/player-grow-reversed")),
    reserve = SFX.open(Misc.resolveSoundFile("powerups/has-item-reversed")),
}

function inverted.onEnable(p)
end

function inverted.onDisable(p)
end

function inverted.onTickPowerup(p)
	p.keys.left = KEYS_UP
	p.keys.right = KEYS_UP
	
	if p.rawKeys.right == KEYS_DOWN then p.keys.left = KEYS_DOWN end
	if p.rawKeys.left == KEYS_DOWN then p.keys.right = KEYS_DOWN end
end

return inverted