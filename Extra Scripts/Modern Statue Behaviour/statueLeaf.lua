local statueLeaf = {}

statueLeaf.hoverLimit = 12
--statueLeaf.SFX = Misc.resolveSoundFile("metalPipe.ogg")
statueLeaf.SFX = 37
statueLeaf.SFXPlayDelay = 1

statueLeaf.luigiChars = table.map{2,8,13} --actually used in code
statueLeaf.marioChars = table.map{1,7,15} --the rest are for in case someone is using any custom player libraries
statueLeaf.peachChars = table.map{3,10,11}
statueLeaf.toadChars = table.map{4,6,9,14}
statueLeaf.linkChars = table.map{5,12,16}

local function isOnGround(p)
    return (
        p:isGroundTouching()
        or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
        or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
    )
end

function statueLeaf.onInitAPI()
	registerEvent(statueLeaf, "onTick")
end

function statueLeaf.onTick()
	for _,p in ipairs(Player.get()) do
		local data = p.data
		if data.statueLeaf == nil then --Set up some data variables
			data.statueLeaf = {
				hasPlayedSFX = false,
				hasSpawnedEffects = false,
		        SFXDelay = 0,
			}
		end

		--Actual code below
		if p.powerup == PLAYER_TANOOKI and p:mem(0x4A,FIELD_BOOL) then -- if a player is a STATUE
            p.speedX = 0 --No horizontal movement
            if p:mem(0x4E,FIELD_WORD) <= statueLeaf.hoverLimit then -- timer for being a STATUE
				--Float in the air, but it's different because Redigit
                if p.character == statueLeaf.luigiChars[p.character] then
                    p.speedY = -Defines.player_grav * 0.8
                else
                    p.speedY = -Defines.player_grav
                end
            else
				--Slam to the floor
				if p.keys.altRun == KEYS_UP or p.keys.altRun == KEYS_UNPRESSED then
					--This is how the source code did it, so I did it too for consistancy
					if p.speedY < 8 then
						p.speedY = p.speedY + 0.25
					end
				end
            end

			--Some extra stuff
            if isOnGround(p) then
				if not data.statueLeaf.hasSpawnedEffects then --Spawn effects
					for i = -1, 1, 2 do
						local offset = 0
						if i == 1 then
							offset = -32
						end
						local smoke = Effect.spawn(10,p.x+((p.width/2)+offset),p.y+p.height-16)
						smoke.speedX = 3*i
						smoke.speedY = 0
					end
					data.statueLeaf.hasSpawnedEffects = true
				end

                if data.statueLeaf.hasPlayedSFX == false then
                    data.statueLeaf.SFXDelay = data.statueLeaf.SFXDelay + 1
                    if data.statueLeaf.SFXDelay >= statueLeaf.SFXPlayDelay then
                        SFX.play(statueLeaf.SFX)
                        data.statueLeaf.hasPlayedSFX = true
                    end
                end
			else
				data.statueLeaf.SFXDelay = 0
				data.statueLeaf.hasPlayedSFX = false
				data.statueLeaf.hasSpawnedEffects = false
            end
		else
			data.statueLeaf.SFXDelay = 0
			data.statueLeaf.hasPlayedSFX = false
			data.statueLeaf.hasSpawnedEffects = false
        end
	end
end

return statueLeaf