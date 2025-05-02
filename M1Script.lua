--!strict
-- /* Services *\ --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

-- /* Variables *\ --
local cooldownBetween2M1s: number = 0.3

--local blockCooldown: number = 0.1

local lastHitTimes = {} -- keeps track of the last time a character was hit
local stunCheckRunning = {} -- keeps track of whether there is already an active loop for the character
local lastAttackTimes = {}

local ragdollData = require(ReplicatedStorage.ModuleScripts.RagdollData) -- A table containing CFrame type data for each attachment that is added to the character

-- Remote Events
local m1RE: RemoteEvent = ReplicatedStorage.Remotes.M1
local blockRE: RemoteEvent = ReplicatedStorage.Remotes.Block
local vfxReplicatorRE: RemoteEvent = ReplicatedStorage.Remotes.VfxReplicator

-- /* Functions *\ --
-- Goes through all descendants of the character enabling or disabling all Motor6D depending on what value of the enabled variable
local function EnableMotor6D(character: Model, enabled: boolean)
	for _, v in ipairs(character:GetDescendants()) do
		if not v.IsA("Motor6d") then -- Anything that is not Motor6D is skipped
			continue 
		end		
		if v.Name == "RootJoint" or v.Name == "Neck" then -- RootJoint and Neck are skipped due to side effects
			continue
		end
		local motor : Motor6D = v :: Motor6D			
		motor.Enabled = enabled
	end	
end

-- Adds attachments to all required parts of the character and adds BallSocketConstraints that connect to those attachments. BallSocketConstrain are added to achieve the Ragdoll effect
local function BuildJoints(character: Model)	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part	
	for _, v in ipairs(character:GetDescendants()) do

		if not v:IsA("BasePart") or v:FindFirstAncestorOfClass("Accessory") or v.Name == "Handle" or v.Name == "Torso" or v.Name == "HumanoidRootPart" then -- In everything that is stated here, attachments are not added because they are not needed there
			continue
		end
		if not ragdollData[v.Name] then -- Also, no attachment is placed in everything that is not in the table
			continue
		end
		local a0: Attachment, a1: Attachment = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name = "RAGDOLL_ATTACHMENT"
		a0.Parent = v
		a0.CFrame = ragdollData[v.Name].CFrame[2]
		a1.Name = "RAGDOLL_ATTACHMENT"
		a1.Parent = humanoidRootPart
		a1.CFrame = ragdollData[v.Name].CFrame[1]
		--  Add a BallSocketConstraint to achieve the Ragdoll effect
		local socket = Instance.new("BallSocketConstraint")
		socket.Name = "RAGDOLL_CONSTRAINT"
		socket.Attachment0 = a0
		socket.Attachment1 = a1
		socket.Parent = v		
	end
end

-- In the second script I added parts to all parts of the character so that they don't go through the floor. This function changes the CanCollide property to value of enabled variable
local function EnableCollisionParts(character: Model, enabled: boolean)
	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.CanCollide = not enabled
			local collidePart: Part = v:FindFirstChild("Collide") :: Part
			collidePart.CanCollide = enabled
		end
	end
end

-- It goes through all the descendants of the character and destroys any attachments that have been added
local function DestroyJoints(character: Model)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part	
	humanoidRootPart.Massless = false	
	for _, v in ipairs(character:GetDescendants()) do
		if v.Name == "RAGDOLL_ATTACHMENT" or v.Name == "RAGDOLL_CONSTRAINT"  then
			v:Destroy()
		end		
	end	
end

-- The character goes into Ragdoll state
local function RagdollCharacter(character: Model)
	-- I call the necessary functions needed to make the character a Ragdoll
	EnableMotor6D(character, false)
	BuildJoints(character)
	EnableCollisionParts(character, true)	
	local player: Player = Players:GetPlayerFromCharacter(character)
	local humanoid: Humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part	
	humanoid.AutoRotate = false -- It prevents the character from automatically turning in the direction the player wants to move
	humanoid.PlatformStand = true -- character is in a state where it is in free fall and cannot move
end

-- the character returns to normal
local function  UnragdollCharacter(character: Model, getUpState: number?)
	local humanoid: Humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part	
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then -- if the character is dead, the execution of this function is stopped
		return
	end	
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) -- This method sets whether a given Enum.HumanoidStateType is enabled for the Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) -- changes the character state to the specified state	
	--calling the required functions
	DestroyJoints(character)
	EnableMotor6D(character, true)
	EnableCollisionParts(character, false)	
	-- resetting properties to default values
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
end

--Sets the enabled property to false for all ParticleEmitters in VFX
local function DisableVFX(part: Part)
	for _, v in pairs(part:GetDescendants()) do		
		if not  v:IsA("ParticleEmitter") then			
			continue
		end
		v.Enabled = false
	end
end

--Sets the enabled property to true for all ParticleEmitters in VFX
local function EnableVFX(part: Part)	
	for _, v in pairs(part:GetDescendants()) do		
		if not  v:IsA("ParticleEmitter") then			
			continue
		end		
		v.Enabled = true
	end
end

-- /* Events *\ --
m1RE.OnServerEvent:Connect(function(player, attackingCharacter, hitedCharacters, m1Count, isHoldingSpace)	
	attackingCharacter:SetAttribute("isAttacking", true) -- setting the isAttacking attribute to true so that the character cannot perform the action again until a certain amount of time has passed	
	lastAttackTimes[attackingCharacter] = tick() -- the time when the character performed the action is saved for later calculation	
	-- Fire all clients
	vfxReplicatorRE:FireAllClients(attackingCharacter) -- replicate vfx on all clients for less lag	
	local humanoid: Humanoid = attackingCharacter:FindFirstChild("Humanoid")
	local humanoidRootPart: Part =  attackingCharacter:FindFirstChild("HumanoidRootPart") :: Part
	humanoid.WalkSpeed = 6 --lowers the character's speed
	humanoid.JumpHeight = 0 -- reduces the strength of jumping	
	for _, hitedCharacter in pairs(hitedCharacters) do -- I go through all affected characters so they get damage		
		local hitedHumanoid: Humanoid = hitedCharacter:FindFirstChild("Humanoid")
		local hitedHumanoidRootPart: Part = hitedCharacter:FindFirstChild("HumanoidRootPart") :: Part		
		if not hitedHumanoid or hitedCharacter:GetAttribute("isBlocking") then -- if the hited character does not have a humanoid, it means that the character was not hit, but some "inanimate" object, and if the hited character block the hit, it does not take damage
			continue
		end		
		lastHitTimes[hitedCharacter] = tick() -- the time the hited character took damage
		local event		
		if not stunCheckRunning[hitedCharacter] then -- when the hited character takes damage he becomes stunned and the stun resets if the player takes damage again
			stunCheckRunning[hitedCharacter] = true 
			task.spawn(function()
				hitedCharacter:SetAttribute("isStunned", true) --setting the isStunned attribute to true so that a stunned character cannot perform other actions such as blocking or attacking
				hitedHumanoid.WalkSpeed = 0
				hitedHumanoid.JumpHeight = 0 				
				while true do -- until a certain amount of time has passed without the hited character taking damage, he will remain stunned
					local now = tick()
					local lastHit = lastHitTimes[hitedCharacter]								
					if not lastHit or now - lastHit > (cooldownBetween2M1s + 1.2) then
						-- Stun stoped
						hitedCharacter:SetAttribute("isStunned", false)
						hitedHumanoid.WalkSpeed = 16
						hitedHumanoid.JumpHeight = 7.2					
						stunCheckRunning[hitedCharacter] = false					
						break
					end										
					task.wait(0.1)
				end
			end)
		end
		-- Take damage
		hitedHumanoid.Health -= 5	-- character takes 5 damage		
		--hited character is pushed back a bit
		local linearVelocity: LinearVelocity = Instance.new("LinearVelocity")
		linearVelocity.Attachment0 = hitedHumanoidRootPart:FindFirstChild("RootAttachment") :: Attachment
		linearVelocity.ForceLimitsEnabled = false			
		if m1Count == 4 then			
			if humanoid:GetState() == Enum.HumanoidStateType.Running or humanoid:GetState() == Enum.HumanoidStateType.Jumping then -- if the attacking character is in a state of running or jumping, it enters this branch				
				RagdollCharacter(hitedCharacter)			
				task.delay(1.5, function()
					UnragdollCharacter(hitedCharacter)
				end)			
				if isHoldingSpace == true then -- if the player holds space, he will perform an uppercut	
					linearVelocity.VectorVelocity = Vector3.new(0, 50, 0) + (humanoidRootPart.CFrame.LookVector * 5)										
				else -- if not, the hited character pushes back with a little more force
					linearVelocity.VectorVelocity = (humanoidRootPart.CFrame.LookVector + Vector3.new(0, 0.3, 0)) * 30	
					hitedHumanoidRootPart.CFrame = hitedHumanoidRootPart.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(45), 0, 0)								
				end			
			elseif humanoid:GetState() == Enum.HumanoidStateType.Freefall then -- if the attacking character is in a state of freefall, he will perform a slam			
				task.spawn(function()					
					hitedHumanoidRootPart.CFrame = hitedHumanoidRootPart.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(90), 0, 0) -- rotation of the hited character on the back					
					task.wait(cooldownBetween2M1s + 1.2)
					hitedHumanoidRootPart.CFrame = hitedHumanoidRootPart.CFrame * CFrame.fromEulerAnglesXYZ(math.rad(-90), 0, 0) -- return hited character back on lags
				end)				
			end	
		end		
		linearVelocity.Parent = hitedHumanoidRootPart
		Debris:AddItem(linearVelocity, 0.2) -- after 0.2s linearVelocity is destroyed
	end
	task.spawn(function()
		local currentCharacter = attackingCharacter		
		while true do -- while the character is attacking, the isAttacking attribute remains true
			task.wait(0.1) 
			if tick() - lastAttackTimes[currentCharacter] >= cooldownBetween2M1s then			
				if currentCharacter and currentCharacter.Parent then
					currentCharacter:SetAttribute("isAttacking", false)
					
					local humanoid: Humanoid = currentCharacter:FindFirstChild("Humanoid")
					
					if humanoid then
						humanoid.WalkSpeed = 16
						task.delay(1, function()							
							humanoid.JumpHeight = 7.2							
						end)
					end
				end				
				break
			end
		end
	end)	
end)

blockRE.OnServerEvent:Connect(function(player, isBlocking)
	local character = player.Character or player.CharacterAdded:Wait()	
	character:SetAttribute("isBlocking", isBlocking)	 -- setting the isBlocking attribute to the passed value
end)

-- :FireAllClients is called from the server to replicate the vfx on all clients to reduce lag
vfxReplicatorRE.OnClientEvent:Connect(function(character: Model)
	local humanoidRootPart: Part =  character:FindFirstChild("HumanoidRootPart") :: Part	

	local forwardVector: Vector3 = humanoidRootPart.CFrame.LookVector	-- vector towards which the player is looking
	local spawnPosition : Vector3 = humanoidRootPart.Position + Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit * 2	-- the position where the part containing the vfx will create
	local direction: Vector3 = humanoidRootPart.Position - spawnPosition	-- the direction in which the part containing the vfx will be turned
	local origin = CFrame.new(spawnPosition, spawnPosition + direction) -- a parameter containing the previous three specified data	
	-- vfx creation
	local vfx: Part = ReplicatedStorage.VFX["cat slash"]:Clone()
	vfx.CFrame = origin 
	vfx.Parent = game.Workspace.VFX
	task.spawn(function()
		EnableVFX(vfx)
		task.wait(0.2)
		DisableVFX(vfx)		
	end)	
	Debris:AddItem(vfx, 0.3) -- after 0.3 seconds the part containing the vfx is destroyed	
end)
