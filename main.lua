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
			-- Skip over incompatible curses if enabled
			if hasCurse(LevelCurse.CURSE_OF_MAZE) and TreasureQuickstart.settings.curses == false then
				TreasureQuickstart.itemFound = true
			else
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
		default = true,
		info = "Enable or disable the mod",
		display = "Enabled: "
	},

	challenges = {
		default = true,
		info = "Enable or disable treasure filtering in challenges",
		display = "Enable in challenges: "
	},

	curses = {
		default = true,
		info = "Skips Curse of the Maze. When false, the mod will stop on this curse instead of reseeding due to API limitations.",
		display = "Skip incompatible curses: "
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
	}
}

-- Settings value table, used and populated by MCM
TreasureQuickstart.settings = {
	enabled = TreasureQuickstart.MCM.enabled.default,
	quality = TreasureQuickstart.MCM.quality.default,
	challenges = TreasureQuickstart.MCM.challenges.default,
	curses = TreasureQuickstart.MCM.curses.default
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
				-- Color = { 1.0, 1.0, 1.0 },
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
				-- Color = { 1.0, 1.0, 1.0 },
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
				-- Color = { 1.0, 1.0, 1.0 },
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

		-- ENTRY: Disable incompatible curses
		ModConfigMenu.AddSetting(
			"Treasure QuickStart",
			nil,
			{
				Type = ModConfigMenu.OptionType.BOOLEAN,
				Default = TreasureQuickstart.MCM.curses.default,
				Info = { TreasureQuickstart.MCM.curses.info },
				-- Color = { 1.0, 1.0, 1.0 },
				Display = function()
					return TreasureQuickstart.MCM.curses.display .. (TreasureQuickstart.settings.curses and "true" or "false")
				end,

				OnChange = function(v)
					TreasureQuickstart.settings.curses = v
					TreasureQuickstart:save()
				end,

				CurrentSetting = function()
					return TreasureQuickstart.settings.curses
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
