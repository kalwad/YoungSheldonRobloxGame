--!nonstrict
-- Server-authoritative producers for the seven physical Cooper campaign tasks.
-- Install as ServerScriptService.CooperTaskWorld after cooper_task_world_install.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TASK_WORLD_CONTROLLER_VERSION = "2026-07-11.1"
local ROOT_TIMEOUT = 30
local SNAPSHOT_INTERVAL = 0.35
local REGISTRATION_INTERVAL = 12
local COMPLETION_CONFIRM_TIMEOUT = 1.25

local EVENT_SPECS = {
	{
		eventKey = "GeorgeDrinkDelivered",
		taskId = "BringGeorgeDrink",
		stationName = "GeorgeDrinkStation",
		action = "DeliverGeorgeDrink",
	},
	{
		eventKey = "TVRemoteReturned",
		taskId = "FindTVRemote",
		stationName = "TVRemoteReturnStation",
		action = "DeliverItem",
		itemId = "TVRemote",
	},
	{
		eventKey = "FootballChannelSet",
		taskId = "SetFootballChannel",
		stationName = "FootballChannelStation",
		action = "SetFootballChannel",
	},
	{
		eventKey = "MachineCrateDelivered",
		taskId = "CarryMachineCrate",
		stationName = "MachineCrateDeliveryZone",
		action = "DeliverItem",
		itemId = "MachineCrate",
	},
	{
		eventKey = "GarageObstructionCleared",
		taskId = "FixGarageObstruction",
		stationName = "GarageObstructionClearZone",
		action = "DeliverItem",
		itemId = "GarageObstruction",
	},
	{
		eventKey = "PorchDeliveryRetrieved",
		taskId = "RetrievePorchDelivery",
		stationName = "PorchDeliveryReturnZone",
		action = "DeliverItem",
		itemId = "PorchDelivery",
	},
	{
		eventKey = "StormItemSecured",
		taskId = "SecureStormItem",
		stationName = "StormSafeZone",
		action = "DeliverItem",
		itemId = "StormItem",
	},
}

local environment = workspace:WaitForChild("CooperHouseEnvironment", ROOT_TIMEOUT)
assert(environment and environment:IsA("Model"), "CooperHouseEnvironment was not installed")
local house = environment:WaitForChild("CooperHouse", ROOT_TIMEOUT)
assert(house and house:IsA("Model"), "CooperHouseEnvironment.CooperHouse was not installed")
local taskWorld = environment:WaitForChild("CooperTaskWorld", ROOT_TIMEOUT)
assert(taskWorld and taskWorld:IsA("Model"), "CooperTaskWorld was not installed")
local stationsFolder = taskWorld:WaitForChild("Stations", ROOT_TIMEOUT)
local itemsFolder = taskWorld:WaitForChild("Items", ROOT_TIMEOUT)
assert(stationsFolder:IsA("Folder"), "CooperTaskWorld.Stations must be a Folder")
assert(itemsFolder:IsA("Folder"), "CooperTaskWorld.Items must be a Folder")
taskWorld:SetAttribute("ControllerReady", false)
taskWorld:SetAttribute("RegisteredActionCount", 0)

local campaignRoot = ReplicatedStorage:WaitForChild("CooperGame", ROOT_TIMEOUT)
assert(campaignRoot and campaignRoot:IsA("Folder"), "ReplicatedStorage.CooperGame was not installed")
local configModule = campaignRoot:WaitForChild("Config", ROOT_TIMEOUT)
assert(configModule and configModule:IsA("ModuleScript"), "CooperGame.Config was not installed")
local Config = require(configModule)
local campaignState = campaignRoot:WaitForChild(Config.WorldStateName, ROOT_TIMEOUT)
assert(campaignState and campaignState:IsA("Folder"), "CooperGame state folder was not installed")

local serverEvents = ServerScriptService:WaitForChild(Config.ServerEventsName, ROOT_TIMEOUT)
assert(serverEvents and serverEvents:IsA("Folder"), Config.ServerEventsName .. " was not installed")
local reportAction = serverEvents:WaitForChild("ReportAction", ROOT_TIMEOUT)
local registerAction = serverEvents:WaitForChild("RegisterAction", ROOT_TIMEOUT)
local campaignAPI = serverEvents:WaitForChild("API", ROOT_TIMEOUT)
assert(reportAction:IsA("BindableEvent"), "CooperGame ReportAction must be a BindableEvent")
assert(registerAction:IsA("BindableEvent"), "CooperGame RegisterAction must be a BindableEvent")
assert(campaignAPI:IsA("BindableFunction"), "CooperGame API must be a BindableFunction")

local interactionClient = nil
do
	local interactionRemotes = ReplicatedStorage:FindFirstChild("CooperInteractionsRemotes")
	local candidate = interactionRemotes and interactionRemotes:FindFirstChild("Client")
	if candidate and candidate:IsA("RemoteEvent") then
		interactionClient = candidate
	end
end

local specByEventKey = {}
local eventKeyByTaskId = {}
local promptSpec = {}
local activeByEventKey = {}
local eventLocks = {}
local playerCooldowns = {}
local completionSerial = 0
local lastRegistrationAt = 0
local lastSnapshotRevision = -1

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function tell(player, message, duration)
	if interactionClient and player and player.Parent == Players then
		interactionClient:FireClient(player, "Toast", {
			text = tostring(message),
			duration = duration or 2.5,
		})
	end
end

local function healthyCharacter(player)
	if not player or player.Parent ~= Players then
		return nil, nil, nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, rootPart
end

local function worldPosition(instance)
	if not instance then
		return nil
	elseif instance:IsA("Attachment") then
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
	local _, _, rootPart = healthyCharacter(player)
	local targetPosition = worldPosition(instance)
	return rootPart ~= nil
		and targetPosition ~= nil
		and (rootPart.Position - targetPosition).Magnitude <= maximumDistance
end

local function passCooldown(player, key, delaySeconds)
	local byKey = playerCooldowns[player]
	if not byKey then
		byKey = {}
		playerCooldowns[player] = byKey
	end
	local currentTime = serverNow()
	if (byKey[key] or 0) > currentTime then
		return false
	end
	byKey[key] = currentTime + delaySeconds
	return true
end

local function pickupPrompt(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	local prompt = handle and handle:FindFirstChild("PickupPrompt")
	return prompt and prompt:IsA("ProximityPrompt") and prompt or nil
end

local function itemMarker(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	local marker = handle and handle:FindFirstChild("TaskMarker")
	return marker and marker:IsA("BillboardGui") and marker or nil
end

local function setItemMarkerEnabled(tool, enabled)
	local marker = itemMarker(tool)
	if marker then
		marker.Enabled = enabled
	end
	local highlight = tool and tool:FindFirstChild("TaskHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight.Enabled = enabled
	end
end

local function resetItem(tool, taskActive)
	if not tool or not tool.Parent then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local homeCFrame = tool:GetAttribute("HomeCFrame")
	if not handle or not handle:IsA("BasePart") or typeof(homeCFrame) ~= "CFrame" then
		warn("[CooperTaskWorld] Cannot reset malformed item " .. tool:GetFullName())
		return
	end

	local prompt = pickupPrompt(tool)
	if prompt then
		prompt.Enabled = false
	end
	tool:SetAttribute("OwnerUserId", 0)
	tool:SetAttribute("TaskActive", taskActive == true)
	tool.Parent = itemsFolder
	handle.Anchored = true
	handle.Massless = false
	handle.CanCollide = true
	handle.CanTouch = false
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	handle.CFrame = homeCFrame
	pcall(function()
		handle:SetNetworkOwner(nil)
	end)
	if prompt then
		prompt.Enabled = taskActive == true
	end
	setItemMarkerEnabled(tool, taskActive == true)
end

local function setStationState(spec, isActive)
	local station = spec.station
	local prompt = spec.prompt
	station:SetAttribute("TaskActive", isActive)
	if prompt then
		prompt.Enabled = isActive and not eventLocks[spec.eventKey]
	end
	local marker = station:FindFirstChild("TaskMarker", true)
	if marker and marker:IsA("BillboardGui") then
		marker.Enabled = isActive
	end
	local lamp = station:FindFirstChild("StatusLamp", true)
	if lamp and lamp:IsA("BasePart") then
		local recentlyCompletedAt = tonumber(station:GetAttribute("LastCompletedAt")) or -math.huge
		if serverNow() - recentlyCompletedAt <= 2.5 then
			lamp.Color = Color3.fromRGB(72, 220, 105)
			lamp.Material = Enum.Material.Neon
		elseif isActive then
			lamp.Color = Color3.fromRGB(255, 190, 55)
			lamp.Material = Enum.Material.Neon
		else
			lamp.Color = Color3.fromRGB(92, 96, 101)
			lamp.Material = Enum.Material.Metal
		end
	end
end

for _, spec in ipairs(EVENT_SPECS) do
	assert(not specByEventKey[spec.eventKey], "Duplicate Cooper task event " .. spec.eventKey)
	specByEventKey[spec.eventKey] = spec
	eventKeyByTaskId[spec.taskId] = spec.eventKey

	local station = stationsFolder:FindFirstChild(spec.stationName)
	assert(station and station:IsA("Model"), "Missing Cooper task station " .. spec.stationName)
	local prompt = station:FindFirstChild("TaskPrompt", true)
	assert(prompt and prompt:IsA("ProximityPrompt"), spec.stationName .. " has no TaskPrompt")
	assert(prompt:GetAttribute("CooperTaskEventKey") == spec.eventKey, spec.stationName .. " event key mismatch")
	assert(prompt:GetAttribute("CooperTaskAction") == spec.action, spec.stationName .. " action mismatch")
	spec.station = station
	spec.prompt = prompt
	promptSpec[prompt] = spec
	activeByEventKey[spec.eventKey] = false

	if spec.itemId then
		local tool = itemsFolder:FindFirstChild(spec.itemId)
		assert(tool and tool:IsA("Tool"), "Missing Cooper task item " .. spec.itemId)
		assert(tool:GetAttribute("CooperTaskGenerated") == true, spec.itemId .. " is not a generated task item")
		assert(tool:GetAttribute("CooperTaskItemId") == spec.itemId, spec.itemId .. " item identity mismatch")
		assert(tool:GetAttribute("CooperTaskEventKey") == spec.eventKey, spec.itemId .. " event key mismatch")
		local itemPrompt = pickupPrompt(tool)
		assert(itemPrompt, spec.itemId .. " has no PickupPrompt")
		assert(itemPrompt:GetAttribute("CooperTaskAction") == "PickupItem", spec.itemId .. " pickup action mismatch")
		assert(itemPrompt:GetAttribute("CooperTaskEventKey") == spec.eventKey, spec.itemId .. " pickup event mismatch")
		assert(itemPrompt:GetAttribute("CooperTaskItemId") == spec.itemId, spec.itemId .. " pickup identity mismatch")
		spec.item = tool
		promptSpec[itemPrompt] = spec
	end
end

local function readActiveTasks()
	local ok, snapshot = pcall(function()
		return campaignAPI:Invoke("GetSnapshot")
	end)
	if not ok or type(snapshot) ~= "table" or type(snapshot.tasks) ~= "table" then
		taskWorld:SetAttribute("SnapshotHealthy", false)
		return nil, nil
	end

	local current = {}
	local records = {}
	for eventKey in pairs(specByEventKey) do
		current[eventKey] = false
	end
	for _, record in ipairs(snapshot.tasks) do
		if type(record) == "table" and type(record.id) == "string" then
			local eventKey = eventKeyByTaskId[record.id]
			if eventKey then
				current[eventKey] = true
				records[eventKey] = record
			end
		end
	end
	taskWorld:SetAttribute("SnapshotHealthy", true)
	taskWorld:SetAttribute("LastSnapshotAt", serverNow())
	lastSnapshotRevision = tonumber(snapshot.revision) or lastSnapshotRevision
	return current, records
end

local function validOwnerPlayer(tool)
	local ownerUserId = tonumber(tool:GetAttribute("OwnerUserId")) or 0
	if ownerUserId <= 0 then
		return nil
	end
	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return nil
	end
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if tool.Parent ~= character and tool.Parent ~= backpack then
		return nil
	end
	return player
end

local function keepItemSane(spec, isActive)
	local tool = spec.item
	if not tool then
		return
	end
	if not isActive then
		if tool.Parent ~= itemsFolder or (tonumber(tool:GetAttribute("OwnerUserId")) or 0) ~= 0 then
			resetItem(tool, false)
		else
			local prompt = pickupPrompt(tool)
			if prompt then
				prompt.Enabled = false
			end
			setItemMarkerEnabled(tool, false)
		end
		return
	end

	local ownerUserId = tonumber(tool:GetAttribute("OwnerUserId")) or 0
	if ownerUserId > 0 then
		if not validOwnerPlayer(tool) then
			resetItem(tool, true)
		end
		return
	end
	if tool.Parent ~= itemsFolder then
		resetItem(tool, true)
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local homeCFrame = tool:GetAttribute("HomeCFrame")
	if not handle or not handle:IsA("BasePart") or typeof(homeCFrame) ~= "CFrame"
		or handle.Position.Y < -20
		or (handle.Position - homeCFrame.Position).Magnitude > 12
	then
		resetItem(tool, true)
		return
	end
	local prompt = pickupPrompt(tool)
	if prompt then
		prompt.Enabled = true
	end
	setItemMarkerEnabled(tool, true)
end

local function setGarageDoorObstruction(isActive)
	local garage = environment:FindFirstChild("DetachedGarage")
	local door = garage and garage:FindFirstChild("InteractiveSectionalGarageDoor")
	if not door then
		return
	end
	door:SetAttribute("CooperTaskObstructed", isActive)
	local prompt = door:FindFirstChild("ProximityPrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local wasDisabledByTask = prompt:GetAttribute("DisabledByCooperTaskWorld") == true
	if isActive then
		prompt:SetAttribute("DisabledByCooperTaskWorld", true)
		prompt.Enabled = false
	elseif wasDisabledByTask then
		prompt:SetAttribute("DisabledByCooperTaskWorld", false)
		local state = door:GetAttribute("DoorState")
		if state == "Open" or state == "Closed" or state == "Blocked" then
			prompt.Enabled = true
		end
	end
end

local function applyActiveTasks(current)
	for _, spec in ipairs(EVENT_SPECS) do
		local wasActive = activeByEventKey[spec.eventKey] == true
		local isActive = current[spec.eventKey] == true
		activeByEventKey[spec.eventKey] = isActive
		if spec.item and isActive and not wasActive then
			resetItem(spec.item, true)
		elseif spec.item then
			keepItemSane(spec, isActive)
		end
		setStationState(spec, isActive)
	end

	setGarageDoorObstruction(current.GarageObstructionCleared == true)
	taskWorld:SetAttribute("LastAppliedRevision", lastSnapshotRevision)
end

local function refreshAndApply()
	local current = readActiveTasks()
	if not current then
		-- Fail closed without erasing a legitimate player's in-flight carry. A fresh
		-- successful snapshot decides whether that item should resume or reset.
		for _, spec in ipairs(EVENT_SPECS) do
			setStationState(spec, false)
			if spec.item then
				local prompt = pickupPrompt(spec.item)
				if prompt then
					prompt.Enabled = false
				end
			end
		end
		return nil
	end
	applyActiveTasks(current)
	return current
end

local function registerAllActions()
	for _, spec in ipairs(EVENT_SPECS) do
		registerAction:Fire(spec.eventKey, true)
	end
	lastRegistrationAt = serverNow()
	taskWorld:SetAttribute("RegisteredActionCount", #EVENT_SPECS)
	taskWorld:SetAttribute("LastRegistrationAt", lastRegistrationAt)
end

local function waitForRegistrationAcknowledgement()
	local deadline = serverNow() + 3
	repeat
		if tonumber(campaignState:GetAttribute("SupportedActionCount")) == 14 then
			return
		end
		task.wait(0.04)
	until serverNow() >= deadline
	error("CooperGame did not acknowledge all seven CooperTaskWorld action registrations")
end

local function waitForCampaignReady()
	local deadline = serverNow() + ROOT_TIMEOUT
	repeat
		local current = readActiveTasks()
		if current then
			return current
		end
		task.wait(0.2)
	until serverNow() >= deadline
	error("CooperGame API did not become ready before CooperTaskWorld timed out")
end

local function takeGeneratedItem(player, spec)
	if not passCooldown(player, "Pickup:" .. spec.itemId, 0.45) then
		return
	end
	local current = readActiveTasks()
	if not current or current[spec.eventKey] ~= true then
		return
	end
	local tool = spec.item
	local handle = tool and tool:FindFirstChild("Handle")
	local prompt = pickupPrompt(tool)
	local character, humanoid = healthyCharacter(player)
	if not tool or not handle or not handle:IsA("BasePart") or not prompt or not character or not humanoid then
		return
	end
	if not playerIsNear(player, handle, prompt.MaxActivationDistance + 2.5) then
		return
	end
	if tool.Parent ~= itemsFolder or (tonumber(tool:GetAttribute("OwnerUserId")) or 0) ~= 0 then
		tell(player, "Someone else is carrying that task item.")
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	tool:SetAttribute("OwnerUserId", player.UserId)
	prompt.Enabled = false
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	tell(player, "Carry " .. tostring(tool:GetAttribute("DisplayName") or tool.Name) .. " to the glowing task zone.")
end

local function exactHeldTaskItem(player, spec)
	local character, _, rootPart = healthyCharacter(player)
	local tool = spec.item
	local handle = tool and tool:FindFirstChild("Handle")
	if not character or not rootPart or not tool or not handle or not handle:IsA("BasePart") then
		return false
	end
	if tool.Parent ~= character or tool:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end
	if tool:GetAttribute("CooperTaskGenerated") ~= true
		or tool:GetAttribute("CooperTaskItemId") ~= spec.itemId
		or tool:GetAttribute("CooperTaskEventKey") ~= spec.eventKey
	then
		return false
	end
	local stationPosition = worldPosition(spec.prompt.Parent)
	return stationPosition ~= nil
		and (rootPart.Position - stationPosition).Magnitude <= spec.prompt.MaxActivationDistance + 2.5
		and (handle.Position - stationPosition).Magnitude <= spec.prompt.MaxActivationDistance + 4
end

local function heldLoneStar(player)
	local character = healthyCharacter(player)
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool")
			and child:GetAttribute("CooperLoneStarBeer") == true
			and child.Name == "Lone Star Beer Bottle"
		then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and playerIsNear(player, specByEventKey.GeorgeDrinkDelivered.prompt.Parent, 14) then
				return child
			end
		end
	end
	return nil
end

local function setFootballScreen()
	local furniture = house:FindFirstChild("FurnitureAndProps")
	local television = furniture and furniture:FindFirstChild("WoodCabinetCRTTelevision")
	local screen = television and television:FindFirstChild("CurvedGlassScreen")
	local surface = screen and screen:FindFirstChild("CooperTVBroadcast")
	local program = surface and surface:FindFirstChild("Program")
	local safeArea = program and program:FindFirstChild("SafeArea")
	local title = safeArea and safeArea:FindFirstChild("ProgramTitle")
	local subtitle = safeArea and safeArea:FindFirstChild("ProgramSubtitle")
	local liveBug = safeArea and safeArea:FindFirstChild("LiveBug")
	local ticker = program and program:FindFirstChild("Ticker")
	if title and title:IsA("TextLabel") then
		title.Text = "MEDFORD HIGH FOOTBALL"
	end
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.Text = "FRIDAY NIGHT HOME GAME\nLIVE FROM MEDFORD, TEXAS"
	end
	if liveBug and liveBug:IsA("TextLabel") then
		liveBug.Text = "LIVE • FOOTBALL"
	end
	if ticker and ticker:IsA("TextLabel") then
		ticker.Text = "MEDFORD 14 • VISITORS 10 • THIRD QUARTER • GO MAVERICKS"
	end
	if program and program:IsA("Frame") then
		program.BackgroundColor3 = Color3.fromRGB(43, 78, 43)
	end
	if television then
		television:SetAttribute("CooperChannel", "Football")
		television:SetAttribute("CooperChannelSetAt", serverNow())
	end
end

local function holdFootballScreen(seconds)
	task.spawn(function()
		local untilTime = serverNow() + seconds
		while taskWorld.Parent and serverNow() < untilTime do
			setFootballScreen()
			task.wait(0.25)
		end
	end)
end

local function reportAndConfirm(player, spec, validator, metadata)
	if eventLocks[spec.eventKey] or not passCooldown(player, "Complete:" .. spec.eventKey, 0.85) then
		return false
	end
	eventLocks[spec.eventKey] = true
	setStationState(spec, true)

	local success = false
	local sourceConnection = nil
	local ok, failure = xpcall(function()
		local current, records = readActiveTasks()
		if not current or current[spec.eventKey] ~= true or not records[spec.eventKey] then
			return
		end
		if not playerIsNear(player, spec.prompt.Parent, spec.prompt.MaxActivationDistance + 2.5) then
			return
		end
		if not validator() then
			return
		end

		completionSerial += 1
		local completionToken = string.format(
			"CooperTaskWorld:%s:%d:%d",
			spec.eventKey,
			player.UserId,
			completionSerial
		)
		local observedCompletion = campaignState:GetAttribute("LastCompletionSource") == completionToken
		sourceConnection = campaignState:GetAttributeChangedSignal("LastCompletionSource"):Connect(function()
			if campaignState:GetAttribute("LastCompletionSource") == completionToken then
				observedCompletion = true
			end
		end)

		local reportMetadata = type(metadata) == "table" and table.clone(metadata) or {}
		reportMetadata.source = completionToken
		reportMetadata.taskWorldVersion = TASK_WORLD_CONTROLLER_VERSION
		reportAction:Fire(spec.eventKey, player, reportMetadata)

		local deadline = serverNow() + COMPLETION_CONFIRM_TIMEOUT
		repeat
			task.wait(0.04)
			if campaignState:GetAttribute("LastCompletionSource") == completionToken then
				observedCompletion = true
			end
			local latest = readActiveTasks()
			if latest and latest[spec.eventKey] ~= true then
				break
			end
		until serverNow() >= deadline
		-- The unique server-authored source token is written only after CooperGame has
		-- rewarded and removed this exact task. It remains authoritative even if a
		-- simultaneous completion overwrites the campaign's other "Last*" attributes.
		success = observedCompletion
	end, function(message)
		return debug.traceback(tostring(message), 2)
	end)
	if sourceConnection then
		sourceConnection:Disconnect()
	end

	if not ok then
		warn("[CooperTaskWorld] Completion failed for " .. spec.eventKey .. ": " .. tostring(failure))
	end
	eventLocks[spec.eventKey] = nil

	local latest = readActiveTasks()
	if latest then
		if success then
			spec.station:SetAttribute("LastCompletedAt", serverNow())
		end
		applyActiveTasks(latest)
	else
		setStationState(spec, false)
	end
	return success
end

local function deliverGeneratedItem(player, spec)
	local success = reportAndConfirm(player, spec, function()
		if not exactHeldTaskItem(player, spec) then
			tell(player, "Equip the marked " .. tostring(spec.item:GetAttribute("DisplayName") or spec.item.Name) .. " first.")
			return false
		end
		return true
	end, {
		itemId = spec.itemId,
	})
	if success then
		resetItem(spec.item, false)
	end
end

local function deliverGeorgeDrink(player, spec)
	local beer = nil
	local success = reportAndConfirm(player, spec, function()
		beer = heldLoneStar(player)
		if not beer then
			tell(player, "Hold a Lone Star bottle from the kitchen fridge first.")
			return false
		end
		return true
	end, {
		itemId = "LoneStarBeer",
	})
	if success and beer and beer.Parent then
		beer:Destroy()
	end
end

local function setFootballChannel(player, spec)
	local success = reportAndConfirm(player, spec, function()
		return healthyCharacter(player) ~= nil
	end, {
		channel = "MedfordFootball",
	})
	if success then
		holdFootballScreen(10)
	end
end

for prompt, spec in pairs(promptSpec) do
	prompt.Triggered:Connect(function(player)
		if not player or player.Parent ~= Players then
			return
		end
		local action = prompt:GetAttribute("CooperTaskAction")
		if action == "PickupItem" then
			takeGeneratedItem(player, spec)
		elseif action == "DeliverItem" then
			task.spawn(deliverGeneratedItem, player, spec)
		elseif action == "DeliverGeorgeDrink" then
			task.spawn(deliverGeorgeDrink, player, spec)
		elseif action == "SetFootballChannel" then
			task.spawn(setFootballChannel, player, spec)
		end
	end)
end

local function resetItemsOwnedBy(player)
	for _, spec in ipairs(EVENT_SPECS) do
		local tool = spec.item
		if tool and tool:GetAttribute("OwnerUserId") == player.UserId then
			resetItem(tool, activeByEventKey[spec.eventKey] == true)
		end
	end
end

local function setupPlayer(player)
	player.CharacterRemoving:Connect(function()
		resetItemsOwnedBy(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	resetItemsOwnedBy(player)
	playerCooldowns[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

script.Destroying:Connect(function()
	pcall(function()
		for _, spec in ipairs(EVENT_SPECS) do
			registerAction:Fire(spec.eventKey, false)
			activeByEventKey[spec.eventKey] = false
			setStationState(spec, false)
			if spec.item then
				resetItem(spec.item, false)
			end
		end
	end)
	setGarageDoorObstruction(false)
	if taskWorld.Parent then
		taskWorld:SetAttribute("ControllerReady", false)
		taskWorld:SetAttribute("RegisteredActionCount", 0)
	end
end)

local initialTasks = waitForCampaignReady()
registerAllActions()
waitForRegistrationAcknowledgement()
applyActiveTasks(initialTasks)
taskWorld:SetAttribute("ControllerVersion", TASK_WORLD_CONTROLLER_VERSION)
taskWorld:SetAttribute("ControllerReady", true)

task.spawn(function()
	while script.Parent and taskWorld.Parent do
		local ok, failure = xpcall(function()
			if serverNow() - lastRegistrationAt >= REGISTRATION_INTERVAL then
				registerAllActions()
			end
			refreshAndApply()
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		if not ok then
			warn("[CooperTaskWorld] World synchronization recovered from an error: " .. tostring(failure))
		end
		task.wait(SNAPSHOT_INTERVAL)
	end
end)

print("[CooperTaskWorld] Seven authoritative task producers ready")
