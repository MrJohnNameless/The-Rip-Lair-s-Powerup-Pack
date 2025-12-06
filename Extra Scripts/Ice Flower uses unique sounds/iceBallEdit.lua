local iceBall = {}

function iceBall.onInitAPI()
	registerEvent(iceBall, "onTick")
end

function iceBall.onTick()
	for _,p in ipairs(Player.get()) do
		if p.powerup == 7 then
			Audio.sounds[18].muted = true
			if p:mem(0x118,FIELD_FLOAT) == 111 or p:mem(0x50, FIELD_BOOL) and p:mem(0x160, FIELD_WORD) == 29 then
				SFX.play("iceball.ogg")
			end
		else
			Audio.sounds[18].muted = false
		end
	end
end

return iceBall