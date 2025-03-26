-- !strict

-- #Services
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- #Variables

local PlayerLvlSetupRemoteEvent = ReplicatedStorage.Remote.PlayerLvlSetup -- location:  StarterCharacterScripts.RemoteEvents
local TransitionRemoteEvent = ReplicatedStorage.Remote.Transition -- location: StarterCharacterScripts.RemoteEvents

local DataManagerModule = require(ServerScriptService.Data.DataManager)

local enteredPlayers = {}
-- #Functions

local function TweenDoor(door: Part, doorDefaultPosition: Vector3, goal: string)
		
	local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quint)
	
	if goal == "Open"then
		-- Open door tween
		local goalOpen = {
			Position = doorDefaultPosition + Vector3.new(0, 8, 0)
		}
		local tween = TweenService:Create(door, tweenInfo, goalOpen)
		tween:Play()
	else
		-- Close door tween
		local goalClose = {
			Position =  doorDefaultPosition --door.Position - Vector3.new(0, 8, 0)
		}	
		
		local tween = TweenService:Create(door, tweenInfo, goalClose)
		tween:Play()
		
	end
	
end

local function MovePlayersThroughDoors(players: {}, otherDoor: Model, mapDoor: Model, isMapDoor: boolean?)	
	if otherDoor:GetAttribute("Open") then
		if isMapDoor then
			local mapPP: ProximityPrompt = mapDoor.PPromptPart.ProximityPrompt
			local otherPP: ProximityPrompt = otherDoor.PPromptPart.ProximityPrompt
			
			mapPP.Enabled = false
			otherPP.Enabled = false			
		end
		
		task.wait(2)
		

		-- if 2 players have entered the door, the player's character moves through the door
		if #players == 2 then
			for i, player in enteredPlayers do
				local character: Model = player.Character or player.CharacterAdded:Wait() 

				local canMove: BoolValue = player:WaitForChild("CanMove")
				canMove.Value = false

				if i == 1 then
					local partToCome1: Part =  otherDoor.PartToCome

					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					humanoid:MoveTo(partToCome1.Position, partToCome1)
				else
					local partToCome1: Part =  mapDoor.PartToCome

					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					humanoid:MoveTo(partToCome1.Position, partToCome1)
				end
			end
		
		else -- if not, wait for the other player to enter while the player who has entered is excluded from the possibility of moving
			for i, player in enteredPlayers do				
				local character: Model = player.Character or player.CharacterAdded:Wait() 

				local canMove: BoolValue = player:WaitForChild("CanMove")
				canMove.Value = false
				
				local partToCome1: Part =  mapDoor.PartToCome
				
				local humanoid: Humanoid = character:FindFirstChild("Humanoid")
				humanoid:MoveTo(partToCome1.Position, partToCome1)				
			end
		end

		table.clear(players)		
	end	
end


-- #Events

for _, mapDoor : Model in pairs(CollectionService:GetTagged("MapDoor")) do

	local door: Part = mapDoor.Door 
	local doorDefaultPosition: Vector3 = door.Position
	local doorColor: string =  mapDoor:GetAttribute("Color")
	local lvl: Instance = mapDoor.Parent
	
	local partToCome: Part = mapDoor.PartToCome 
	local blackPart : Part = mapDoor.BlackPart 
	local proximityPrompt: ProximityPrompt = mapDoor.PPromptPart.ProximityPrompt 	
	
	local playerOpened: BoolValue = mapDoor.PlayerOpened
	
	-- when the proximityPrompt triggers the door opens or closes
	proximityPrompt.Triggered:Connect(function(player: Player)
		local canMove: BoolValue = player:WaitForChild("CanMove")

		if proximityPrompt.ActionText == "Open the door" then -- Ako se vrata otvaraju 	
			
			TweenDoor(door, doorDefaultPosition, "Open")
			
			mapDoor:SetAttribute("Open", true)
			canMove.Value = false
			
			player:SetAttribute("Level", tonumber(lvl.Name))
			player:SetAttribute("Color", doorColor)
			table.insert(enteredPlayers, player)
					
			playerOpened.Value = true

			proximityPrompt.ActionText = "Close the door"
			
		else -- Ako se vrata zatvaraju

			TweenDoor(door, doorDefaultPosition, "Close")
			
			mapDoor:SetAttribute("Open", false)
			canMove.Value = true
			
			player:SetAttribute("Level", nil)
			player:SetAttribute("Color", nil)
			table.remove(enteredPlayers, #enteredPlayers)
			
			playerOpened.Value = false
			
			proximityPrompt.ActionText = "Open the door"
		end
	end)

	-- when both doors are opened players move through the doors
	mapDoor:GetAttributeChangedSignal("Open"):Connect(function()	
		if not mapDoor:GetAttribute("Open") then			
			return 
		end
		
		if doorColor == "Blue" then
			local otherDoor: Model = mapDoor.Parent.RedDoor
			
			MovePlayersThroughDoors(enteredPlayers, otherDoor, mapDoor, true)						
		else
			local otherDoor: Model = mapDoor.Parent.BlueDoor
			
			MovePlayersThroughDoors(enteredPlayers, otherDoor, mapDoor, true)	
		end
		
	end)
	
	-- when partToCome is touched players are teleported to the level
	partToCome.Touched:Connect(function(hit)
		local character: Model 
		local player: Player
		
		if hit.Name ==  "HumanoidRootPart" then
			character = hit.Parent
			player = Players:GetPlayerFromCharacter(character)			
		end
				
		if player then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			local playerColor = player:GetAttribute("Color")
			local lvlToTeleport: Folder = game.Workspace.Levels[tonumber(lvl.Name)]
			local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]
			local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation

			humanoidRootPart.CFrame = SpawnLocation.CFrame + Vector3.new(0, 2, 0)	
			SpawnLocation.Enabled = true
			mapSpawnLocation.Enabled = false
			player.RespawnLocation = SpawnLocation
			
			
			PlayerLvlSetupRemoteEvent:FireClient(player, tonumber(lvl.Name)) 


			-- BoolValue IsInLevel is set to true (the player has entered the level)
			local isInLevel: BoolValue = player:WaitForChild("InLevel")
			isInLevel.Value = true
			

			-- BoolValue CanMove is set to true (player can move)
			local canMove: BoolValue = player:WaitForChild("CanMove")
			canMove.Value = true
			
			local billboardGui: BillboardGui = ReplicatedStorage.BillboardGui[playerColor.."BillboardGui"]:Clone()
			billboardGui.Parent = character.Head
			
			proximityPrompt.Enabled = true
			

			-- The door is closing.
			TweenDoor(door, doorDefaultPosition, "Close")
			mapDoor:SetAttribute("Open", false) -- the open attribute is set to false
			proximityPrompt.ActionText = "Open the door"
		end		
	end)
	
	-- when the blackPart is touched a transition is shown to the player
	blackPart.Touched:Connect(function(hit)
		blackPart.CanTouch = false
		
		local character: Model = hit.Parent
		local player: Player = Players:GetPlayerFromCharacter(character)
		
		if player then
			TransitionRemoteEvent:FireClient(player)				
		end
		
		task.wait(1)		
		blackPart.CanTouch = true
	end)
	
end

for _, levelDoor : Model in pairs(CollectionService:GetTagged("LevelDoor")) do

	local door: Part = levelDoor.Door --levelDoor:WaitForChild("Door")
	local doorDefaultPosition: Vector3 = door.Position
	local doorColor: string = levelDoor:GetAttribute("Color")
	local lvl: Instance = levelDoor.Parent

	local partToCome: Part = levelDoor.PartToCome --levelDoor:WaitForChild("PartToCome")
	local blackPart : Part = levelDoor.BlackPart --levelDoor:WaitForChild("BlackPart")
	local region: Part = levelDoor.Region --levelDoor:WaitForChild("Region")


	-- when the region is touched if the player is the same color as the door, the door opens
	region.Touched:Connect(function(hit)
		if hit.Name == "HumanoidRootPart" and #enteredPlayers < 2 then	

			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			
			if player:GetAttribute("Color") == levelDoor:GetAttribute("Color") then
				table.insert(enteredPlayers, player)
				
				TweenDoor(door, doorDefaultPosition, "Open")
				
				levelDoor:SetAttribute("Open", true)				
			end

		end			
	end)
	
	-- when the player exits the region the door closes
	region.TouchEnded:Connect(function(hit)
		if hit.Name == "HumanoidRootPart" then
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			
			if table.find(enteredPlayers, player) then
				table.remove(enteredPlayers, enteredPlayers[player])	
			end			
		end
		
				
		if #enteredPlayers < 1 then
			TweenDoor(door, doorDefaultPosition, "Close")
						
			levelDoor:SetAttribute("Open", false)
		end		
	end)
	

	-- when both doors are opened players move through the doors
	levelDoor:GetAttributeChangedSignal("Open"):Connect(function()	
		if not levelDoor:GetAttribute("Open") then			
			return 
		end
		

		if doorColor == "Blue" then
			local otherDoor: Model = levelDoor.Parent.RedDoor

			MovePlayersThroughDoors(enteredPlayers, otherDoor, levelDoor)

		else
			local otherDoor: Model = levelDoor.Parent.BlueDoor

			MovePlayersThroughDoors(enteredPlayers, otherDoor, levelDoor)			
		end	
	end)
	
	-- when partToCome is touched players are teleported to the level
	partToCome.Touched:Connect(function(hit)
		local character: Model 
		local player: Player

		if hit.Name ==  "HumanoidRootPart" then
			character = hit.Parent
			player = Players:GetPlayerFromCharacter(character)			
		end
		
		if player then

			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			local playerColor = player:GetAttribute("Color")
			local lvlToTeleport: Folder = game.Workspace.Levels[tonumber(lvl.Name)]
			local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]
			local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation

			humanoidRootPart.CFrame = mapSpawnLocation.CFrame + Vector3.new(0, 2, 0)	
			SpawnLocation.Enabled = false
			mapSpawnLocation.Enabled = true
			player.RespawnLocation = mapSpawnLocation

		
			-- BoolValue IsInLevel is set to true (the player has entered the level)
			local isInLevel: BoolValue = player:WaitForChild("InLevel")
			isInLevel.Value = false
		
			-- BoolValue CanMove is set to true (player can move)
			local canMove: BoolValue = player:WaitForChild("CanMove")
			canMove.Value = true
			
			local billboardGui: BillboardGui = character.Head:FindFirstChildWhichIsA("BillboardGui")
			billboardGui:Destroy()
			
			TweenDoor(door, doorDefaultPosition, "Close")
			player:SetAttribute("Color", nil)
			player:SetAttribute("Level", nil)
			
			DataManagerModule.LevelCompleted(player, tonumber(lvl.Name))
		end

	end)
	
	-- when the blackPart is touched a transition is shown to the player
	blackPart.Touched:Connect(function(hit)
		if hit.Parent ~= nil  and hit.Parent:IsA("Model") and hit.Name == "HumanoidRootPart" then
			local character: Model = hit.Parent
			local player: Player = Players:GetPlayerFromCharacter(character)
			
			TransitionRemoteEvent:FireClient(player)	
			
			task.wait(2)
			
			local gemsFolder: Folder = lvl.Gems
		
			for i, gem: MeshPart in gemsFolder:GetChildren() do
				if gem.CanTouch == false then
					gem.CanTouch = true
					gem.Transparency = 0
				end
			end
			
			local stone: MeshPart = lvl:FindFirstChild("Stone")
			local stoneStartPosition: Part = lvl:FindFirstChild("StoneStartPosition")
			
			if stone and stoneStartPosition then
				stone.Position = stoneStartPosition.Position
			end
			
		end
	end)
	
	
end

PlayerLvlSetupRemoteEvent.OnServerEvent:Connect(function(player)		
	local playerColor: string = player:GetAttribute("Color")
	local playerLevel: number = player:GetAttribute("Level")
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	local folder: Folder = game.Workspace.Levels:FindFirstChild(playerLevel)
	local stone: MeshPart = folder:FindFirstChild("Stone")
	local stoneStartPosition: Part = folder:FindFirstChild("StoneStartPosition")
	
	if stone and stoneStartPosition then
		stone.Position = stoneStartPosition.Position
	end		
		
	local lvlToTeleport: Folder = game.Workspace.Levels[playerLevel]
	local SpawnLocation: SpawnLocation = lvlToTeleport["SpawnLocation"..playerColor]
	local mapSpawnLocation: SpawnLocation = game.Workspace.Map.MapSpawnLocation
	
	humanoidRootPart.CFrame = SpawnLocation.CFrame + Vector3.new(0, 2, 0)
end)