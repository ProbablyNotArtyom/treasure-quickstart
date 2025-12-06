-------------------------------------------------------------------------------------------------
-- Treasure QuickStart
-------------------------------------------------------------------------------------------------

local json = require("json")										-- Load JSON for MCM
local TreasureQuickstart = RegisterMod("Treasure QuickStart", 1)	-- Register mod

-- Callback for MC_POST_GAME_STARTED
function TreasureQuickstart:start()
	local player = Isaac.GetPlayer()
	local level = Game():GetLevel()

	-- Room type to search for, as set by the MCM
	local roomType = (TreasureQuickstart.settings.mode == 1) and RoomType.ROOM_TREASURE or RoomType.ROOM_PLANETARIUM
	-- If current run is a challenge
	local isChallenge = (Isaac.GetChallenge() ~= 0) and true or false
	-- If current run is a custom seed
	local isSeeded = (Isaac.GetChallenge() == 0 and Game():GetSeeds():IsCustomRun()) and true or false

	-- Check if current floor has a room of a certain type
	local function hasRoom(level, type)
		local rooms = Game():GetLevel():GetRooms()
		for i = 0, #rooms - 1 do
			if (rooms:Get(i).Data.Type == type) then
				return true
			end
		end

		return false
	end

	if TreasureQuickstart.settings.enabled == true and						-- If mod is enabled through MCM
	isSeeded == false and													-- If not a seeded run
	level:GetStartingRoomIndex() == level:GetCurrentRoomIndex() and			-- If player is in starting room
	level:GetStage() == LevelStage.STAGE1_1 and								-- If floor 1
	player:HasCollectible(CollectibleType.COLLECTIBLE_R_KEY) == false then	-- If player has not used the "R key" item
		-- Check if the current run is a challenge and if we should enable for them
		if isChallenge and TreasureQuickstart.settings.challenges == false then
			TreasureQuickstart.endSearch = true
		else
			-- Ensure a treasure room is present, then check it's item
			if hasRoom(level, roomType) then
				-- Get treasure room index
				itemRoomIndex = level:QueryRoomTypeIndex(roomType, false, RNG(), true)
				-- Move the player to the treasure room
				-- This needs to be done before we can check the item, as it is not generated until the player enters the room
				Game():ChangeRoom(itemRoomIndex)

				local room = Game():GetRoom()
				local roomEntities = room:GetEntities()

				-- Search through entities for item pedestals
				for i = 0, #roomEntities - 1 do
					local entity = roomEntities:Get(i)
					if (entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
						local item = Isaac.GetItemConfig():GetCollectible(entity.SubType)
						TreasureQuickstart.endSearch = item.Quality >= (TreasureQuickstart.settings.quality - 1) and true or false
					end
				end
			else
				-- Dont end the search if we're looking for a planetarium and one isn't present
				if roomType == RoomType.ROOM_PLANETARIUM then
					TreasureQuickstart.endSearch = false
				else
					TreasureQuickstart.endSearch = true
				end
			end
		end
	end
end

-- Callback for MC_POST_RENDER
function TreasureQuickstart:restart()
	-- Restart the run until an item is found
	-- This is always run after the start() callback, which sets endSearch appropriately
	-- Restarting only once a frame prevents the game from crashing from reseeding too quickly
	if TreasureQuickstart.endSearch == false then
		Isaac.ExecuteCommand("restart")
	end
end

-------------------------------------------------------------------------------------------------
-- MOD CONFIG MENU

-- UI definitions
TreasureQuickstart.MCM = {
	enabled = {
		default = true,
		info = "Enable or disable the mod",
		display = "Enabled: "
	},

	challenges = {
		default = false,
		info = "Enable or disable treasure filtering in challenges",
		display = "Enable in challenges: "
	},

	quality = {
		default = 4,	-- Quality 3 by default
		info = "Filter out items below this quality",
		display = "Minimum Quality: ",
		choices = {
			"Q0",
			"Q1",
			"Q2",
			"Q3",
			"Q4"
		}
	},

	mode = {
		default = 1,	-- Treasure rooms by default
		info = "Type of item room to search for. Planetariums can take a while to find.",
		display = "Room type: ",
		choices = {
			"Treasure",
			"Planetarium"
		}
	}
}

-- Settings value table, used and populated by MCM
TreasureQuickstart.settings = {
	mode = TreasureQuickstart.MCM.mode.default,
	enabled = TreasureQuickstart.MCM.enabled.default,
	quality = TreasureQuickstart.MCM.quality.default,
	challenges = TreasureQuickstart.MCM.challenges.default
}

-- Save persistent data
function TreasureQuickstart:save()
	local jsonString = json.encode(TreasureQuickstart.settings)
	TreasureQuickstart:SaveData(jsonString)
end

-- Load persistent data
function TreasureQuickstart:load()
	if not TreasureQuickstart:HasData() then
		return
	end

	local jsonString = TreasureQuickstart:LoadData()
	TreasureQuickstart.settings = json.decode(jsonString)
end

-- Init the MCM page
local function modConfigMenuInit()
	if ModConfigMenu ~= nil then
		-- Remove the category to prevent duplicate entries when reloading live
		ModConfigMenu.RemoveCategory("Treasure QuickStart")

		-- TITLE
		ModConfigMenu.AddTitle("Treasure QuickStart", nil, "Settings")
		ModConfigMenu.AddText("Treasure QuickStart", nil, "------------------------")

		-- ENTRY: Toggle mod enable
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.BOOLEAN,
				Default = TreasureQuickstart.MCM.enabled.default,
				Info = { TreasureQuickstart.MCM.enabled.info },
				Display = function()
					return TreasureQuickstart.MCM.enabled.display .. (TreasureQuickstart.settings.enabled and "true" or "false")
				end,

				OnChange = function(v)
					TreasureQuickstart.settings.enabled = v
					TreasureQuickstart:save()
				end,

				CurrentSetting = function()
					return TreasureQuickstart.settings.enabled
				end
			}
		)

		-- SPACER
		ModConfigMenu.AddSpace("Treasure QuickStart", nil)

		-- ENTRY: Mode setting
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.NUMBER,
				Minimum = 1,
				Maximum = #TreasureQuickstart.MCM.mode.choices,
				Default = TreasureQuickstart.MCM.mode.default,
				Info = { TreasureQuickstart.MCM.mode.info },
				Display = function()
					return TreasureQuickstart.MCM.mode.display .. TreasureQuickstart.MCM.mode.choices[TreasureQuickstart.settings.mode]
				end,

				OnChange = function(v)
					TreasureQuickstart.settings.mode = v
					TreasureQuickstart:save()
				end,

				CurrentSetting = function()
					return TreasureQuickstart.settings.mode
				end
			}
		)

		-- ENTRY: Minimum quality setting
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.NUMBER,
				Minimum = 1,
				Maximum = #TreasureQuickstart.MCM.quality.choices,
				Default = TreasureQuickstart.MCM.quality.default,
				Info = { TreasureQuickstart.MCM.quality.info },
				Display = function()
					return TreasureQuickstart.MCM.quality.display .. TreasureQuickstart.MCM.quality.choices[TreasureQuickstart.settings.quality]
				end,

				OnChange = function(v)
					TreasureQuickstart.settings.quality = v
					TreasureQuickstart:save()
				end,

				CurrentSetting = function()
					return TreasureQuickstart.settings.quality
				end
			}
		)

		-- ENTRY: Enable in challenges
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.BOOLEAN,
				Default = TreasureQuickstart.MCM.challenges.default,
				Info = { TreasureQuickstart.MCM.challenges.info },
				Display = function()
					return TreasureQuickstart.MCM.challenges.display .. (TreasureQuickstart.settings.challenges and "true" or "false")
				end,

				OnChange = function(v)
					TreasureQuickstart.settings.challenges = v
					TreasureQuickstart:save()
				end,

				CurrentSetting = function()
					return TreasureQuickstart.settings.challenges
				end
			}
		)
	end
end

-------------------------------------------------------------------------------------------------
-- CALLBACKS

TreasureQuickstart:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, TreasureQuickstart.start)
TreasureQuickstart:AddCallback(ModCallbacks.MC_POST_RENDER, TreasureQuickstart.restart)
TreasureQuickstart:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, TreasureQuickstart.save)

-------------------------------------------------------------------------------------------------
-- INIT

modConfigMenuInit()				-- Init mod configuration menu entry
TreasureQuickstart.load()		-- Load saved MCM settings
