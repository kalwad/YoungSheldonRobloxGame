--!nonstrict
-- Server-authoritative interaction controller for the Cooper house.
-- Installed into ServerScriptService as "CooperInteractions".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local HOUSE_PATH_TIMEOUT = 20
local CHILD_TIMEOUT = 8

-- Milestone 1 owns Humanoid.WalkSpeed in one server-authoritative controller.
-- Timed fixture interactions compose a named movement lock through that API.
local movementAPI = ServerScriptService:WaitForChild("CooperMovementAPI", 30)
local movementSetLock = movementAPI and movementAPI:WaitForChild("SetLock", 10)
assert(movementSetLock and movementSetLock:IsA("BindableFunction"), "CooperMovementAPI.SetLock is missing")

local function setTimedActionMovementLock(player, locked)
	local ok, accepted = pcall(function()
		return movementSetLock:Invoke(player, "InteriorTimedAction", locked == true)
	end)
	return ok and accepted == true
end

local function waitFor(parent, name, className, timeout)
	if not parent then
		return nil
	end
	local instance = parent:WaitForChild(name, timeout or CHILD_TIMEOUT)
	if not instance then
		warn(string.format("[CooperInteractions] Missing %s.%s", parent:GetFullName(), name))
		return nil
	end
	if className and not instance:IsA(className) then
		warn(string.format(
			"[CooperInteractions] %s must be a %s (got %s)",
			instance:GetFullName(),
			className,
			instance.ClassName
		))
		return nil
	end
	return instance
end

local function findPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local remotes = ReplicatedStorage:WaitForChild("CooperInteractionsRemotes", HOUSE_PATH_TIMEOUT)
if not remotes then
	warn("[CooperInteractions] CooperInteractionsRemotes was not installed")
	return
end

local requestEvent = waitFor(remotes, "Request", "RemoteEvent", 5)
local clientEvent = waitFor(remotes, "Client", "RemoteEvent", 5)
if not requestEvent or not clientEvent then
	warn("[CooperInteractions] Required RemoteEvents are missing")
	return
end

local environment = workspace:WaitForChild("CooperHouseEnvironment", HOUSE_PATH_TIMEOUT)
local house = environment and environment:WaitForChild("CooperHouse", HOUSE_PATH_TIMEOUT)
local interactionRoot = house and house:WaitForChild("CooperInteractions", HOUSE_PATH_TIMEOUT)
if not interactionRoot then
	warn("[CooperInteractions] CooperInteractions world model was not installed")
	return
end

local furniture = waitFor(house, "FurnitureAndProps", "Model")
local bathroom = waitFor(interactionRoot, "BathroomInteractions", "Model")
local fridge = waitFor(furniture, "WhiteHotpointRefrigerator", "Model")
local doorAssembly = waitFor(fridge, "CooperFridgeDoorAssembly", "Model")
local fridgeInterior = waitFor(fridge, "CooperFridgeInterior", "Model")
if not furniture or not bathroom or not fridge or not doorAssembly or not fridgeInterior then
	warn("[CooperInteractions] Required house interaction geometry is incomplete")
	return
end

local heldByPlayer = {}
local holderByObject = {}
local homePivots = {}
local releasedAt = {}
local releaseEpoch = {}
local terminalSessions = {}
local cubeSessions = {}
local cooldowns = {}
local activeActions = {}
local fixtureOwners = {}
local actionSerial = 0
local cubeSessionSerial = 0

local reportActionEvent = nil
local function reportAuthoritativeAction(player, eventKey, metadata)
	if not reportActionEvent or not reportActionEvent.Parent then
		local eventFolder = ServerScriptService:FindFirstChild("CooperGameServerEvents")
		local candidate = eventFolder and eventFolder:FindFirstChild("ReportAction")
		reportActionEvent = candidate and candidate:IsA("BindableEvent") and candidate or nil
	end
	if not reportActionEvent then
		return
	end
	local ok, failure = pcall(function()
		-- CooperGame's private server contract is event key, authoritative player,
		-- then optional metadata. Nothing is replicated to clients.
		reportActionEvent:Fire(eventKey, player, metadata or {})
	end)
	if not ok then
		warn("[CooperInteractions] Optional ReportAction integration failed: " .. tostring(failure))
	end
end

local function now()
	return workspace:GetServerTimeNow()
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return nil
	end
	return character, humanoid, rootPart
end

local function worldPosition(instance)
	if typeof(instance) ~= "Instance" then
		return nil
	end
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	local ancestorPart = instance:FindFirstAncestorWhichIsA("BasePart")
	return ancestorPart and ancestorPart.Position or nil
end

local function playerIsNear(player, instance, maximumDistance)
	local _, _, rootPart = getCharacterParts(player)
	local targetPosition = worldPosition(instance)
	return rootPart ~= nil
		and targetPosition ~= nil
		and (rootPart.Position - targetPosition).Magnitude <= maximumDistance
end

local function passCooldown(player, key, delaySeconds)
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	local current = now()
	if (playerCooldowns[key] or 0) > current then
		return false
	end
	playerCooldowns[key] = current + delaySeconds
	return true
end

local function tell(player, text, duration)
	if not player or player.Parent ~= Players then
		return
	end
	clientEvent:FireClient(player, "Toast", {
		text = tostring(text),
		duration = duration or 2.5,
	})
end

local function timedFeedback(player, text, duration)
	if not player or player.Parent ~= Players then
		return
	end
	clientEvent:FireClient(player, "TimedAction", {
		text = text,
		duration = duration,
	})
end

local function findPickableContainer(descendant)
	local current = descendant
	while current and current ~= house do
		if current:GetAttribute("CooperPickable") == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function pickableHandle(container)
	if container:IsA("BasePart") then
		return container
	end
	return container:FindFirstChild("InteractionHandle")
end

local function setPromptEnabled(container, enabled)
	local handle = pickableHandle(container)
	if not handle then
		return
	end
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("ProximityPrompt") then
			child.Enabled = enabled
		end
	end
end

local function closeCubeSession(player, notifyClient)
	local session = cubeSessions[player]
	if not session then
		return
	end
	cubeSessions[player] = nil
	if notifyClient and player.Parent == Players then
		clientEvent:FireClient(player, "CubeClose", {
			sessionId = session.id,
		})
	end
end

local function closeOtherCubeSessions(container, exceptPlayer)
	for sessionPlayer, session in pairs(cubeSessions) do
		if session.container == container and sessionPlayer ~= exceptPlayer then
			closeCubeSession(sessionPlayer, true)
		end
	end
end

local function releaseHeld(player, shouldThrow)
	local state = heldByPlayer[player]
	if not state then
		return
	end

	heldByPlayer[player] = nil
	holderByObject[state.container] = nil
	releasedAt[state.container] = now()
	releaseEpoch[state.container] = (releaseEpoch[state.container] or 0) + 1
	local epoch = releaseEpoch[state.container]
	if cubeSessions[player] and cubeSessions[player].container == state.container then
		closeCubeSession(player, true)
	end

	if state.weld and state.weld.Parent then
		state.weld:Destroy()
	end

	local handle = state.handle
	if handle and handle.Parent then
		handle.Massless = false
		handle.CanCollide = false
		pcall(function()
			handle:SetNetworkOwner(nil)
		end)

		local _, _, rootPart = getCharacterParts(player)
		if rootPart then
			local largestDimension = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
			local forwardDistance = math.clamp(largestDimension * 0.65 + 1.8, 2.6, 4.5)
			local releasePosition = rootPart.Position
				+ rootPart.CFrame.LookVector * forwardDistance
				+ Vector3.new(0, 0.35, 0)
			local rotationOnly = handle.CFrame - handle.Position
			handle.CFrame = CFrame.new(releasePosition) * rotationOnly
		end
		-- Keep collision on for throws so the cube doesn't fall through the floor
		-- and get snapped home by the Y < -20 restock loop.
		if shouldThrow then
			handle.CanCollide = true
			handle.Anchored = false
		end
		if shouldThrow and rootPart then
			local throwPower = tonumber(state.container:GetAttribute("ThrowPower")) or 58
			handle.AssemblyLinearVelocity = rootPart.CFrame.LookVector * throwPower
				+ Vector3.new(0, 14, 0)
				+ rootPart.AssemblyLinearVelocity
			handle.AssemblyAngularVelocity = Vector3.new(7, 10, 5)
			setPromptEnabled(state.container, true)
		else
			handle.AssemblyLinearVelocity = Vector3.zero
			handle.AssemblyAngularVelocity = Vector3.zero
			task.delay(0.1, function()
				if state.container
					and state.container.Parent
					and handle.Parent
					and not holderByObject[state.container]
					and releaseEpoch[state.container] == epoch
				then
					handle.CanCollide = true
					setPromptEnabled(state.container, true)
				end
			end)
		end
	end

	if player.Parent == Players then
		clientEvent:FireClient(player, "HeldItem", {
			held = false,
		})
	end
end

-- Solving can begin straight from the table without first picking the cube up.
-- In that path there is no held-state weld for releaseHeld() to throw, so give
-- up launches the nearby physical cube directly and leaves any other item in
-- the player's hand untouched.
local function throwLoosePickable(player, container)
	if not container
		or not container.Parent
		or container:GetAttribute("CooperPickable") ~= true
		or holderByObject[container]
	then
		return false
	end
	local handle = pickableHandle(container)
	local _, _, rootPart = getCharacterParts(player)
	if not handle
		or not handle:IsA("BasePart")
		or not rootPart
		or not playerIsNear(player, handle, 15)
	then
		return false
	end

	releasedAt[container] = now()
	releaseEpoch[container] = (releaseEpoch[container] or 0) + 1
	handle.Massless = false
	handle.CanCollide = true
	handle.Anchored = false
	pcall(function()
		handle:SetNetworkOwner(nil)
	end)

	local largestDimension = math.max(handle.Size.X, handle.Size.Y, handle.Size.Z)
	local forwardDistance = math.clamp(largestDimension * 0.65 + 1.8, 2.6, 4.5)
	local releasePosition = rootPart.Position
		+ rootPart.CFrame.LookVector * forwardDistance
		+ Vector3.new(0, 0.35, 0)
	local rotationOnly = handle.CFrame - handle.Position
	handle.CFrame = CFrame.new(releasePosition) * rotationOnly
	local throwPower = tonumber(container:GetAttribute("ThrowPower")) or 58
	handle.AssemblyLinearVelocity = rootPart.CFrame.LookVector * throwPower
		+ Vector3.new(0, 14, 0)
		+ rootPart.AssemblyLinearVelocity
	handle.AssemblyAngularVelocity = Vector3.new(7, 10, 5)
	setPromptEnabled(container, true)
	return true
end

local function holdPickable(player, container)
	if not container or container:GetAttribute("CooperPickable") ~= true then
		return
	end
	if holderByObject[container] then
		tell(player, "Someone else is holding that.")
		return
	end

	local character = getCharacterParts(player)
	if not character then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local handle = pickableHandle(container)
	if not hand or not handle or not handle:IsA("BasePart") then
		return
	end
	if not playerIsNear(player, handle, 13) then
		return
	end

	if heldByPlayer[player] then
		releaseHeld(player, false)
	end

	closeOtherCubeSessions(container, player)
	releasedAt[container] = nil
	releaseEpoch[container] = (releaseEpoch[container] or 0) + 1
	setPromptEnabled(container, false)
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	handle.CFrame = hand.CFrame * CFrame.new(0, -0.45, -0.75) * CFrame.Angles(0, math.rad(90), 0)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CooperHoldWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.Parent = handle
	pcall(function()
		handle:SetNetworkOwner(player)
	end)

	local state = {
		container = container,
		handle = handle,
		weld = weld,
	}
	heldByPlayer[player] = state
	holderByObject[container] = player

	clientEvent:FireClient(player, "HeldItem", {
		held = true,
		name = container:GetAttribute("DisplayName") or container.Name,
		isCube = container:GetAttribute("CubePuzzle") == true,
	})
end

local showerPipe = findPath(furniture, "BlackTileFrostedShower", "ChromeShowerPipe")
local showerTogglePrompt = showerPipe and showerPipe:FindFirstChild("CooperShowerTogglePrompt")
local showerWaterPart = bathroom:FindFirstChild("ShowerWater")
local showerWater = showerWaterPart and showerWaterPart:FindFirstChildOfClass("ParticleEmitter")
local showerLight = showerWaterPart and showerWaterPart:FindFirstChildOfClass("PointLight")
local showerSound = showerWaterPart and showerWaterPart:FindFirstChild("CooperShowerWaterSound")
if showerWaterPart and (not showerSound or not showerSound:IsA("Sound")) then
	if showerSound then
		showerSound:Destroy()
	end
	showerSound = Instance.new("Sound")
	showerSound.Name = "CooperShowerWaterSound"
	showerSound.SoundId = "rbxasset://sounds/impact_water.mp3"
	showerSound.Volume = 0.62
	showerSound.Looped = true
	showerSound.RollOffMinDistance = 4
	showerSound.RollOffMaxDistance = 30
	showerSound.Parent = showerWaterPart
end
local showerSteamPart = bathroom:FindFirstChild("ShowerSteamCloud")
local showerSteam = showerSteamPart and showerSteamPart:FindFirstChildOfClass("ParticleEmitter")
local showerUseAnchor = bathroom:FindFirstChild("ShowerUseAnchor")
local sinkUseAnchor = bathroom:FindFirstChild("SinkUseAnchor")
local showerVisibleParts = {}
local showerVisibleBeams = {}
local frostedGlassDoor = findPath(furniture, "BlackTileFrostedShower", "FrostedGlassDoor")
local frostedGlassRestTransparency = frostedGlassDoor and frostedGlassDoor.Transparency or 0.42
for _, descendant in ipairs(bathroom:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:GetAttribute("CooperShowerStream") == true then
		table.insert(showerVisibleParts, descendant)
	elseif descendant:IsA("Beam") and descendant:GetAttribute("CooperShowerBeam") == true then
		table.insert(showerVisibleBeams, descendant)
	end
end
if showerUseAnchor and not showerUseAnchor:IsA("BasePart") then
	showerUseAnchor = nil
end
if sinkUseAnchor and not sinkUseAnchor:IsA("BasePart") then
	sinkUseAnchor = nil
end
local showerOn = false

local function setShower(on)
	showerOn = on == true
	interactionRoot:SetAttribute("ShowerOn", showerOn)
	if showerWater then
		showerWater.Enabled = showerOn
	end
	if showerLight then
		showerLight.Enabled = showerOn
	end
	if showerSteam then
		showerSteam.Enabled = showerOn
	end
	if showerSound and showerSound:IsA("Sound") then
		if showerOn then
			if not showerSound.IsPlaying then
				showerSound:Play()
			end
		else
			showerSound:Stop()
		end
	end
	if frostedGlassDoor and frostedGlassDoor:IsA("BasePart") then
		-- Slightly clearer glass while running so exterior cameras still read water.
		frostedGlassDoor.Transparency = showerOn and math.max(frostedGlassRestTransparency, 0.62) or frostedGlassRestTransparency
	end
	for _, waterPart in ipairs(showerVisibleParts) do
		if waterPart.Parent then
			waterPart.Transparency = showerOn
				and (tonumber(waterPart:GetAttribute("OnTransparency")) or 0.45)
				or 1
		end
	end
	for _, waterBeam in ipairs(showerVisibleBeams) do
		if waterBeam.Parent then
			waterBeam.Enabled = showerOn
		end
	end
	if showerTogglePrompt then
		showerTogglePrompt.ActionText = showerOn and "Turn Off Shower" or "Turn On Shower"
	end
end

setShower(false)

local sinkWaterPart = bathroom:FindFirstChild("SinkWater")
local toothbrushFoamPart = bathroom:FindFirstChild("ToothbrushFoam")
local toiletWaterPart = bathroom:FindFirstChild("ToiletWaterEffect")
local sinkWater = sinkWaterPart and sinkWaterPart:FindFirstChild("FaucetWater")
if not (sinkWater and sinkWater:IsA("ParticleEmitter")) then
	sinkWater = sinkWaterPart and sinkWaterPart:FindFirstChildOfClass("ParticleEmitter")
end
local sinkSplash = sinkWaterPart and sinkWaterPart:FindFirstChild("BasinSplash")
local sinkSteam = sinkWaterPart and sinkWaterPart:FindFirstChild("SinkSteam")
local sinkSound = sinkWaterPart and sinkWaterPart:FindFirstChild("CooperSinkFaucetSound")
local toothbrushFoam = toothbrushFoamPart and toothbrushFoamPart:FindFirstChildOfClass("ParticleEmitter")
local toiletWater = toiletWaterPart and toiletWaterPart:FindFirstChildOfClass("ParticleEmitter")
local sinkVisibleParts = {}
local sinkVisibleBeams = {}
for _, descendant in ipairs(bathroom:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:GetAttribute("CooperSinkFlow") == true then
		table.insert(sinkVisibleParts, descendant)
	elseif descendant:IsA("Beam") and descendant:GetAttribute("CooperSinkBeam") == true then
		table.insert(sinkVisibleBeams, descendant)
	end
end
local function setSinkFlow(on)
	local enabled = on == true
	if sinkWater then
		sinkWater.Enabled = enabled
	end
	if sinkSplash and sinkSplash:IsA("ParticleEmitter") then
		sinkSplash.Enabled = enabled
	end
	if sinkSteam and sinkSteam:IsA("ParticleEmitter") then
		sinkSteam.Enabled = enabled
	end
	if sinkSound and sinkSound:IsA("Sound") then
		if enabled then
			if not sinkSound.IsPlaying then
				sinkSound:Play()
			end
		else
			sinkSound:Stop()
		end
	end
	for _, waterPart in ipairs(sinkVisibleParts) do
		if waterPart.Parent then
			waterPart.Transparency = enabled
				and (tonumber(waterPart:GetAttribute("OnTransparency")) or 0.3)
				or 1
		end
	end
	for _, waterBeam in ipairs(sinkVisibleBeams) do
		if waterBeam.Parent then
			waterBeam.Enabled = enabled
		end
	end
end
setSinkFlow(false)
local toiletFlushSound = toiletWaterPart and toiletWaterPart:FindFirstChild("CooperToiletFlushSound")
if toiletFlushSound and not toiletFlushSound:IsA("Sound") then
	toiletFlushSound = nil
end
local toiletFlushSwirl = bathroom:FindFirstChild("ToiletFlushSwirl")
if toiletFlushSwirl and not toiletFlushSwirl:IsA("BasePart") then
	toiletFlushSwirl = nil
end
-- RestCFrame is another world-space attribute that can be stale after the
-- completed house is moved. The authored swirl part itself is already in the
-- correct bowl, so make its current pose the only reset source.
local toiletFlushRestCFrame = toiletFlushSwirl and toiletFlushSwirl.CFrame or nil
local toiletFlushRestSize = toiletFlushSwirl and toiletFlushSwirl.Size or nil
if toiletFlushSwirl then
	toiletFlushSwirl:SetAttribute("RestCFrame", toiletFlushRestCFrame)
	toiletFlushSwirl:SetAttribute("RestSize", toiletFlushRestSize)
end
local toiletSeat = bathroom:FindFirstChild("ToiletSeat")
if toiletSeat and not toiletSeat:IsA("Seat") then
	toiletSeat = nil
end
local toiletPrompt = toiletSeat and toiletSeat:FindFirstChild("CooperToiletPrompt")

if toiletSeat and toiletPrompt then
	toiletSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		toiletPrompt.Enabled = toiletSeat.Occupant == nil
	end)
end

local toiletFlushSerial = 0
local toiletFlushTweens = {}
local function playToiletFlush()
	toiletFlushSerial = toiletFlushSerial + 1
	local serial = toiletFlushSerial
	for _, tween in ipairs(toiletFlushTweens) do
		tween:Cancel()
	end
	table.clear(toiletFlushTweens)
	if toiletWater then
		toiletWater:Emit(38)
	end
	if toiletFlushSound then
		local configuredSoundId = interactionRoot:GetAttribute("ToiletFlushSoundId")
		if type(configuredSoundId) ~= "string" and toiletWaterPart then
			configuredSoundId = toiletWaterPart:GetAttribute("FlushSoundId")
		end
		if type(configuredSoundId) == "string" and configuredSoundId ~= "" then
			toiletFlushSound.SoundId = configuredSoundId
			pcall(function()
				toiletFlushSound:Stop()
			end)
			pcall(function()
				toiletFlushSound.TimePosition = 0
			end)
			pcall(function()
				toiletFlushSound:Play()
			end)
			-- The configured Creator Store source is intentionally longer than a
			-- household flush. Only use its opening drain/gurgle and never let an
			-- older delayed callback stop a newer flush.
			task.delay(3, function()
				if serial == toiletFlushSerial and toiletFlushSound and toiletFlushSound.Parent then
					pcall(function()
						toiletFlushSound:Stop()
					end)
				end
			end)
		end
	end
	if not toiletFlushSwirl then
		return
	end
	local restCFrame = toiletFlushRestCFrame
	local restSize = toiletFlushRestSize
	if typeof(restCFrame) ~= "CFrame" then
		restCFrame = toiletFlushSwirl.CFrame
	end
	if typeof(restSize) ~= "Vector3" then
		restSize = toiletFlushSwirl.Size
	end
	toiletFlushSwirl.CFrame = restCFrame
	toiletFlushSwirl.Size = restSize
	toiletFlushSwirl.Transparency = 0.18
	local first = TweenService:Create(toiletFlushSwirl, TweenInfo.new(0.34, Enum.EasingStyle.Quad), {
		CFrame = restCFrame * CFrame.Angles(0, math.rad(165), 0),
		Size = Vector3.new(restSize.X * 0.86, restSize.Y, restSize.Z * 1.35),
		Transparency = 0.3,
	})
	local second = TweenService:Create(toiletFlushSwirl, TweenInfo.new(0.42, Enum.EasingStyle.Quad), {
		CFrame = restCFrame * CFrame.Angles(0, math.rad(330), 0),
		Size = Vector3.new(restSize.X * 0.56, restSize.Y, restSize.Z * 0.8),
		Transparency = 1,
	})
	toiletFlushTweens = { first, second }
	first.Completed:Connect(function(playbackState)
		if serial == toiletFlushSerial and playbackState == Enum.PlaybackState.Completed then
			second:Play()
		end
	end)
	second.Completed:Connect(function()
		if serial == toiletFlushSerial and toiletFlushSwirl and toiletFlushSwirl.Parent then
			toiletFlushSwirl.CFrame = restCFrame
			toiletFlushSwirl.Size = restSize
			toiletFlushSwirl.Transparency = 1
			table.clear(toiletFlushTweens)
		end
	end)
	first:Play()
end

local bathroomToothbrush = findPath(furniture, "OxbloodTileBathroomVanity", "Toothbrush1")
if bathroomToothbrush and not bathroomToothbrush:IsA("BasePart") then
	bathroomToothbrush = nil
end

local function findRigMotor(character, name)
	local candidate = character:FindFirstChild(name, true)
	return candidate and candidate:IsA("Motor6D") and candidate or nil
end

local function createBrushingVisual(player)
	local character = getCharacterParts(player)
	if not character then
		return nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local head = character:FindFirstChild("Head")
	if not hand or not hand:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "CooperBrushingToothbrush"
	model.Parent = character

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.12, 0.12, 1.05)
	handle.Color = Color3.fromRGB(67, 133, 202)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	local handDrop = hand.Name == "RightHand" and 0.22 or math.max(0.35, hand.Size.Y * 0.42)
	handle.CFrame = hand.CFrame
		* CFrame.new(0, -handDrop, -0.34)
		* CFrame.Angles(math.rad(-18), math.rad(8), math.rad(72))
	handle.Parent = model

	local bristles = Instance.new("Part")
	bristles.Name = "Bristles"
	bristles.Size = Vector3.new(0.24, 0.16, 0.20)
	bristles.Color = Color3.fromRGB(242, 246, 242)
	bristles.Material = Enum.Material.SmoothPlastic
	bristles.CanCollide = false
	bristles.CanTouch = false
	bristles.CanQuery = false
	bristles.Massless = true
	bristles.CFrame = handle.CFrame * CFrame.new(0, 0.07, -0.58)
	bristles.Parent = model

	local bristleWeld = Instance.new("WeldConstraint")
	bristleWeld.Name = "BristleWeld"
	bristleWeld.Part0 = handle
	bristleWeld.Part1 = bristles
	bristleWeld.Parent = bristles

	local handWeld = Instance.new("WeldConstraint")
	handWeld.Name = "HandWeld"
	handWeld.Part0 = hand
	handWeld.Part1 = handle
	handWeld.Parent = handle

	local mouthAttachment = Instance.new("Attachment")
	mouthAttachment.Name = "CooperToothpasteFoamAttachment"
	mouthAttachment.Position = Vector3.new(0, -head.Size.Y * 0.12, -head.Size.Z * 0.52)
	mouthAttachment.Parent = head
	local mouthFoam = Instance.new("ParticleEmitter")
	mouthFoam.Name = "ToothpasteFoam"
	mouthFoam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	mouthFoam.Color = ColorSequence.new(
		Color3.fromRGB(248, 252, 255),
		Color3.fromRGB(190, 225, 245)
	)
	mouthFoam.Lifetime = NumberRange.new(0.22, 0.42)
	mouthFoam.Speed = NumberRange.new(0.15, 0.55)
	mouthFoam.Rate = 14
	mouthFoam.Enabled = true
	mouthFoam.SpreadAngle = Vector2.new(28, 28)
	mouthFoam.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0.035),
	})
	mouthFoam.Parent = mouthAttachment

	local visual = {
		active = true,
		model = model,
		mouthAttachment = mouthAttachment,
		motors = {},
	}
	if bathroomToothbrush and bathroomToothbrush.Parent then
		visual.fixtureToothbrush = bathroomToothbrush
		visual.fixtureTransparency = bathroomToothbrush.Transparency
		bathroomToothbrush.Transparency = 1
		local fixturePrompt = bathroomToothbrush:FindFirstChild("CooperBrushTeethPrompt")
		if fixturePrompt and fixturePrompt:IsA("ProximityPrompt") then
			visual.fixturePrompt = fixturePrompt
			visual.fixturePromptWasEnabled = fixturePrompt.Enabled
			fixturePrompt.Enabled = false
		end
	end

	local isR15 = character:FindFirstChild("RightUpperArm") ~= nil
	local function addMotor(motor, pose, oscillationKind)
		if motor then
			table.insert(visual.motors, {
				motor = motor,
				baseC0 = motor.C0,
				pose = pose,
				kind = oscillationKind,
			})
		end
	end
	local hasR15IK = false
	if isR15 then
		-- Modern R15 rigs can be jointed with AnimationConstraints and have no
		-- shoulder/elbow Motor6Ds to pose. IKControl supports both those rigs and
		-- classic R15, while keeping the toothbrush welded to the actual hand.
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		local rightHand = character:FindFirstChild("RightHand")
		local upperTorso = character:FindFirstChild("UpperTorso")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if rightUpperArm and rightHand and humanoid then
			local ikTarget = Instance.new("Attachment")
			ikTarget.Name = "CooperBrushingHandTarget"
			ikTarget.CFrame = CFrame.new(0.38, -0.12, -0.72)
				* CFrame.Angles(0, math.rad(90), math.rad(-8))
			ikTarget.Parent = head

			local ikPole
			if upperTorso and upperTorso:IsA("BasePart") then
				ikPole = Instance.new("Attachment")
				ikPole.Name = "CooperBrushingElbowPole"
				ikPole.Position = Vector3.new(1.4, 0.2, -1.5)
				ikPole.Parent = upperTorso
			end

			local ikControl = Instance.new("IKControl")
			ikControl.Name = "CooperBrushingArmIK"
			ikControl.Type = Enum.IKControlType.Transform
			ikControl.ChainRoot = rightUpperArm
			ikControl.EndEffector = rightHand
			ikControl.Target = ikTarget
			ikControl.Pole = ikPole
			ikControl.SmoothTime = 0.05
			ikControl.Priority = 20
			ikControl.Weight = 0
			ikControl.Enabled = true
			ikControl.Parent = humanoid

			local chainOkay, chainCount = pcall(function()
				return ikControl:GetChainCount()
			end)
			if chainOkay and chainCount > 0 then
				hasR15IK = true
				visual.ikControl = ikControl
				visual.ikTarget = ikTarget
				visual.ikTargetBase = ikTarget.CFrame
				visual.ikPole = ikPole
			else
				ikControl:Destroy()
				ikTarget:Destroy()
				if ikPole then
					ikPole:Destroy()
				end
			end
		end
	end
	if isR15 and not hasR15IK then
		addMotor(
			findRigMotor(character, "RightShoulder"),
			CFrame.Angles(math.rad(66), math.rad(-8), math.rad(-24)),
			"Shoulder"
		)
		addMotor(
			findRigMotor(character, "RightElbow"),
			CFrame.Angles(math.rad(-82), math.rad(4), math.rad(-6)),
			"Elbow"
		)
		addMotor(
			findRigMotor(character, "RightWrist"),
			CFrame.Angles(math.rad(-12), math.rad(8), math.rad(24)),
			"Wrist"
		)
	elseif not isR15 then
		addMotor(
			findRigMotor(character, "Right Shoulder"),
			CFrame.Angles(math.rad(78), math.rad(-8), math.rad(-38)),
			"Shoulder"
		)
	end

	-- Classic joints use C0 instead of Transform because Animator can overwrite
	-- Transform. Modern R15 uses the IK target above. The character is locked at
	-- the sink, so both paths produce a repeatable stroke and restore cleanly.
	local animationStartedAt = now()
	task.spawn(function()
		while visual.active and model.Parent and character.Parent do
			local elapsed = now() - animationStartedAt
			local blend = math.clamp(elapsed / 0.28, 0, 1)
			local phase = math.sin(elapsed * 11.5)
			if visual.ikControl and visual.ikControl.Parent and visual.ikTarget and visual.ikTarget.Parent then
				visual.ikControl.Weight = blend
				visual.ikTarget.CFrame = visual.ikTargetBase
					* CFrame.new(phase * 0.11, phase * 0.025, 0)
					* CFrame.Angles(0, 0, math.rad(phase * 8))
			end
			for _, motorState in ipairs(visual.motors) do
				local motor = motorState.motor
				if motor and motor.Parent then
					local oscillation
					if motorState.kind == "Elbow" then
						oscillation = CFrame.Angles(math.rad(phase * 13), 0, math.rad(phase * 3))
					elseif motorState.kind == "Wrist" then
						oscillation = CFrame.Angles(0, math.rad(phase * 7), math.rad(phase * 18))
					else
						oscillation = CFrame.Angles(math.rad(phase * 4), 0, math.rad(phase * 5))
					end
					local target = motorState.baseC0 * motorState.pose * oscillation
					motor.C0 = motorState.baseC0:Lerp(target, blend)
				end
			end
			task.wait(0.05)
		end
	end)

	return visual
end

local function destroyBrushingVisual(visual)
	if not visual then
		return
	end
	visual.active = false
	if visual.ikControl and visual.ikControl.Parent then
		visual.ikControl.Weight = 0
		visual.ikControl.Enabled = false
		visual.ikControl:Destroy()
	end
	if visual.ikTarget and visual.ikTarget.Parent then
		visual.ikTarget:Destroy()
	end
	if visual.ikPole and visual.ikPole.Parent then
		visual.ikPole:Destroy()
	end
	for _, motorState in ipairs(visual.motors or {}) do
		if motorState.motor and motorState.motor.Parent then
			motorState.motor.C0 = motorState.baseC0
		end
	end
	if visual.fixturePrompt and visual.fixturePrompt.Parent then
		visual.fixturePrompt.Enabled = visual.fixturePromptWasEnabled == true
	end
	if visual.fixtureToothbrush and visual.fixtureToothbrush.Parent then
		visual.fixtureToothbrush.Transparency = visual.fixtureTransparency or 0
	end
	if visual.mouthAttachment and visual.mouthAttachment.Parent then
		visual.mouthAttachment:Destroy()
	end
	if visual.model and visual.model.Parent then
		visual.model:Destroy()
	end
end

local function destroyHygieneVisual(visual)
	if not visual then
		return
	end
	visual.active = false
	if visual.ikControl and visual.ikControl.Parent then
		visual.ikControl.Weight = 0
		visual.ikControl.Enabled = false
		visual.ikControl:Destroy()
	end
	if visual.leftIkControl and visual.leftIkControl.Parent then
		visual.leftIkControl.Weight = 0
		visual.leftIkControl.Enabled = false
		visual.leftIkControl:Destroy()
	end
	if visual.ikTarget and visual.ikTarget.Parent then
		visual.ikTarget:Destroy()
	end
	if visual.leftIkTarget and visual.leftIkTarget.Parent then
		visual.leftIkTarget:Destroy()
	end
	if visual.ikPole and visual.ikPole.Parent then
		visual.ikPole:Destroy()
	end
	for _, motorState in ipairs(visual.motors or {}) do
		if motorState.motor and motorState.motor.Parent then
			motorState.motor.C0 = motorState.baseC0
		end
	end
	if visual.animate and visual.animate.Parent then
		visual.animate.Disabled = visual.animateWasDisabled == true
	end
	if visual.steamAttachment and visual.steamAttachment.Parent then
		visual.steamAttachment:Destroy()
	end
	if visual.model and visual.model.Parent then
		visual.model:Destroy()
	end
end

local function createHygieneVisual(player, mode)
	local character = getCharacterParts(player)
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not humanoid or not root or not rightHand then
		return nil
	end

	local animate = character:FindFirstChild("Animate")
	local visual = {
		active = true,
		motors = {},
		model = Instance.new("Model"),
	}
	visual.model.Name = mode == "Shower" and "CooperShowerWashFX" or "CooperHandWashFX"
	visual.model.Parent = character
	if animate and animate:IsA("LocalScript") then
		visual.animate = animate
		visual.animateWasDisabled = animate.Disabled
		animate.Disabled = true
	end

	local function makeProp(name, size, color, parentPart, localCF)
		local prop = Instance.new("Part")
		prop.Name = name
		prop.Size = size
		prop.Color = color
		prop.Material = Enum.Material.SmoothPlastic
		prop.CanCollide = false
		prop.CanTouch = false
		prop.CanQuery = false
		prop.Massless = true
		prop.CastShadow = false
		prop.CFrame = parentPart.CFrame * localCF
		prop.Parent = visual.model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = parentPart
		weld.Part1 = prop
		weld.Parent = prop
		return prop
	end

	if mode == "Sink" then
		makeProp("SoapBar", Vector3.new(0.35, 0.18, 0.55), Color3.fromRGB(235, 245, 255), rightHand, CFrame.new(0, -0.35, -0.35))
		if leftHand then
			makeProp("SudsyCloth", Vector3.new(0.4, 0.12, 0.5), Color3.fromRGB(210, 230, 245), leftHand, CFrame.new(0, -0.3, -0.3))
		end
	else
		makeProp("Washcloth", Vector3.new(0.55, 0.12, 0.7), Color3.fromRGB(220, 235, 245), rightHand, CFrame.new(0, -0.4, -0.45))
		if leftHand then
			makeProp("WashclothLeft", Vector3.new(0.45, 0.1, 0.55), Color3.fromRGB(210, 228, 240), leftHand, CFrame.new(0, -0.35, -0.4))
		end
	end

	local steamParent = mode == "Shower" and (upperTorso or root) or rightHand
	local attachment = Instance.new("Attachment")
	attachment.Name = "CooperHygieneSteam"
	attachment.Position = mode == "Shower" and Vector3.new(0, 0.4, 0) or Vector3.new(0, -0.15, -0.25)
	attachment.Parent = steamParent
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "BodySteam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250))
	steam.Lifetime = NumberRange.new(0.7, 1.4)
	steam.Speed = NumberRange.new(0.4, 1.2)
	steam.Rate = mode == "Shower" and 40 or 22
	steam.SpreadAngle = Vector2.new(50, 50)
	steam.Acceleration = Vector3.new(0, 1.3, 0)
	steam.LightEmission = 0.15
	steam.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, mode == "Shower" and 0.45 or 0.18),
		NumberSequenceKeypoint.new(1, mode == "Shower" and 2.0 or 0.9),
	})
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Enabled = true
	steam.Parent = attachment
	visual.steamAttachment = attachment
	if mode == "Shower" then
		local droplets = Instance.new("ParticleEmitter")
		droplets.Name = "BodyWater"
		droplets.Texture = "rbxasset://textures/particles/smoke_main.dds"
		droplets.Color = ColorSequence.new(Color3.fromRGB(175, 225, 250))
		droplets.Lifetime = NumberRange.new(0.25, 0.5)
		droplets.Speed = NumberRange.new(2, 5)
		droplets.Rate = 55
		droplets.SpreadAngle = Vector2.new(30, 30)
		droplets.Acceleration = Vector3.new(0, -22, 0)
		droplets.Size = NumberSequence.new(0.08)
		droplets.Enabled = true
		droplets.Parent = attachment
	end

	local isR15 = character:FindFirstChild("RightUpperArm") ~= nil
	local function addMotor(motor, pose, kind)
		if motor then
			table.insert(visual.motors, {
				motor = motor,
				baseC0 = motor.C0,
				pose = pose,
				kind = kind,
			})
		end
	end

	local hasIK = false
	if isR15 and head then
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		local leftUpperArm = character:FindFirstChild("LeftUpperArm")
		if rightUpperArm and rightHand then
			local ikTarget = Instance.new("Attachment")
			ikTarget.Name = "CooperWashHandTarget"
			if mode == "Shower" then
				ikTarget.CFrame = CFrame.new(0.55, -0.35, -0.55) * CFrame.Angles(math.rad(-20), math.rad(90), 0)
			else
				ikTarget.CFrame = CFrame.new(0.45, -0.85, -0.55) * CFrame.Angles(math.rad(-40), math.rad(90), 0)
			end
			ikTarget.Parent = head

			local ikPole
			if upperTorso and upperTorso:IsA("BasePart") then
				ikPole = Instance.new("Attachment")
				ikPole.Name = "CooperWashElbowPole"
				ikPole.Position = Vector3.new(1.5, 0.15, -1.2)
				ikPole.Parent = upperTorso
			end

			local ikControl = Instance.new("IKControl")
			ikControl.Name = "CooperWashArmIK"
			ikControl.Type = Enum.IKControlType.Transform
			ikControl.ChainRoot = rightUpperArm
			ikControl.EndEffector = rightHand
			ikControl.Target = ikTarget
			ikControl.Pole = ikPole
			ikControl.SmoothTime = 0.05
			ikControl.Priority = 25
			ikControl.Weight = 1
			ikControl.Enabled = true
			ikControl.Parent = humanoid

			local chainOkay, chainCount = pcall(function()
				return ikControl:GetChainCount()
			end)
			if chainOkay and chainCount > 0 then
				hasIK = true
				visual.ikControl = ikControl
				visual.ikTarget = ikTarget
				visual.ikTargetBase = ikTarget.CFrame
				visual.ikPole = ikPole
			else
				ikControl:Destroy()
				ikTarget:Destroy()
				if ikPole then
					ikPole:Destroy()
				end
			end
		end
		if hasIK and leftUpperArm and leftHand then
			local leftTarget = Instance.new("Attachment")
			leftTarget.Name = "CooperWashLeftHandTarget"
			if mode == "Shower" then
				leftTarget.CFrame = CFrame.new(-0.5, -0.25, -0.5) * CFrame.Angles(math.rad(-15), math.rad(-90), 0)
			else
				leftTarget.CFrame = CFrame.new(-0.35, -0.8, -0.5) * CFrame.Angles(math.rad(-35), math.rad(-90), 0)
			end
			leftTarget.Parent = head
			local leftIK = Instance.new("IKControl")
			leftIK.Name = "CooperWashLeftArmIK"
			leftIK.Type = Enum.IKControlType.Transform
			leftIK.ChainRoot = leftUpperArm
			leftIK.EndEffector = leftHand
			leftIK.Target = leftTarget
			leftIK.SmoothTime = 0.05
			leftIK.Priority = 24
			leftIK.Weight = 1
			leftIK.Enabled = true
			leftIK.Parent = humanoid
			visual.leftIkControl = leftIK
			visual.leftIkTarget = leftTarget
			visual.leftIkTargetBase = leftTarget.CFrame
		end
	end

	if not hasIK then
		if isR15 then
			addMotor(findRigMotor(character, "RightShoulder"), CFrame.Angles(math.rad(70), math.rad(-10), math.rad(-35)), "Shoulder")
			addMotor(findRigMotor(character, "LeftShoulder"), CFrame.Angles(math.rad(65), math.rad(10), math.rad(32)), "Shoulder")
			addMotor(findRigMotor(character, "RightElbow"), CFrame.Angles(math.rad(-75), 0, 0), "Elbow")
			addMotor(findRigMotor(character, "LeftElbow"), CFrame.Angles(math.rad(-70), 0, 0), "Elbow")
		else
			addMotor(findRigMotor(character, "Right Shoulder"), CFrame.Angles(math.rad(85), math.rad(-12), math.rad(-50)), "Shoulder")
			addMotor(findRigMotor(character, "Left Shoulder"), CFrame.Angles(math.rad(80), math.rad(12), math.rad(48)), "Shoulder")
		end
	end

	local startedAt = now()
	task.spawn(function()
		while visual.active and character.Parent do
			local elapsed = now() - startedAt
			local phase = math.sin(elapsed * (mode == "Shower" and 7.5 or 11))
			if visual.ikControl and visual.ikTarget and visual.ikTarget.Parent then
				visual.ikControl.Weight = 1
				visual.ikTarget.CFrame = visual.ikTargetBase * CFrame.new(phase * 0.12, phase * 0.08, 0)
			end
			if visual.leftIkControl and visual.leftIkTarget and visual.leftIkTarget.Parent then
				visual.leftIkControl.Weight = 1
				visual.leftIkTarget.CFrame = visual.leftIkTargetBase * CFrame.new(-phase * 0.1, -phase * 0.07, 0)
			end
			for _, motorState in ipairs(visual.motors) do
				local motor = motorState.motor
				if motor and motor.Parent then
					local oscillation = if motorState.kind == "Elbow"
						then CFrame.Angles(math.rad(phase * 18), 0, 0)
						else CFrame.Angles(math.rad(phase * 8), 0, math.rad(phase * 12))
					motor.C0 = motorState.baseC0 * motorState.pose * oscillation
				end
			end
			task.wait(0.03)
		end
	end)

	return visual
end

local function restoreActionCharacter(state)
	local humanoid = state.humanoid
	local rootPart = state.rootPart
	if rootPart and rootPart.Parent then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.Anchored = state.rootWasAnchored
	end
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = state.autoRotate
		humanoid.JumpPower = state.jumpPower
		humanoid.JumpHeight = state.jumpHeight
	end
	if state.movementLocked then
		setTimedActionMovementLock(state.player, false)
		state.movementLocked = false
	end
end

local function finishTimedAction(player, state, completed, cancellationMessage)
	if activeActions[player] ~= state then
		return
	end
	activeActions[player] = nil
	if fixtureOwners[state.fixtureKey] == state then
		fixtureOwners[state.fixtureKey] = nil
	end
	if state.onFinish then
		local ok, failure = pcall(state.onFinish, completed)
		if not ok then
			warn("[CooperInteractions] Timed action cleanup failed: " .. tostring(failure))
		end
	end
	restoreActionCharacter(state)
	if player.Parent == Players then
		clientEvent:FireClient(player, "TimedActionEnd", {
			completed = completed == true,
		})
		if cancellationMessage then
			tell(player, cancellationMessage)
		end
	end
end

local function cancelTimedAction(player, cancellationMessage)
	local state = activeActions[player]
	if state then
		finishTimedAction(player, state, false, cancellationMessage)
	end
end

local function startTimedAction(player, key, fixtureKey, label, duration, anchor, onStart, onFinish)
	if activeActions[player] then
		tell(player, "Finish what you're doing first.")
		return false
	end
	local fixtureOwner = fixtureOwners[fixtureKey]
	if fixtureOwner and activeActions[fixtureOwner.player] == fixtureOwner then
		tell(player, fixtureKey == "Shower" and "Someone else is using the shower." or "Someone else is using the sink.")
		return false
	elseif fixtureOwner then
		fixtureOwners[fixtureKey] = nil
	end

	local character, humanoid, rootPart = getCharacterParts(player)
	if not character then
		return false
	end
	actionSerial = actionSerial + 1
	local state = {
		id = actionSerial,
		player = player,
		key = key,
		fixtureKey = fixtureKey,
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		anchor = anchor,
		endsAt = now() + duration,
		rootWasAnchored = rootPart.Anchored,
		autoRotate = humanoid.AutoRotate,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		onFinish = onFinish,
	}
	activeActions[player] = state
	fixtureOwners[fixtureKey] = state

	humanoid.Sit = false
	if not setTimedActionMovementLock(player, true) then
		finishTimedAction(player, state, false, "That interaction could not safely lock movement.")
		return false
	end
	state.movementLocked = true
	humanoid.AutoRotate = false
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if anchor and anchor:IsA("BasePart") then
		rootPart.CFrame = anchor.CFrame
	end
	rootPart.Anchored = true

	if onStart then
		local ok, failure = pcall(onStart)
		if not ok then
			warn("[CooperInteractions] Timed action failed to start: " .. tostring(failure))
			finishTimedAction(player, state, false, "That interaction could not start.")
			return false
		end
	end
	timedFeedback(player, label, duration)

	task.spawn(function()
		while activeActions[player] == state do
			if player.Parent ~= Players
				or player.Character ~= character
				or humanoid.Health <= 0
				or not rootPart.Parent
			then
				finishTimedAction(player, state, false)
				return
			end
			if anchor and (not anchor.Parent or (rootPart.Position - anchor.Position).Magnitude > 4) then
				finishTimedAction(player, state, false, "You moved away, so the action stopped.")
				return
			end
			if now() >= state.endsAt then
				finishTimedAction(player, state, true)
				return
			end
			task.wait(0.12)
		end
	end)
	return true
end

local doorHinge = waitFor(doorAssembly, "FridgeDoorHinge", "BasePart")
local doorPanel = waitFor(doorAssembly, "FridgeDoorPanel", "BasePart")
local refrigeratorBody = waitFor(fridge, "RefrigeratorBody", "BasePart")
local beerPromptAnchor = waitFor(fridgeInterior, "BeerPromptAnchor", "BasePart")
if not doorHinge or not doorPanel or not refrigeratorBody or not beerPromptAnchor then
	warn("[CooperInteractions] Refrigerator interaction anchors are incomplete")
	return
end
local fridgeTogglePrompt = doorHinge:FindFirstChild("CooperFridgeTogglePrompt")
local beerPrompt = beerPromptAnchor:FindFirstChild("CooperFridgeBeerPrompt")
if fridgeTogglePrompt and fridgeTogglePrompt:IsA("ProximityPrompt") then
	fridgeTogglePrompt:SetAttribute("CooperAction", "FridgeToggle")
end
if beerPrompt and beerPrompt:IsA("ProximityPrompt") then
	beerPrompt:SetAttribute("CooperAction", "FridgeBeer")
end
-- The whole house may be repositioned in Studio after the interaction package
-- is installed. CFrame attributes do not follow a moved parent Model, while the
-- actual hinge does. Treat the live authored hinge as the closed pose so a stale
-- absolute attribute can never fling the refrigerator door across the map.
local authoredClosedDoorCFrame = doorHinge:GetAttribute("ClosedCFrame")
local closedDoorCFrame = doorHinge.CFrame
if typeof(authoredClosedDoorCFrame) ~= "CFrame"
	or (authoredClosedDoorCFrame.Position - closedDoorCFrame.Position).Magnitude > 0.01
then
	doorHinge:SetAttribute("ClosedCFrame", closedDoorCFrame)
	doorHinge:SetAttribute("DerivedOpenAngleDegrees", nil)
end
local function deriveFridgeOpenAngle()
	local configured = tonumber(doorHinge:GetAttribute("DerivedOpenAngleDegrees"))
	if configured then
		return configured
	end
	local configuredMagnitude = tonumber(doorHinge:GetAttribute("OpenAngleMagnitude")) or 78
	local angleMagnitude = math.clamp(math.abs(configuredMagnitude), 70, 125)
	local edgeA = doorPanel.Position + doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
	local edgeB = doorPanel.Position - doorPanel.CFrame.RightVector * (doorPanel.Size.X * 0.5)
	local closedFreeEdge = if (edgeA - doorHinge.Position).Magnitude >= (edgeB - doorHinge.Position).Magnitude
		then edgeA
		else edgeB
	local freeEdgeInHingeSpace = closedDoorCFrame:PointToObjectSpace(closedFreeEdge)
	local panelRel = closedDoorCFrame:ToObjectSpace(doorPanel.CFrame)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { fridge }
	local function openScore(degrees)
		local openCF = closedDoorCFrame * CFrame.Angles(0, math.rad(degrees), 0)
		local freeEdge = openCF:PointToWorldSpace(freeEdgeInHingeSpace)
		local towardPlayer = (freeEdge - refrigeratorBody.Position):Dot(refrigeratorBody.CFrame.LookVector)
		local openPanelCF = openCF * panelRel
		local collideCount = 0
		for _, hit in ipairs(workspace:GetPartBoundsInBox(openPanelCF, doorPanel.Size * 0.9, overlapParams)) do
			if hit.CanCollide then
				collideCount += 1
			end
		end
		return towardPlayer * 10 - collideCount * 25
	end
	local derivedAngle = openScore(angleMagnitude) >= openScore(-angleMagnitude) and angleMagnitude or -angleMagnitude
	doorHinge:SetAttribute("DerivedOpenAngleDegrees", derivedAngle)
	doorHinge:SetAttribute("SwingDirectionDerivedFromGeometry", true)
	return derivedAngle
end
local openDoorAngle = deriveFridgeOpenAngle()
local openDoorCFrame = closedDoorCFrame * CFrame.Angles(0, math.rad(openDoorAngle), 0)
local fridgeOpen = false
local fridgeMoving = false
local fridgePromptFeedbackEpoch = 0

-- Only movable gameplay objects should stop the refrigerator door. The authored
-- kitchen geometry sits very close to the door's swept volume, so treating every
-- overlapping static wall/cabinet as a blocker would make the fridge unusable.
local fridgeDoorOverlapParams = OverlapParams.new()
fridgeDoorOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
fridgeDoorOverlapParams.FilterDescendantsInstances = { fridge }

local function isFridgeDoorDynamicObstruction(hit)
	if not hit or not hit:IsA("BasePart") or hit:IsDescendantOf(fridge) then
		return false
	end
	local current = hit
	while current and current ~= workspace do
		if current:IsA("Tool") then
			return true
		end
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return true
		end
		if current:GetAttribute("CooperPickable") == true
			or current:GetAttribute("DeliveryId") ~= nil
			or current:GetAttribute("DeliveryKind") ~= nil
			or current:GetAttribute("CooperRideable") == true
			or current:GetAttribute("CooperYardRideable") == true
			or current.Name == "CooperYardTrike"
		then
			return true
		end
		current = current.Parent
	end
	-- Catch ordinary loose physics props while continuing to ignore anchored
	-- structural pieces such as the counter, walls, and refrigerator surround.
	return hit.CanCollide and not hit.Anchored
end

local function refrigeratorDoorObstruction()
	for _, part in ipairs(doorAssembly:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			local size = part.Size
			local querySize = Vector3.new(
				math.max(0.05, size.X - 0.08),
				math.max(0.05, size.Y - 0.08),
				math.max(0.05, size.Z - 0.08)
			)
			for _, hit in ipairs(workspace:GetPartBoundsInBox(part.CFrame, querySize, fridgeDoorOverlapParams)) do
				if isFridgeDoorDynamicObstruction(hit) then
					return hit
				end
			end
		end
	end
	return nil
end

local function updateBeerVisuals()
	local count = math.max(0, math.floor(tonumber(fridge:GetAttribute("CooperBeerCount")) or 0))
	for _, child in ipairs(fridgeInterior:GetChildren()) do
		local index = child:GetAttribute("BeerVisualIndex") or string.match(child.Name, "^BeerCan(%d+)$")
		if index and child:IsA("BasePart") then
			local isVisible = tonumber(index) <= math.min(count, 6)
			local visibleTransparency = tonumber(child:GetAttribute("VisibleTransparency")) or 0
			child.Transparency = isVisible and visibleTransparency or 1
		end
	end
	if beerPrompt then
		beerPrompt.ObjectText = string.format("Lone Star Beer (%d)", count)
	end
end

local function fridgeBeerCapacity()
	local capacity = 12
	fridge:SetAttribute("CooperExtraShelfCapacity", nil)
	fridge:SetAttribute("CooperBeerCapacity", capacity)
	return capacity
end

local function setFridgeOpen(open)
	if fridgeMoving then
		return false
	end
	if fridgeOpen == open then
		return true
	end
	fridgeMoving = true
	fridgePromptFeedbackEpoch += 1
	if beerPrompt then
		beerPrompt.Enabled = false
	end
	local startingPivot = doorAssembly:GetPivot()
	local blocked = false
	local driver = Instance.new("CFrameValue")
	driver.Value = startingPivot
	local tween
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		if blocked then
			return
		end
		doorAssembly:PivotTo(driver.Value)
		if refrigeratorDoorObstruction() then
			blocked = true
			doorAssembly:PivotTo(startingPivot)
			if tween then
				tween:Cancel()
			end
		end
	end)
	tween = TweenService:Create(
		driver,
		TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = open and openDoorCFrame or closedDoorCFrame }
	)
	tween:Play()
	local playbackState = tween.Completed:Wait()
	connection:Disconnect()
	driver:Destroy()
	local reachedTarget = not blocked and playbackState == Enum.PlaybackState.Completed
	if reachedTarget then
		doorAssembly:PivotTo(open and openDoorCFrame or closedDoorCFrame)
		fridgeOpen = open
	else
		doorAssembly:PivotTo(startingPivot)
	end
	fridgeMoving = false
	if reachedTarget and fridgeTogglePrompt then
		fridgeTogglePrompt.ActionText = fridgeOpen and "Close Fridge" or "Open Fridge"
	elseif fridgeTogglePrompt then
		local feedbackEpoch = fridgePromptFeedbackEpoch
		fridgeTogglePrompt.ActionText = "Fridge blocked"
		task.delay(1.2, function()
			if fridgeTogglePrompt.Parent
				and fridgePromptFeedbackEpoch == feedbackEpoch
				and not fridgeMoving
			then
				fridgeTogglePrompt.ActionText = fridgeOpen and "Close Fridge" or "Open Fridge"
			end
		end)
	end
	if beerPrompt then
		beerPrompt.Enabled = fridgeOpen
	end
	return reachedTarget
end

local automationCommandInstance = fridge:FindFirstChild("AutomationDoorCommand")
if automationCommandInstance and not automationCommandInstance:IsA("BindableFunction") then
	automationCommandInstance:Destroy()
	automationCommandInstance = nil
end
if not automationCommandInstance then
	automationCommandInstance = Instance.new("BindableFunction")
	automationCommandInstance.Name = "AutomationDoorCommand"
	automationCommandInstance.Parent = fridge
end
local automationDoorCommand = automationCommandInstance
local fridgeAutomationHoldCount = 0
local fridgeAutomationOriginalOpen = nil
automationDoorCommand.OnInvoke = function(action, value)
	if typeof(action) == "boolean" then
		if action == false and fridgeAutomationHoldCount > 0 then
			return false, fridgeOpen, true, fridgeAutomationOriginalOpen
		end
		local success = setFridgeOpen(action)
		return success, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	end
	if typeof(action) ~= "string" then
		return false, fridgeOpen, false
	end
	local command = string.lower(action)
	if command == "getstate" then
		return true, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	elseif command == "open" then
		local success = setFridgeOpen(true)
		return success, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	elseif command == "close" then
		if fridgeAutomationHoldCount > 0 then
			return false, fridgeOpen, true, fridgeAutomationOriginalOpen
		end
		local success = setFridgeOpen(false)
		return success, fridgeOpen, false, fridgeAutomationOriginalOpen
	elseif command == "setopen" and typeof(value) == "boolean" then
		if value == false and fridgeAutomationHoldCount > 0 then
			return false, fridgeOpen, true, fridgeAutomationOriginalOpen
		end
		local success = setFridgeOpen(value)
		return success, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	elseif command == "acquireholdopen" or command == "holdopen" then
		if fridgeAutomationHoldCount == 0 then
			fridgeAutomationOriginalOpen = fridgeOpen
		end
		fridgeAutomationHoldCount += 1
		fridge:SetAttribute("AutomationHoldOpen", true)
		local success = setFridgeOpen(true)
		if not success then
			fridgeAutomationHoldCount -= 1
			if fridgeAutomationHoldCount == 0 then
				fridgeAutomationOriginalOpen = nil
				fridge:SetAttribute("AutomationHoldOpen", false)
			end
		end
		return success, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	elseif command == "releaseholdopen" or command == "restore" then
		if fridgeAutomationHoldCount <= 0 then
			return false, fridgeOpen, false, nil
		end
		if fridgeAutomationHoldCount > 1 then
			fridgeAutomationHoldCount -= 1
			return true, fridgeOpen, true, fridgeAutomationOriginalOpen
		end
		local restoreOpen = if typeof(value) == "boolean"
			then value
			else fridgeAutomationOriginalOpen == true
		fridgeAutomationHoldCount = 0
		fridge:SetAttribute("AutomationHoldOpen", false)
		local success = setFridgeOpen(restoreOpen)
		if success then
			fridgeAutomationOriginalOpen = nil
		else
			fridgeAutomationHoldCount = 1
			fridge:SetAttribute("AutomationHoldOpen", true)
		end
		return success, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
	end
	return false, fridgeOpen, fridgeAutomationHoldCount > 0, fridgeAutomationOriginalOpen
end

doorAssembly:PivotTo(closedDoorCFrame)
if beerPrompt then
	beerPrompt.Enabled = false
end
updateBeerVisuals()
fridge:GetAttributeChangedSignal("CooperBeerCount"):Connect(updateBeerVisuals)

local function findBeerTool(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, parent in ipairs({ character, backpack }) do
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("CooperLoneStarBeer") == true then
					return child
				end
			end
		end
	end
	return nil
end

local function makeBeerTool()
	local tool = Instance.new("Tool")
	tool.Name = "Lone Star Beer Bottle"
	tool.ToolTip = "A cold Lone Star bottle for George"
	tool.CanBeDropped = true
	tool.RequiresHandle = true
	-- The bottle is modeled along Handle.X. This grip turns that axis upright and
	-- settles the lower body into either an R6 or R15 right hand.
	tool.Grip = CFrame.new(0, -0.18, -0.48) * CFrame.Angles(0, math.rad(90), 0)
	tool:SetAttribute("CooperLoneStarBeer", true)
	tool:SetAttribute("ContainerType", "Bottle")

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(1.06, 0.46, 0.46)
	handle.Color = Color3.fromRGB(87, 53, 28)
	handle.Material = Enum.Material.Glass
	handle.Transparency = 0.08
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Massless = false
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local function addBottlePart(name, size, relativeCFrame, color, material, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = handle.CFrame * relativeCFrame
		part.Color = color
		part.Material = material
		part.Shape = shape or Enum.PartType.Block
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Name = "BottleWeld"
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	addBottlePart(
		"Shoulder",
		Vector3.new(0.34, 0.38, 0.38),
		CFrame.new(0.59, 0, 0),
		Color3.fromRGB(91, 57, 30),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	addBottlePart(
		"Neck",
		Vector3.new(0.48, 0.22, 0.22),
		CFrame.new(0.82, 0, 0),
		Color3.fromRGB(82, 50, 27),
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	addBottlePart(
		"Cap",
		Vector3.new(0.13, 0.25, 0.25),
		CFrame.new(1.125, 0, 0),
		Color3.fromRGB(190, 37, 38),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	local labelPlate = addBottlePart(
		"LoneStarLabel",
		Vector3.new(0.52, 0.34, 0.035),
		CFrame.new(-0.03, 0, -0.247),
		Color3.fromRGB(235, 224, 190),
		Enum.Material.SmoothPlastic
	)
	local labelGui = Instance.new("SurfaceGui")
	labelGui.Name = "PrintedLabel"
	labelGui.Face = Enum.NormalId.Front
	labelGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	labelGui.PixelsPerStud = 120
	labelGui.Parent = labelPlate
	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.fromScale(1, 1)
	labelText.BackgroundColor3 = Color3.fromRGB(205, 38, 41)
	labelText.BackgroundTransparency = 0.05
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.Font = Enum.Font.GothamBold
	labelText.TextScaled = true
	labelText.Text = "LONE" .. string.char(10) .. "STAR"
	labelText.Parent = labelGui

	return tool
end

local computerAnchor = findPath(
	furniture,
	"YoungSheldonBedroomDetails_V2",
	"SheldonAndMissyRoom",
	"Sheldon1980sComputerDesk",
	"Keyboard"
)
if computerAnchor and not computerAnchor:IsA("BasePart") then
	computerAnchor = nil
end
if not computerAnchor then
	warn("[CooperInteractions] Sheldon's computer keyboard anchor is missing")
end

-- Missy's original route correctly includes the shared bedroom, so her Talk
-- prompt can overlap the keyboard prompt. While a player is actually standing
-- at the computer, temporarily suppress only nearby NPC Talk prompts so the
-- same E press cannot open dialogue instead of the required terminal. The
-- prompt is restored as soon as the player leaves the desk.
local COMPUTER_PRIORITY_PLAYER_DISTANCE = 6
local COMPUTER_PRIORITY_NPC_DISTANCE = 12
task.spawn(function()
	while task.wait(0.15) do
		local computerOccupied = false
		if computerAnchor and computerAnchor.Parent then
			for _, player in ipairs(Players:GetPlayers()) do
				if playerIsNear(player, computerAnchor, COMPUTER_PRIORITY_PLAYER_DISTANCE) then
					computerOccupied = true
					break
				end
			end
		end
		local npcWorld = environment:FindFirstChild("CooperFamilyNPCs")
		if npcWorld then
			for _, descendant in ipairs(npcWorld:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") and descendant.Name == "TalkPrompt" then
					local promptPosition = worldPosition(descendant)
					local suppress = computerOccupied
						and computerAnchor ~= nil
						and promptPosition ~= nil
						and (promptPosition - computerAnchor.Position).Magnitude <= COMPUTER_PRIORITY_NPC_DISTANCE
					local suppressed = descendant:GetAttribute("CooperComputerPrioritySuppressed") == true
					if suppress and not suppressed and descendant.Enabled then
						descendant:SetAttribute("CooperComputerPrioritySuppressed", true)
						descendant.Enabled = false
					elseif not suppress and suppressed then
						descendant:SetAttribute("CooperComputerPrioritySuppressed", nil)
						local npc = descendant:FindFirstAncestorOfClass("Model")
						if not npc
							or (npc:GetAttribute("InConversation") ~= true
								and npc:GetAttribute("BoomboxDancing") ~= true)
						then
							descendant.Enabled = true
						end
					end
				end
			end
		end
	end
end)

local terminalCommands = {
	HELP = "COMMANDS: HELP, DIR, VER, DATE, TIME, WHOAMI, TRAIN, BRISKET, ECHO, CLS, EXIT",
	DIR = "TRAIN.EXE     PHYSICS.BAS     MEEMAW.TXT     AUTOEXEC.BAT",
	VER = "COOPER-DOS 3.11  /  MEDFORD RESEARCH BUILD",
	WHOAMI = "GUEST" .. string.char(92) .. "COOPER_HOUSE",
	TRAIN = "MISSOURI-KANSAS-TEXAS LINE: ALL TRAINS CURRENTLY ON SCHEDULE.",
	BRISKET = "ACCESS DENIED: GEORGE HAS CLASSIFIED THE RUB RECIPE.",
}

local function terminalResponse(player, raw)
	local command = string.sub(tostring(raw or ""), 1, 80)
	command = string.gsub(command, "[%c]", "")
	local upper = string.upper(command)
	local verb = string.match(upper, "^(%S+)") or ""

	if verb == "CLS" or verb == "CLEAR" then
		clientEvent:FireClient(player, "TerminalClear", {})
		return
	elseif verb == "EXIT" then
		terminalSessions[player] = nil
		player:SetAttribute("CooperComputerSessionUntil", nil)
		clientEvent:FireClient(player, "TerminalClose", {})
		return
	elseif verb == "DATE" then
		clientEvent:FireClient(player, "TerminalLine", { command = command, text = os.date("%A, %B %d, %Y") })
		return
	elseif verb == "TIME" then
		clientEvent:FireClient(player, "TerminalLine", { command = command, text = os.date("%I:%M:%S %p") })
		return
	elseif verb == "ECHO" then
		clientEvent:FireClient(player, "TerminalLine", {
			command = command,
			text = string.sub(command, 6),
		})
		return
	end

	local response = terminalCommands[verb]
	if not response then
		response = "Bad command or file name. Type HELP."
	end
	clientEvent:FireClient(player, "TerminalLine", {
		command = command,
		text = response,
	})
end

-- The client renders the cube optimistically, while this matching server state
-- decides whether it was really solved and binds every move to one physical cube.
local cubeMoveDefinitions = {
	U = { axis = 2, layer = 1, quarter = 1 },
	D = { axis = 2, layer = -1, quarter = -1 },
	R = { axis = 1, layer = 1, quarter = 1 },
	L = { axis = 1, layer = -1, quarter = -1 },
	F = { axis = 3, layer = -1, quarter = -1 },
	B = { axis = 3, layer = 1, quarter = 1 },
}
local cubeFaceNames = { "U", "D", "L", "R", "F", "B" }

local function cubeVector(x, y, z)
	return { x, y, z }
end

local function rotateCubeVectorPositive(vector, axis)
	local x, y, z = vector[1], vector[2], vector[3]
	if axis == 1 then
		return cubeVector(x, -z, y)
	elseif axis == 2 then
		return cubeVector(z, y, -x)
	end
	return cubeVector(-y, x, z)
end

local function rotateCubeVector(vector, axis, quarter)
	local result = vector
	local rotationCount = quarter == 1 and 1 or 3
	for _ = 1, rotationCount do
		result = rotateCubeVectorPositive(result, axis)
	end
	return result
end

local function newCubeState()
	local stickers = {}
	local function add(px, py, pz, nx, ny, nz, color)
		table.insert(stickers, {
			position = cubeVector(px, py, pz),
			normal = cubeVector(nx, ny, nz),
			color = color,
		})
	end
	for a = -1, 1 do
		for b = -1, 1 do
			add(a, 1, b, 0, 1, 0, "U")
			add(a, -1, b, 0, -1, 0, "D")
			add(a, b, -1, 0, 0, -1, "F")
			add(a, b, 1, 0, 0, 1, "B")
			add(1, b, a, 1, 0, 0, "R")
			add(-1, b, a, -1, 0, 0, "L")
		end
	end
	return stickers
end

local function applyServerCubeMove(stickers, faceName, inverse)
	local move = cubeMoveDefinitions[faceName]
	if not move then
		return false
	end
	local quarter = move.quarter * (inverse and -1 or 1)
	for _, sticker in ipairs(stickers) do
		if sticker.position[move.axis] == move.layer then
			sticker.position = rotateCubeVector(sticker.position, move.axis, quarter)
			sticker.normal = rotateCubeVector(sticker.normal, move.axis, quarter)
		end
	end
	return true
end

local function cubeNormalFace(normal)
	if normal[2] == 1 then
		return "U"
	elseif normal[2] == -1 then
		return "D"
	elseif normal[3] == -1 then
		return "F"
	elseif normal[3] == 1 then
		return "B"
	elseif normal[1] == 1 then
		return "R"
	end
	return "L"
end

local function serverCubeIsSolved(stickers)
	local expectedColors = {}
	for _, sticker in ipairs(stickers) do
		local face = cubeNormalFace(sticker.normal)
		if expectedColors[face] and expectedColors[face] ~= sticker.color then
			return false
		end
		expectedColors[face] = sticker.color
	end
	return true
end

local function makeCubeScramble()
	local stickers
	local scramble
	repeat
		stickers = newCubeState()
		scramble = {}
		local previousFace = nil
		for _ = 1, 18 do
			local faceName
			repeat
				faceName = cubeFaceNames[math.random(1, #cubeFaceNames)]
			until faceName ~= previousFace
			previousFace = faceName
			local inverse = math.random(0, 1) == 1
			applyServerCubeMove(stickers, faceName, inverse)
			table.insert(scramble, {
				face = faceName,
				inverse = inverse,
			})
		end
	until not serverCubeIsSolved(stickers)
	return stickers, scramble
end

local function playerCanUseCube(player, container)
	if not container or not container.Parent or container:GetAttribute("CubePuzzle") ~= true then
		return false
	end
	local heldState = heldByPlayer[player]
	if heldState and heldState.container == container then
		return true
	end
	if holderByObject[container] then
		return false
	end
	local handle = pickableHandle(container)
	return handle ~= nil and playerIsNear(player, handle, 14)
end

local function beginCubeSession(player, container)
	if not playerCanUseCube(player, container) then
		return false
	end
	for sessionPlayer, session in pairs(cubeSessions) do
		if sessionPlayer ~= player and session.container == container then
			tell(player, "Someone else is solving that cube.")
			return false
		end
	end
	closeCubeSession(player, false)
	terminalSessions[player] = nil
	player:SetAttribute("CooperComputerSessionUntil", nil)
	if player.Parent == Players then
		clientEvent:FireClient(player, "TerminalClose", {})
	end

	cubeSessionSerial = cubeSessionSerial + 1
	local stickers, scramble = makeCubeScramble()
	local session = {
		id = cubeSessionSerial,
		container = container,
		stickers = stickers,
		scramble = scramble,
		moveCount = 0,
		solved = false,
		openedAt = now(),
	}
	cubeSessions[player] = session
	clientEvent:FireClient(player, "CubeOpen", {
		sessionId = session.id,
		scramble = scramble,
	})
	return true
end

local function handleCubeMove(player, payload)
	if type(payload) ~= "table" then
		return
	end
	local session = cubeSessions[player]
	if not session
		or payload.sessionId ~= session.id
		or session.solved
		or not playerCanUseCube(player, session.container)
	then
		closeCubeSession(player, true)
		return
	end
	local faceName = type(payload.face) == "string" and string.upper(payload.face) or ""
	if not cubeMoveDefinitions[faceName] or not passCooldown(player, "CubeMove", 0.03) then
		return
	end
	applyServerCubeMove(session.stickers, faceName, payload.inverse == true)
	session.moveCount = session.moveCount + 1
	session.openedAt = now()
	clientEvent:FireClient(player, "CubeMove", {
		sessionId = session.id,
		face = faceName,
		inverse = payload.inverse == true,
		moveCount = session.moveCount,
	})
	local solved = serverCubeIsSolved(session.stickers)
	reportAuthoritativeAction(player, "CubeMoveCompleted", {
		source = "CooperInteractions",
		face = faceName,
		inverse = payload.inverse == true,
		moveCount = session.moveCount,
		solved = solved,
	})
	if solved then
		session.solved = true
		clientEvent:FireClient(player, "CubeSolved", {
			sessionId = session.id,
			moveCount = session.moveCount,
		})
		tell(player, "Cube solved. Sheldon approves.", 4)
	end
end

local function handlePrompt(prompt, player)
	if not player or not player:IsA("Player") then
		return
	end
	local maximumDistance = math.max(prompt.MaxActivationDistance + 4, 12)
	if not playerIsNear(player, prompt.Parent, maximumDistance) then
		return
	end
	local action = prompt:GetAttribute("CooperAction")
	if type(action) ~= "string" then
		return
	end
	if not passCooldown(player, action, 0.25) then
		return
	end

	if action == "Pickup" then
		holdPickable(player, findPickableContainer(prompt))
	elseif action == "CubePuzzle" then
		beginCubeSession(player, findPickableContainer(prompt))
	elseif action == "ToiletSit" then
		local _, humanoid = getCharacterParts(player)
		if not humanoid or not toiletSeat then
			return
		end
		if toiletSeat.Occupant and toiletSeat.Occupant ~= humanoid then
			tell(player, "The bathroom is occupied.")
			return
		end
		toiletSeat:Sit(humanoid)
		tell(player, "Bathroom break. Press jump when you're finished.", 3.5)
	elseif action == "ToiletFlush" then
		playToiletFlush()
		reportAuthoritativeAction(player, "ToiletFlushed", {
			source = "CooperInteractions",
		})
		tell(player, "Flush!", 1.3)
	elseif action == "ShowerToggle" then
		if fixtureOwners.Shower then
			tell(player, "Someone is using the shower.")
		else
			local turningOn = not showerOn
			setShower(turningOn)
			if not turningOn then
				reportAuthoritativeAction(player, "ShowerStopped", {
					source = "CooperInteractions",
					mode = "Toggle",
				})
			end
		end
	elseif action == "ShowerUse" then
		local showerWasOn = showerOn
		local showerVisual = nil
		startTimedAction(player, action, "Shower", "Taking a shower...", 5, showerUseAnchor, function()
			setShower(true)
			showerVisual = createHygieneVisual(player, "Shower")
		end, function(completed)
			destroyHygieneVisual(showerVisual)
			showerVisual = nil
			setShower(showerWasOn)
			if completed and player.Parent == Players then
				if not showerOn then
					reportAuthoritativeAction(player, "ShowerStopped", {
						source = "CooperInteractions",
						duration = 5,
						mode = "CompletedUse",
					})
				end
				tell(player, "Fresh, clean, and ready for Medford.")
			end
		end)
	elseif action == "SinkWash" then
		local washVisual = nil
		startTimedAction(player, action, "Sink", "Washing hands...", 3.5, sinkUseAnchor, function()
			setSinkFlow(true)
			washVisual = createHygieneVisual(player, "Sink")
		end, function(completed)
			destroyHygieneVisual(washVisual)
			washVisual = nil
			setSinkFlow(false)
			if completed then
				reportAuthoritativeAction(player, "HandsWashed", {
					source = "CooperInteractions",
					duration = 3.5,
				})
				tell(player, "Hands washed.")
			end
		end)
	elseif action == "BrushTeeth" then
		local brushingVisual = nil
		startTimedAction(player, action, "Sink", "Brushing teeth...", 5, sinkUseAnchor, function()
			brushingVisual = createBrushingVisual(player)
			if toothbrushFoam then
				-- The countertop emitter is only a fallback for a nonstandard rig
				-- that has neither an R6 nor R15 right hand/head.
				toothbrushFoam.Enabled = brushingVisual == nil
			end
		end, function(completed)
			destroyBrushingVisual(brushingVisual)
			brushingVisual = nil
			if toothbrushFoam then
				toothbrushFoam.Enabled = false
			end
			if completed then
				reportAuthoritativeAction(player, "TeethBrushed", {
					source = "CooperInteractions",
					duration = 5,
				})
				tell(player, "All brushed and ready for the day.")
			end
		end)
	elseif action == "Computer" then
		if not computerAnchor then
			tell(player, "The computer is unavailable right now.")
			return
		end
		-- CooperGame owns the button-driven family task terminal.
		closeCubeSession(player, true)
		terminalSessions[player] = now()
		-- CooperGame validates every beer/component order against this server-only
		-- session plus live distance to the keyboard. A client cannot order remotely
		-- by firing the terminal RemoteEvent from elsewhere in the map.
		player:SetAttribute("CooperComputerSessionUntil", workspace:GetServerTimeNow() + 300)
		local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
		local gameRemotes = gameRoot and gameRoot:FindFirstChild("Remotes")
		local feedbackRemote = gameRemotes and gameRemotes:FindFirstChild("Feedback")
		if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
			feedbackRemote:FireClient(player, {
				kind = "TerminalOpen",
				text = "Computer ready",
			})
		end
	elseif action == "FridgeToggle" then
		if fridge:GetAttribute("AutomationHoldOpen") == true and fridgeOpen then
			tell(player, "BeerBot is using the fridge. Give it a moment.")
			return
		end
		task.spawn(setFridgeOpen, not fridgeOpen)
	elseif action == "FridgeBeer" then
		if not fridgeOpen then
			return
		end
		local count = math.max(0, math.floor(tonumber(fridge:GetAttribute("CooperBeerCount")) or 0))
		local heldBeer = findBeerTool(player)
		if heldBeer then
			if count >= fridgeBeerCapacity() then
				tell(player, "The fridge is full.")
				return
			end
			heldBeer:Destroy()
			fridge:SetAttribute("CooperBeerCount", count + 1)
			tell(player, "Lone Star stored in the fridge.")
		elseif count > 0 then
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				makeBeerTool().Parent = backpack
				fridge:SetAttribute("CooperBeerCount", count - 1)
				tell(player, "You took a Lone Star Beer.")
			end
		else
			tell(player, "George cleaned out the fridge.")
		end
		updateBeerVisuals()
	end
end

local connectedPrompts = {}
local function connectPrompt(descendant)
	if descendant:IsA("ProximityPrompt") and descendant:GetAttribute("CooperAction") then
		if not connectedPrompts[descendant] then
			connectedPrompts[descendant] = true
			descendant.Triggered:Connect(function(player)
				handlePrompt(descendant, player)
			end)
		end
	end
end

for _, descendant in ipairs(house:GetDescendants()) do
	connectPrompt(descendant)
	if descendant:GetAttribute("CooperPickable") == true then
		homePivots[descendant] = descendant:GetPivot()
	end
end
house.DescendantAdded:Connect(connectPrompt)

requestEvent.OnServerEvent:Connect(function(player, action, payload)
	if type(action) ~= "string" then
		return
	end
	if action == "HeldAction" then
		if payload == "Throw" and passCooldown(player, "Throw", 0.3) then
			releaseHeld(player, true)
		elseif payload == "Drop" and passCooldown(player, "Drop", 0.3) then
			releaseHeld(player, false)
		elseif payload == "Solve" then
			local state = heldByPlayer[player]
			if state
				and state.container:GetAttribute("CubePuzzle") == true
				and passCooldown(player, "CubeOpen", 0.5)
			then
				beginCubeSession(player, state.container)
			end
		end
	elseif action == "TerminalCommand" then
		if type(payload) ~= "string" then
			return
		end
		-- Re-materializing after the explicit type check also keeps nonstrict Luau's
		-- broad RemoteEvent payload union out of the validated command path.
		local terminalCommand = tostring(payload)
		if not string.match(terminalCommand, "%S")
			or not terminalSessions[player]
			or not playerIsNear(player, computerAnchor, 18)
			or not passCooldown(player, "TerminalCommand", 0.18)
		then
			return
		end
		terminalSessions[player] = now()
		terminalResponse(player, terminalCommand)
		local reportedCommand = string.sub(terminalCommand, 1, 80)
		reportedCommand = string.gsub(reportedCommand, "[%c]", "")
		if string.match(reportedCommand, "%S") then
			reportAuthoritativeAction(player, "TerminalCommandRun", {
				source = "CooperInteractions",
				command = reportedCommand,
			})
		end
	elseif action == "TerminalClose" then
		terminalSessions[player] = nil
		player:SetAttribute("CooperComputerSessionUntil", nil)
	elseif action == "CubeMove" then
		handleCubeMove(player, payload)
	elseif action == "CubeReshuffle" then
		local session = cubeSessions[player]
		if type(payload) == "table"
			and session
			and payload.sessionId == session.id
			and playerCanUseCube(player, session.container)
			and passCooldown(player, "CubeReshuffle", 0.5)
		then
			beginCubeSession(player, session.container)
		end
	elseif action == "CubeGiveUpThrow" then
		local session = cubeSessions[player]
		if type(payload) == "table"
			and session
			and payload.sessionId == session.id
			and passCooldown(player, "CubeGiveUpThrow", 0.5)
		then
			local sessionCube = session.container
			local heldState = heldByPlayer[player]
			local heldSessionCube = heldState and heldState.container == sessionCube
			closeCubeSession(player, true)
			if heldSessionCube then
				releaseHeld(player, true)
			elseif not throwLoosePickable(player, sessionCube) then
				tell(player, "The cube is too far away to throw.")
			end
		end
	elseif action == "CubeClose" then
		local session = cubeSessions[player]
		if session and type(payload) == "table" and payload.sessionId == session.id then
			closeCubeSession(player, false)
		end
	end
end)

local function cleanupPlayer(player)
	cancelTimedAction(player)
	releaseHeld(player, false)
	closeCubeSession(player, false)
	terminalSessions[player] = nil
	player:SetAttribute("CooperComputerSessionUntil", nil)
	cooldowns[player] = nil
end

Players.PlayerRemoving:Connect(cleanupPlayer)
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		cancelTimedAction(player)
		releaseHeld(player, false)
		closeCubeSession(player, true)
		terminalSessions[player] = nil
		player:SetAttribute("CooperComputerSessionUntil", nil)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterRemoving:Connect(function()
		cancelTimedAction(player)
		releaseHeld(player, false)
		closeCubeSession(player, true)
		terminalSessions[player] = nil
		player:SetAttribute("CooperComputerSessionUntil", nil)
	end)
end

task.spawn(function()
	while task.wait(2) do
		local currentTime = now()
		for container, homePivot in pairs(homePivots) do
			if container.Parent and not holderByObject[container] then
				local pivotOk, currentPivot = pcall(container.GetPivot, container)
				local distanceFromHome = pivotOk and (currentPivot.Position - homePivot.Position).Magnitude or math.huge
				local expiredAwayFromHome = releasedAt[container]
					and currentTime - releasedAt[container] > 45
					and distanceFromHome > 8
				local recentlyReleased = releasedAt[container] and currentTime - releasedAt[container] < 3
				local fellThroughFloor = pivotOk and currentPivot.Position.Y < -20 and not recentlyReleased
				local shouldReset = not pivotOk
					or fellThroughFloor
					or distanceFromHome > 150
					or expiredAwayFromHome
				if shouldReset then
					closeOtherCubeSessions(container, nil)
					local handle = pickableHandle(container)
					if handle then
						releaseEpoch[container] = (releaseEpoch[container] or 0) + 1
						handle.Anchored = true
						handle.CanCollide = false
						handle.Massless = false
						handle.AssemblyLinearVelocity = Vector3.zero
						handle.AssemblyAngularVelocity = Vector3.zero
						pcall(function()
							handle:SetNetworkOwner(nil)
						end)
						container:PivotTo(homePivot)
						handle.CanCollide = true
						releasedAt[container] = nil
						setPromptEnabled(container, true)
					end
				end
			end
		end
		for player, openedAt in pairs(terminalSessions) do
			if player.Parent ~= Players or currentTime - openedAt > 300 or not playerIsNear(player, computerAnchor, 22) then
				terminalSessions[player] = nil
				if player.Parent == Players then
					player:SetAttribute("CooperComputerSessionUntil", nil)
					clientEvent:FireClient(player, "TerminalClose", {})
				end
			end
		end
		for player, session in pairs(cubeSessions) do
			if player.Parent ~= Players
				or currentTime - session.openedAt > 600
				or not playerCanUseCube(player, session.container)
			then
				closeCubeSession(player, true)
			end
		end
	end
end)

print("[CooperInteractions] Server interaction controller ready")
