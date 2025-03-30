-- !strict

-- #Services
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- #Variables

-- Remote events for player level setup and transition, allowing communication between server and client.
local PlayerLvlSetupRemoteEvent = ReplicatedStorage.Remote.PlayerLvlSetup -- location:  StarterCharacterScripts.RemoteEvents
local TransitionRemoteEvent = ReplicatedStorage.Remote.Transition -- location: StarterCharacterScripts.RemoteEvents

-- Module responsible for managing player data.
local DataManagerModule = require(ServerScriptService.Data.DataManager)

local enteredPlayers = {}
-- #Functions

--[[
Function to animate a door opening or closing using a Tween effect.
The function receives a door part, its default position, and the desired goal ("Open" or "Close").
]]
local function TweenDoor(door: Part, doorDefaultPosition: Vector3, goal: string)

		
	local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quint) -- Smooth transition over 5 seconds.
	
	if goal == "Open"then
		-- Move door upwards to simulate opening.
		local goalOpen = {
			Position = doorDefaultPosition + Vector3.new(0, 8, 0)
		}
		local tween = TweenService:Create(door, tweenInfo, goalOpen)
		tween:Play()
	else
		-- Move door back to its original position to close it.
		local goalClose = {
			Position =  doorDefaultPosition 
		}	
		
		local tween = TweenService:Create(door, tweenInfo, goalClose)
		tween:Play()
		
	end
	
end

--[[
Function to move a player's character to a target part.
It disables the player's movement during the transition for smooth teleportation.
]]
local function MovePlayerToPart(player: Player, part: Part)
	local character: Model = player.Character or player.CharacterAdded:Wait()  -- Ensure the character exists.

	local canMove: BoolValue = player:WaitForChild("CanMove") -- Retrieve movement permission.
	canMove.Value = false -- Disable movement to prevent interruptions.
	
	local humanoid: Humanoid = character:FindFirstChild("Humanoid") -- Get the Humanoid component.
	humanoid:MoveTo(part.Position, part)	 -- Move character to target part.
end

--[[
Function to handle player transitions through doors.
Ensures that doors are open before moving players and manages multi-player transitions.
]]
local function MovePlayersThroughDoors(players: {}, otherDoor: Model, mapDoor: Model, isMapDoor: boolean?)	
	if not otherDoor:GetAttribute("Open") then return end -- Check if the other door is open before proceeding.
	
	if isMapDoor then
		-- Disable proximity prompts to prevent players from triggering them during transitions.
		local mapPP: ProximityPrompt = mapDoor.PPromptPart.ProximityPrompt
		local otherPP: ProximityPrompt = otherDoor.PPromptPart.ProximityPrompt
		
		mapPP.Enabled = false
		otherPP.Enabled = false			
	end
	
	task.wait(2) -- Wait for a short delay before teleporting players.
	
	-- If two players are present, move them through their respective doors.
	if #players == 2 then
		for i, player in enteredPlayers do
			if i == 1 then
				local partToCome1: Part =  otherDoor.PartToCome  -- First player moves to the other door's destination.
				MovePlayerToPart(player, partToCome1)
			else
				local partToCome1: Part =  mapDoor.PartToCome  -- Second player moves to the map door's destination.
				MovePlayerToPart(player, partToCome1)
			end
		end		
	else 
		-- If only one player entered, move them but wait for the second player.
		for i, player in enteredPlayers do							
			local partToCome1: Part =  mapDoor.PartToCome				
			MovePlayerToPart(player, partToCome1)
		end
	end
	table.clear(players)	-- Reset the list of entered players after teleportation.	

end


-- #Events

-- Loops through all objects tagged as "MapDoor" using CollectionService
for _, mapDoor : Model in pairs(CollectionService:GetTagged("MapDoor")) do
	
	-- References to important components of the door system
	local door: Part = mapDoor.Door 
	local doorDefaultPosition: Vector3 = door.Position  -- Stores the default position of the door for resetting
	local doorColor: string =  mapDoor:GetAttribute("Color") -- Determines door color to control logic
	local lvl: Instance = mapDoor.Parent -- Level associated with the door
	
	local partToCome: Part = mapDoor.PartToCome  -- Part that teleports players into the level
	local blackPart : Part = mapDoor.BlackPart   -- Part that triggers a transition effect
	local proximityPrompt: ProximityPrompt = mapDoor.PPromptPart.ProximityPrompt -- Prompt for player interaction 	
	
	local playerOpened: BoolValue = mapDoor.PlayerOpened -- Tracks whether the player has opened the door
	
	-- Handles the opening and closing of the door when the player interacts with it
	proximityPrompt.Triggered:Connect(function(player: Player)
		local canMove: BoolValue = player:WaitForChild("CanMove") --Ensures we wait for the CanMove attribute to exist

		if proximityPrompt.ActionText == "Open the door" then  -- If door is currently closed
			
			TweenDoor(door, doorDefaultPosition, "Open")
			
			mapDoor:SetAttribute("Open", true) -- Marks the door as open
			canMove.Value = false  -- Disables player movement temporarily
			
			-- Sets player's level and color attributes
			player:SetAttribute("Level", tonumber(lvl.Name))
			player:SetAttribute("Color", doorColor)
			
			table.insert(enteredPlayers, player)  -- Adds player to the list of players who entered
					
			playerOpened.Value = true -- Marks that the player has opened the door

			proximityPrompt.ActionText = "Close the door"  -- Updates prompt text to close the door
			
		else  -- If door is currently open, close it
			
			TweenDoor(door, doorDefaultPosition, "Close") 
			
			mapDoor:SetAttribute("Open", false) -- Marks the door as closed
			canMove.Value = true -- Allows player movement again
			
			-- Resets player's attributes since they are no longer in the door
			player:SetAttribute("Level", nil)
			player:SetAttribute("Color", nil)
			
			table.remove(enteredPlayers, #enteredPlayers)  -- Removes last player from the entered list
			
			playerOpened.Value = false -- Marks that the player has closed the door
			
			proximityPrompt.ActionText = "Open the door" -- Updates prompt text to open the door
		end
	end)

	-- Handles logic when both doors are open, allowing players to move through
	mapDoor:GetAttributeChangedSignal("Open"):Connect(function()	
		if not mapDoor:GetAttribute("Open") then return end -- If door isn't open, exit function
		
		-- Determines the corresponding door of the other color
		if doorColor == "Blue" then
			local otherDoor: Model = mapDoor.Parent.RedDoor
			
			MovePlayersThroughDoors(enteredPlayers, otherDoor, mapDoor, true) -- Moves players						
		else
			local otherDoor: Model = mapDoor.Parent.BlueDoor
			
			MovePlayersThroughDoors(enteredPlayers, otherDoor, mapDoor, true) -- Moves players	
		end
		
	end)
	
	-- Teleports players into the level when they touch partToCome
	partToCome.Touched:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end  -- Ensures only player characters trigger it
		
		local character: Model = hit.Parent
		local player: Player = Players:GetPlayerFromCharacter(character) -- Gets player from character
				
		if not player then return end -- Exit if not a valid player
				
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local playerColor = player:GetAttribute("Color") -- Gets the player's color for teleporting
		local lvlToTeleport: Folder = game.Workspace.Levels[tonumber(lvl.Name)] -- Gets level folder
		local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]  -- Gets player-specific spawn
		local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation -- Map spawn location
		
		-- Teleports player to the appropriate spawn location
		humanoidRootPart.CFrame = SpawnLocation.CFrame + Vector3.new(0, 2, 0)	
		SpawnLocation.Enabled = true
		mapSpawnLocation.Enabled = false
		player.RespawnLocation = SpawnLocation
		
		-- Notifies client that the player entered a level
		PlayerLvlSetupRemoteEvent:FireClient(player, tonumber(lvl.Name)) 
		
		-- Marks player as inside the level
		local isInLevel: BoolValue = player:WaitForChild("InLevel")
		isInLevel.Value = true
		
		-- Enables movement again
		local canMove: BoolValue = player:WaitForChild("CanMove")
		canMove.Value = true
		
		-- Assigns a BillboardGui above the player's head to indicate team/color
		local billboardGui: BillboardGui = ReplicatedStorage.BillboardGui[playerColor.."BillboardGui"]:Clone()
		billboardGui.Parent = character.Head
		
		proximityPrompt.Enabled = true -- Re-enables prompt after teleportation
		
		-- Closes the door after teleportation to prevent multiple entries
		TweenDoor(door, doorDefaultPosition, "Close")
		mapDoor:SetAttribute("Open", false) 
		proximityPrompt.ActionText = "Open the door"
			
	end)
	
	-- Handles the transition effect when the blackPart is touched
	blackPart.Touched:Connect(function(hit)
		blackPart.CanTouch = false -- Temporarily disables touch detection to prevent spam
		
		local character: Model = hit.Parent
		local player: Player = Players:GetPlayerFromCharacter(character)
		
		if player then
			TransitionRemoteEvent:FireClient(player) --Triggers the transition effect for the player			
		end
		
		task.wait(1) -- Adds a small delay before re-enabling touch detection		
		blackPart.CanTouch = true
	end)
	
end

-- Loop through all objects tagged as "LevelDoor" to set up their behavior
for _, levelDoor : Model in pairs(CollectionService:GetTagged("LevelDoor")) do
	
	-- Retrieve key components of the door system
	local door: Part = levelDoor.Door 
	local doorDefaultPosition: Vector3 = door.Position -- Store the initial position to reset later
	local doorColor: string = levelDoor:GetAttribute("Color") -- Get the color attribute to match players
	local lvl: Instance = levelDoor.Parent -- Get the parent level instance
	
	-- Parts relevant to door mechanics
	local partToCome: Part = levelDoor.PartToCome   -- The part players must touch to enter level
	local blackPart : Part = levelDoor.BlackPart  -- The transition trigger part
	local region: Part = levelDoor.Region  -- The area that players must enter to open the door


	-- When a player touches the region, check if they match the door's color
	region.Touched:Connect(function(hit)
		-- Ignore touches from non-player objects and prevent redundant openings
		if hit.Name ~= "HumanoidRootPart" and #enteredPlayers >= 2 then	return end
		
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		-- If player color doesn't match the door, do nothing
		if player:GetAttribute("Color") ~= levelDoor:GetAttribute("Color") then return end
		
		-- Register player entry
		table.insert(enteredPlayers, player)
		
		-- Animate the door to open
		TweenDoor(door, doorDefaultPosition, "Open")
		
		-- Mark door as open
		levelDoor:SetAttribute("Open", true)
	end)
	
	-- When a player exits the region, check if the door should close
	region.TouchEnded:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end
		
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		-- Remove player from entered list if present
		if table.find(enteredPlayers, player) then
			table.remove(enteredPlayers, enteredPlayers[player])	
		end	
		
		-- If at least one player remains inside, keep the door open
		if #enteredPlayers >= 1	 then return end	
		
		-- Otherwise, close the door
		TweenDoor(door, doorDefaultPosition, "Close")					
		levelDoor:SetAttribute("Open", false)
	
	end)
	

	-- When both doors are open, teleport players through them
	levelDoor:GetAttributeChangedSignal("Open"):Connect(function()	
		if not levelDoor:GetAttribute("Open") then return end
		
		-- Determine the other door based on color
		local otherDoor: Model 
		if doorColor == "Blue" then
			otherDoor = levelDoor.Parent.RedDoor			
		else
			otherDoor = levelDoor.Parent.BlueDoor
		end	
		
		-- Move players through the doors
		MovePlayersThroughDoors(enteredPlayers, otherDoor, levelDoor)			
	end)
	
	-- When "partToCome" is touched, teleport players to the level
	partToCome.Touched:Connect(function(hit)
		local character: Model 
		local player: Player
		
		if hit.Name ~=  "HumanoidRootPart" then return end
		
		character = hit.Parent
		player = Players:GetPlayerFromCharacter(character)			

		if not player then return end
		
		-- Get spawn locations and teleport the player
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local playerColor = player:GetAttribute("Color")
		local lvlToTeleport: Folder = game.Workspace.Levels[tonumber(lvl.Name)]
		local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]
		local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation
		
		humanoidRootPart.CFrame = mapSpawnLocation.CFrame + Vector3.new(0, 2, 0)	
		SpawnLocation.Enabled = false  -- Disable level spawn to prevent immediate respawns
		mapSpawnLocation.Enabled = true -- Set respawn to map spawn
		player.RespawnLocation = mapSpawnLocation
	
		-- Mark player as in level and able to move
		local isInLevel: BoolValue = player:WaitForChild("InLevel")
		isInLevel.Value = false
	
		local canMove: BoolValue = player:WaitForChild("CanMove")
		canMove.Value = true
		
		-- Remove any UI indicators on the player
		local billboardGui: BillboardGui = character.Head:FindFirstChildWhichIsA("BillboardGui")
		billboardGui:Destroy()
		
		-- Close the door after teleportation
		TweenDoor(door, doorDefaultPosition, "Close")
		player:SetAttribute("Color", nil)
		player:SetAttribute("Level", nil)
		
		-- Notify data manager that the level is completed
		DataManagerModule.LevelCompleted(player, tonumber(lvl.Name))		
	end)
	
	-- When "blackPart" is touched, trigger transition and reset collectibles
	blackPart.Touched:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end
		
		local character: Model = hit.Parent
		local player: Player = Players:GetPlayerFromCharacter(character)
		
		-- Trigger client-side transition effect
		TransitionRemoteEvent:FireClient(player)	
		
		task.wait(2) -- Delay before resetting gems
		
		-- Reactivate all gems in the level
		local gemsFolder: Folder = lvl.Gems	
		for i, gem: MeshPart in gemsFolder:GetChildren() do
			if gem.CanTouch == false then
				gem.CanTouch = true
				gem.Transparency = 0
			end
		end
		
		-- Reset stone position if applicable
		local stone: MeshPart = lvl:FindFirstChild("Stone")
		local stoneStartPosition: Part = lvl:FindFirstChild("StoneStartPosition")
		
		if stone and stoneStartPosition then
			stone.Position = stoneStartPosition.Position
		end			
	end)		
end

-- Handles player setup for level teleportation
PlayerLvlSetupRemoteEvent.OnServerEvent:Connect(function(player)		
	local playerColor: string = player:GetAttribute("Color")
	local playerLevel: number = player:GetAttribute("Level")
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	-- Find level components
	local folder: Folder = game.Workspace.Levels:FindFirstChild(playerLevel)
	local stone: MeshPart = folder:FindFirstChild("Stone")
	local stoneStartPosition: Part = folder:FindFirstChild("StoneStartPosition")
	
	-- Reset stone position if found
	if stone and stoneStartPosition then
		stone.Position = stoneStartPosition.Position
	end		
	
	-- Teleport player to their level spawn location	
	local lvlToTeleport: Folder = game.Workspace.Levels[playerLevel]
	local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]
	local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation	
	humanoidRootPart.CFrame = SpawnLocation.CFrame + Vector3.new(0, 2, 0)
end)