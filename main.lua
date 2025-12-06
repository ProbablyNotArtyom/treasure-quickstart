-------------------------------------------------------------------------------------------------
-- Treasure QuickStart
-------------------------------------------------------------------------------------------------

local json = require("json")										-- Load JSON for MCM
local TreasureQuickstart = RegisterMod("Treasure QuickStart", 1)	-- Register mod

-- Callback for MC_POST_GAME_STARTED
function TreasureQuickstart:start()
	local player = Isaac.GetPlayer()
	local level = Game():GetLevel()

	-- Check if current floor has a treasure room
	local function hasTreasureRoom(level)
		local rooms = Game():GetLevel():GetRooms()
		for i = 0, #rooms - 1 do
			if (rooms:Get(i).Data.Type == RoomType.ROOM_TREASURE) then
				return true
			end
		end

		return false
	end

	-- Check if current floor has a curse
	local function hasCurse(curse)
		local currentCurses = Game():GetLevel():GetCurses()
		return (currentCurses & curse) == curse
	end

	if TreasureQuickstart.settings.enabled == true and					-- If mod is enabled through MCM
	level:GetStartingRoomIndex() == level:GetCurrentRoomIndex() and			-- If player is in starting room
	level:GetStage() == LevelStage.STAGE1_1 and								-- If floor 1
	player:HasCollectible(CollectibleType.COLLECTIBLE_R_KEY) == false then	-- If player has not used the "R key" item
		-- Check if the current run is a challenge and if we should enable for them
		if Isaac.GetChallenge() ~= 0 and TreasureQuickstart.settings.challenges == false then
			TreasureQuickstart.itemFound = true
		end

		-- Ensure a treasure room is present, then check it's item
		if hasTreasureRoom(level) then
			if not hasCurse(LevelCurse.CURSE_OF_MAZE) and not hasCurse(LevelCurse.CURSE_OF_BLIND) then
				-- Get treasure room index
				treasureRoomIndex = level:QueryRoomTypeIndex(RoomType.ROOM_TREASURE, false, RNG(), true)
				-- Move the player to the treasure room
				-- This needs to be done before we can check the item, as it is not generated until the player enters the room
				Game():ChangeRoom(treasureRoomIndex)

				local room = Game():GetRoom()
				local roomEntities = room:GetEntities()

				-- Search through entities for item pedestals
				for i = 0, #roomEntities - 1 do
					local entity = roomEntities:Get(i)
					if (entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
						local item = Isaac.GetItemConfig():GetCollectible(entity.SubType)
						TreasureQuickstart.itemFound = item.Quality >= (TreasureQuickstart.settings.quality - 1) and true or false
					end
				end
			else
				TreasureQuickstart.itemFound = false
			end
		else
			-- If no treasure room, then dont try and reseed for one
			TreasureQuickstart.itemFound = true
		end
	end
end

-- Callback for MC_POST_RENDER
function TreasureQuickstart:restart()
	-- Restart the run until an item is found
	-- This is always run after the start() callback, which sets itemFound appropriately
	-- Restarting only once a frame prevents the game from crashing from reseeding too quickly
	if TreasureQuickstart.itemFound == false then
		Isaac.ExecuteCommand("restart")
	end
end

-------------------------------------------------------------------------------------------------
-- MOD CONFIG MENU

-- UI definitions
TreasureQuickstart.MCM = {
	enabled = {
		default = true
	},

	challenges = {
		default = true
	},

	quality = {
		default = 4,	-- Quality 3 by default
		choices = {
			"Q0",
			"Q1",
			"Q2",
			"Q3",
			"Q4"
		}
	}
}

-- Settings value table, used and populated by MCM
TreasureQuickstart.settings = {
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
				Info = { "Enable or disable the mod" },
				-- Color = { 1.0, 1.0, 1.0 },
				Display = function()
					return "Enabled: " .. (TreasureQuickstart.settings.enabled and "true" or "false")
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

		-- ENTRY: Minimum quality setting
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.NUMBER,
				Minimum = 1,
				Maximum = #TreasureQuickstart.MCM.quality.choices,
				Default = TreasureQuickstart.MCM.quality.default,
				Info = { "Filter out items below this quality" },
				-- Color = { 1.0, 1.0, 1.0 },
				Display = function()
					return "Minimum Quality: " .. TreasureQuickstart.MCM.quality.choices[TreasureQuickstart.settings.quality]
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
				Info = { "Enable or disable treasure filtering in challenges" },
				-- Color = { 1.0, 1.0, 1.0 },
				Display = function()
					return "Enable in challenges: " .. (TreasureQuickstart.settings.challenges and "true" or "false")
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
