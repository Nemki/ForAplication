-- Service
local ContextActionService = game:GetService("ContextActionService") -- Used to bind actions to specific keys
local UserInputService = game:GetService("UserInputService") -- Used to detect user input

-- Variables
local player = game.Players.LocalPlayer -- Gets the local player
local character = player.Character	or player.CharacterAdded:Wait() -- Gets the player's character
local humanoid = character:WaitForChild("Humanoid")  -- Gets the Humanoid component for movement and animation
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")  -- Gets the character's root part for physics interactions

local debounce = false -- Prevents spamming the dash ability
local dashColldown = false

local DashAnimations = {} -- Stores dash animations

-- Attack variables
local M1Colldown = false -- Prevents attack spam
local clicked = false -- Tracks whether an attack input was detected
local PressTime -- Stores the time of the last attack press
local NewPressTime -- Stores the time of the current attack press
local combo = 0 -- Tracks the attack combo progress
local UserInputService = game:GetService("UserInputService") -- Shortcut for input service

-- Load M1 (basic attack) animations
local M1Animations = {
	[1] = humanoid:WaitForChild("Animator"):LoadAnimation(game.ReplicatedStorage.M1s["1"]),
	[2] = humanoid:WaitForChild("Animator"):LoadAnimation(game.ReplicatedStorage.M1s["2"]),
	[3] = humanoid:WaitForChild("Animator"):LoadAnimation(game.ReplicatedStorage.M1s["3"]),
	[4] = humanoid:WaitForChild("Animator"):LoadAnimation(game.ReplicatedStorage.M1s["4"]),
	[5] = humanoid:WaitForChild("Animator"):LoadAnimation(game.ReplicatedStorage.M1s["5"])
}

local M1Remote = game:GetService("ReplicatedStorage").Remotes.M1 -- Remote event for attacks
-- Functions

-- Load Dash animations from ReplicatedStorage
repeat task.wait() 
	for i,v in ipairs(game.ReplicatedStorage.Animacije:GetChildren()) do 				
		if v:IsA("Animation") and v.Name == "BoljiDash" then 		
			table.insert(DashAnimations, player.Character:WaitForChild("Humanoid"):LoadAnimation(game.ReplicatedStorage.Animacije:FindFirstChild("BoljiDash")))
		end
	end
until character:WaitForChild("Humanoid")

-- Dash function, activated by pressing "Q"
local function Dash(action,inputState)
	if action == "Dash" and inputState == Enum.UserInputState.Begin then			
		if dashColldown == false then
			
			dashColldown = true	  -- Activate cooldown				
			local moveDirectio = humanoid.MoveDirection -- Direction the player is moving
			local lookVector = humanoidRootPart.CFrame.LookVector -- Where the character is facing
			local dashDirection = nil			
			local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= Enum.Material.Water -- Checks if the player is grounded
			
			if isOnGround  and humanoid.Health > 0 then					
				local dash = Instance.new("LinearVelocity", humanoidRootPart) -- Creates velocity for dash effect		
				dash.Attachment0 = humanoidRootPart.RootAttachment
				dash.MaxForce = 100000					
				
				-- Function to update dash direction based on key presses
				local function check()
					UserInputService.InputBegan:Connect(function(input)
						if input.KeyCode == Enum.KeyCode.A then									
							dash.VectorVelocity = Vector3.new(-35,0,0)	
						elseif input.KeyCode == Enum.KeyCode.D then
							dash.VectorVelocity = Vector3.new(35,0,0)
						elseif input.KeyCode == Enum.KeyCode.S then
							dash.VectorVelocity = Vector3.new(0,0,35)
						elseif input.KeyCode == Enum.KeyCode.W then
							dash.VectorVelocity = Vector3.new(0,0,-35)
						end
					end)
				end	
				
				local pressed  = false -- Tracks if a movement key is held
				
				-- Function to continuously update dash direction
				local function check2()					
					UserInputService.InputBegan:Connect(function(input)
						if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.W then
							pressed = true
							while pressed == true  do
								task.wait()
								dash.VectorVelocity = humanoidRootPart.CFrame.LookVector * 35										
							end
						end
					end)					
					UserInputService.InputBegan:Connect(function(input)
						if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.W then
							pressed = false
						end
					end)
				end		
				
				-- If camera is locked, dash relative to the character's view direction
				if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then													
					dash.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
					if moveDirectio == Vector3.new(0,0,0)  then						
						dash.VectorVelocity = Vector3.new(0,0,-35)
						game.Debris:AddItem(dash,0.4)
						DashAnimations[1]:Play()
						game.Debris:AddItem(DashAnimations[1], 0.4)						
						spawn(check)
					else
						if UserInputService:IsKeyDown(Enum.KeyCode.A) then
							--print("A")
							dash.VectorVelocity = Vector3.new(-35,0,0)	
							game.Debris:AddItem(dash,0.4)
							DashAnimations[1]:Play()
							game.Debris:AddItem(DashAnimations[1], 0.4)							
							spawn(check)
						elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
							--print("S")
							dash.VectorVelocity = Vector3.new(0,0,35)	
							game.Debris:AddItem(dash,0.4)
							DashAnimations[1]:Play()
							game.Debris:AddItem(DashAnimations[1], 0.4)							
							spawn(check)
						elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then	
							--print("D")
							dash.VectorVelocity = Vector3.new(35,0,0)	
							game.Debris:AddItem(dash,0.4)	
							DashAnimations[1]:Play()
							game.Debris:AddItem(DashAnimations[1], 0.4)							
							spawn(check)
						elseif UserInputService:IsKeyDown(Enum.KeyCode.W) then	
							--print("W")
							dash.VectorVelocity = Vector3.new(0,0,-35)
							game.Debris:AddItem(dash,0.4)	
							DashAnimations[1]:Play()
							game.Debris:AddItem(DashAnimations[1], 0.4)
							spawn(check)													
						end
					end
				else		
					dash.RelativeTo = Enum.ActuatorRelativeTo.World
					dash.VectorVelocity = humanoidRootPart.CFrame.LookVector * 35
					game.Debris:AddItem(dash,0.4)	-- Removes dash effect after 0.4 seconds
					DashAnimations[1]:Play()  -- Play dash animation
					game.Debris:AddItem(DashAnimations[1], 0.4)					
					spawn(check2)
				end								
			end			
			
			-- Reset dash cooldown after 1 second
			delay(1, function()
				if dashColldown == true then					
					dashColldown = false
				end
			end)			
		end
	end	
end

-- Function for pressing "E" that makes a player jump in the air
function JumpInAir(action,inputState)
	if action == "JumpInAir" and inputState == Enum.UserInputState.Begin then
		local rigHumanoid = game.Workspace.Rig1.Humanoid
		local rigRootPart = game.Workspace.Rig1.HumanoidRootPart
		rigHumanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

-- Resets attack combo if it times out
local function M1Reset()
	PressTime = tick()
	M1Animations[1]:Play()
	local connection 
	connection= M1Animations[1]:GetMarkerReachedSignal("Hit"):Connect(function()
		M1Remote:FireServer(combo)
		connection:Disconnect()
	end)
end
-- Events
ContextActionService:BindAction("Dash", Dash, false, Enum.KeyCode.Q)  -- Bind "Q" to Dash
ContextActionService:BindAction("JumpInAir", JumpInAir, false, Enum.KeyCode.E) -- Bind "E" to jump in the air

-- Handles attack combos
UserInputService.InputBegan:Connect(function(input,GPE)
	if GPE then return end -- If the input is part of a game process (GUI input), ignore it
	
	-- Check if the player is allowed to attack (not on cooldown)
	if clicked == false and M1Colldown == false then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then	-- Left mouse button click	
			clicked = true -- Prevents multiple simultaneous clicks
			combo = combo + 1 -- Increments the combo count
			
			-- First attack in the combo
			if combo == 1 then
				PressTime = tick() -- Stores the time of the attack
				M1Animations[1]:Play() -- Plays the first attack animation
				M1Remote:FireServer(combo) -- Notifies the server about the attack combo stage
				
			elseif combo >1 and combo < 5 then  -- If the combo is between 2 and 4
				NewPressTime = tick() -- Stores the new press time
				local ActualTime = NewPressTime - PressTime  -- Calculates time between attacks
				
				if ActualTime < 2 then    -- If the time between attacks is less than 2 seconds, continue the combo
					PressTime = tick() -- Updates press time
					M1Animations[combo]:Play() -- Plays the corresponding combo animation
					M1Remote:FireServer(combo)  -- Notifies the server about the current combo stage
				else
					M1Reset()  -- Resets combo if the player waited too long
					combo = 1
				end
			elseif combo == 5 then -- If the combo reaches the last attack (5th attack)
				NewPressTime = tick()
				local ActualTime = NewPressTime - PressTime
				-- If the time between attacks is valid, perform the final attack and enter cooldown
				if ActualTime < 2 then
					M1Colldown = true  -- Enables attack cooldown		
					M1Animations[combo]:Play()  -- Plays the final combo animation
					M1Remote:FireServer(combo) -- Notifies the server
					task.wait(3) -- Waits 3 seconds before resetting
					M1Colldown = false -- Disables cooldown
					combo = 0 -- Resets combo
					clicked = false  -- Allows for new combo sequences
				else
					M1Reset() -- Resets combo if the attack was too slow
					combo = 1
				end
			end
			
			-- Ensures "clicked" resets after a short delay, allowing the player to attack again
			delay(0.4, function()
				if clicked == true  then
					clicked = false
				end
			end)						
		end
	end	
end)

