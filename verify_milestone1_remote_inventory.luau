--!nonstrict
-- Milestone 1 read-only remote, prompt, and server-boundary security inventory.
--
-- Run from the Studio command bar in either:
--   * the Cooper House place;
--   * the lobby authoring place (whose Studio preview package contains the
--     canonical house scripts); or
--   * a stripped private release candidate.
--
-- This verifier reads source and the current replicated network surface. It
-- never invokes a Remote/Bindable, triggers a prompt, changes an attribute,
-- creates/destroys an Instance, teleports, or touches MemoryStore/DataStore.
-- Static evidence is not a substitute for the published malformed-payload,
-- replay, flood, teleport-ticket, or multi-client tests in PLAN.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local failures = {}
local advisories = {}
local checks = 0
local inventoryRows = 0

local function check(condition, message)
	checks += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function advise(condition, message)
	if not condition then
		table.insert(advisories, message)
	end
	return condition
end

local function contains(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function countPlain(source, marker)
	if type(source) ~= "string" or marker == "" then
		return 0
	end
	local count = 0
	local cursor = 1
	while true do
		local found = string.find(source, marker, cursor, true)
		if not found then
			return count
		end
		count += 1
		cursor = found + #marker
	end
end

local function markers(source, label, expected)
	for _, marker in ipairs(expected) do
		check(contains(source, marker), label .. " is missing security marker: " .. marker)
	end
end

local function lacks(source, label, forbidden)
	for _, marker in ipairs(forbidden) do
		check(not contains(source, marker), label .. " contains forbidden authority marker: " .. marker)
	end
end

local function sourceOf(instance, label)
	check(instance ~= nil, label .. " is missing")
	if not instance then
		return nil
	end
	check(instance:IsA("LuaSourceContainer"), label .. " must be a Luau source container")
	if not instance:IsA("LuaSourceContainer") then
		return nil
	end
	local ok, source = pcall(function()
		return instance.Source
	end)
	check(ok and type(source) == "string" and #source > 100, label .. " source is unreadable or empty")
	return ok and type(source) == "string" and source or nil
end

local searchRoots = {
	ServerScriptService,
	StarterPlayerScripts,
	Workspace,
	ServerStorage,
}

local function findNamedSource(name, className, preferredParent)
	if preferredParent then
		local direct = preferredParent:FindFirstChild(name)
		if direct and direct:IsA(className) then
			return direct
		end
	end
	for _, root in ipairs(searchRoots) do
		if root then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant.Name == name and descendant:IsA(className) then
					return descendant
				end
			end
		end
	end
	return nil
end

local function findGameConfig()
	local liveRoot = ReplicatedStorage:FindFirstChild("CooperGame")
	local liveConfig = liveRoot and liveRoot:FindFirstChild("Config")
	if liveConfig and liveConfig:IsA("ModuleScript") then
		return liveConfig
	end
	for _, root in ipairs(searchRoots) do
		if root then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant.Name == "Config"
					and descendant:IsA("ModuleScript")
					and descendant.Parent
					and descendant.Parent.Name == "CooperGame"
				then
					return descendant
				end
			end
		end
	end
	return nil
end

local function stringSet(list)
	local set = {}
	for _, value in ipairs(list) do
		set[value] = true
	end
	return set
end

local function sameStringSet(actual, expected, label)
	for value in pairs(expected) do
		check(actual[value] == true, label .. " is missing action " .. value)
	end
	for value in pairs(actual) do
		check(expected[value] == true, label .. " exposes undocumented action " .. value)
	end
end

local function literalCallActions(source, receiver, method)
	local actions = {}
	if type(source) ~= "string" then
		return actions
	end
	local pattern = receiver .. ":" .. method .. "%s*%(%s*[\"']([^\"']+)[\"']"
	for action in string.gmatch(source, pattern) do
		actions[action] = true
	end
	return actions
end

local function callReceivers(source, method)
	local receivers = {}
	if type(source) ~= "string" then
		return receivers
	end
	local pattern = "([%a_][%w_]*):" .. method .. "%("
	for receiver in string.gmatch(source, pattern) do
		receivers[receiver] = true
	end
	return receivers
end

local function comparedLiteralActions(source, variableName)
	local actions = {}
	if type(source) ~= "string" then
		return actions
	end
	local pattern = "[^%w_]" .. variableName .. "%s*==%s*[\"']([^\"']+)[\"']"
	for action in string.gmatch("\n" .. source, pattern) do
		actions[action] = true
	end
	return actions
end

local function assertCallInventory(source, label, method, expectedCount)
	local actual = countPlain(source, ":" .. method .. "(")
	check(
		actual == expectedCount,
		string.format("%s %s inventory drifted: expected %d sites, found %d", label, method, expectedCount, actual)
	)
	inventoryRows += actual
end

local function handlerSection(source, marker, nextMarker)
	if type(source) ~= "string" then
		return nil
	end
	local startAt = string.find(source, marker, 1, true)
	if not startAt then
		return nil
	end
	local endAt = nextMarker and string.find(source, nextMarker, startAt + #marker, true) or nil
	return string.sub(source, startAt, (endAt or (#source + 1)) - 1)
end

local sourceInstances = {
	gameServer = findNamedSource("CooperGame", "Script", ServerScriptService),
	gameClient = findNamedSource("CooperGame", "LocalScript", StarterPlayerScripts),
	gameConfig = findGameConfig(),
	taskWorld = findNamedSource("CooperTaskWorld", "Script", ServerScriptService),
	interactionsServer = findNamedSource("CooperInteractions", "Script", ServerScriptService),
	interactionsClient = findNamedSource("CooperInteractions", "LocalScript", StarterPlayerScripts),
	rideablesServer = findNamedSource("CooperYardRideables", "Script", ServerScriptService),
	rideablesClient = findNamedSource("CooperYardRideables", "LocalScript", StarterPlayerScripts),
	movementServer = findNamedSource("CooperMovement", "Script", ServerScriptService),
	sprintClient = findNamedSource("CooperSprint", "LocalScript", StarterPlayerScripts),
	dialogueServer = findNamedSource("CooperFamilyDialogue", "Script", ServerScriptService),
	dialogueClient = findNamedSource("CooperFamilyDialogue", "LocalScript", StarterPlayerScripts),
	bunkerServer = findNamedSource("CooperBunker", "Script", ServerScriptService),
	bunkerClient = findNamedSource("CooperBunkerClient", "LocalScript", StarterPlayerScripts),
	frontDoor = findNamedSource("FrontDoorController", "Script", nil),
	patioDoor = findNamedSource("PatioDoorController", "Script", nil),
	garageDoor = findNamedSource("GeorgieGarageDoorController", "Script", nil),
	lobbyServer = findNamedSource("CooperLobby", "Script", ServerScriptService),
	lobbyClient = findNamedSource("CooperLobby", "LocalScript", StarterPlayerScripts),
	studioBridge = findNamedSource("StudioHousePreview", "Script", ServerScriptService),
}

local houseSourcePresent = sourceInstances.gameServer ~= nil or sourceInstances.gameClient ~= nil
local lobbySourcePresent = sourceInstances.lobbyServer ~= nil or sourceInstances.lobbyClient ~= nil
check(houseSourcePresent or lobbySourcePresent, "Neither canonical house nor lobby source is available to audit")

local sources = {}
if houseSourcePresent then
	for key, label in pairs({
		gameServer = "CooperGame server",
		gameClient = "CooperGame client",
		gameConfig = "CooperGame.Config",
		taskWorld = "CooperTaskWorld",
		interactionsServer = "CooperInteractions server",
		interactionsClient = "CooperInteractions client",
		rideablesServer = "CooperYardRideables server",
		rideablesClient = "CooperYardRideables client",
		movementServer = "CooperMovement server",
		sprintClient = "CooperSprint client",
		dialogueServer = "CooperFamilyDialogue server",
		dialogueClient = "CooperFamilyDialogue client",
		bunkerServer = "CooperBunker server",
		bunkerClient = "CooperBunker client",
		frontDoor = "FrontDoorController",
		patioDoor = "PatioDoorController",
		garageDoor = "GeorgieGarageDoorController",
	}) do
		sources[key] = sourceOf(sourceInstances[key], label)
	end
end
if lobbySourcePresent then
	sources.lobbyServer = sourceOf(sourceInstances.lobbyServer, "CooperLobby server")
	sources.lobbyClient = sourceOf(sourceInstances.lobbyClient, "CooperLobby client")
end
if sourceInstances.studioBridge then
	sources.studioBridge = sourceOf(sourceInstances.studioBridge, "StudioHousePreview bridge")
end

-- Every canonical client-to-server call site. Count assertions deliberately
-- fail closed when a new call is added without updating the security matrix.
if houseSourcePresent then
	markers(sources.gameConfig, "CooperGame feature boundary", {
		"Config.Features = table.freeze({",
		"Lobby = true",
		"Horror = false",
		"SecretExploration = false",
		"TimeMachineFinale = false",
		"Postgame = false",
		"StudioScenarioTools = false",
	})
	do
		assertCallInventory(sources.gameClient, "CooperGame client", "FireServer", 17)
		sameStringSet(
			literalCallActions(sources.gameClient, "requestEvent", "FireServer"),
			stringSet({
				"TutorialSeen",
				"CloseComputer",
				"OrderBeer",
				"OrderMachinePart",
				"OrderTaskUpgrade",
				"UpgradeBoomboxAutoplay",
				"OrderBoombox",
				"OrderSecretBunker",
				"LegacyCommand",
				"HiddenSeen",
				"RequestSnapshot",
			}),
			"CooperGame Request client"
		)
		sameStringSet(
			literalCallActions(sources.gameClient, "bankHackEvent", "FireServer"),
			stringSet({ "Start", "Input", "Cancel" }),
			"CooperGame BankHack client"
		)
	end
	do
		assertCallInventory(sources.bunkerClient, "CooperBunker client", "FireServer", 4)
		sameStringSet(
			literalCallActions(sources.bunkerClient, "requestEvent", "FireServer"),
			stringSet({ "OrderChemistrySetup", "CloseBunkerComputer", "RequestSnapshot" }),
			"CooperBunker Request client"
		)
	end
	do
		assertCallInventory(sources.interactionsClient, "CooperInteractions client", "FireServer", 13)
		sameStringSet(
			literalCallActions(sources.interactionsClient, "requestEvent", "FireServer"),
			stringSet({
				"HeldAction",
				"TerminalClose",
				"TerminalCommand",
				"CubeMove",
				"CubeReshuffle",
				"CubeGiveUpThrow",
				"CubeClose",
			}),
			"CooperInteractions Request client"
		)
		markers(sources.interactionsClient, "CooperInteractions held actions", {
			'requestEvent:FireServer("HeldAction", "Throw")',
			'requestEvent:FireServer("HeldAction", "Drop")',
			'requestEvent:FireServer("HeldAction", "Solve")',
		})
	end
	do
		assertCallInventory(sources.rideablesClient, "CooperYardRideables client", "FireServer", 5)
		sameStringSet(
			literalCallActions(sources.rideablesClient, "rideablesEvent", "FireServer"),
			stringSet({ "SwingPump", "ResetSwing", "TrikeControl", "ResetTrike" }),
			"CooperYardRideables client"
		)
	end
	do
		assertCallInventory(sources.sprintClient, "CooperSprint client", "FireServer", 2)
		markers(sources.sprintClient, "CooperSprint client intent sites", {
			"sprintIntent:FireServer(intent)",
			"sprintIntent:FireServer(false)",
		})
	end
	do
		assertCallInventory(sources.dialogueClient, "CooperFamilyDialogue client", "FireServer", 3)
		sameStringSet(
			literalCallActions(sources.dialogueClient, "sessionRemote", "FireServer"),
			stringSet({ "Close" }),
			"CooperFamilyDialogue client"
		)
	end
end

if lobbySourcePresent then
	assertCallInventory(sources.lobbyClient, "CooperLobby client", "InvokeServer", 1)
	markers(sources.lobbyClient, "CooperLobby client request choke point", {
		"local function request(action: string, payload: any?, quiet: boolean?)",
		"return requestRemote:InvokeServer(action, payload)",
		'request("PlaySolo")',
		'request("CreateParty")',
		'request("Rejoin")',
		'request("InviteFriends")',
		'request("SetReady", not authoritativeSelfReady)',
		'request("Launch")',
		'request("LeaveParty")',
		'request("Refresh", nil, true)',
	})
end

-- Server-to-client RemoteEvent calls and client listeners complete the network
-- inventory. These surfaces convey presentation only; they have no server
-- listener that could turn a forged client packet into authority.
if houseSourcePresent then
	for _, record in ipairs({
		{
			source = sources.gameServer,
			label = "CooperGame server",
			fireClientCount = 3,
			fireAllCount = 1,
			receivers = { "snapshotEvent", "feedbackEvent", "bankHackEvent" },
			allReceivers = { "feedbackEvent" },
		},
		{
			source = sources.interactionsServer,
			label = "CooperInteractions server",
			fireClientCount = 18,
			fireAllCount = 0,
			receivers = { "clientEvent", "feedbackRemote" },
			allReceivers = {},
		},
		{
			source = sources.rideablesServer,
			label = "CooperYardRideables server",
			fireClientCount = 0,
			fireAllCount = 0,
			receivers = {},
			allReceivers = {},
		},
		{
			source = sources.movementServer,
			label = "CooperMovement server",
			fireClientCount = 6,
			fireAllCount = 0,
			receivers = { "sprintIntent" },
			allReceivers = {},
		},
		{
			source = sources.dialogueServer,
			label = "CooperFamilyDialogue server",
			fireClientCount = 3,
			fireAllCount = 0,
			receivers = { "sessionRemote" },
			allReceivers = {},
		},
		{
			source = sources.bunkerServer,
			label = "CooperBunker server",
			fireClientCount = 3,
			fireAllCount = 0,
			receivers = { "event" },
			allReceivers = {},
		},
		{
			source = sources.taskWorld,
			label = "CooperTaskWorld",
			fireClientCount = 0,
			fireAllCount = 0,
			receivers = {},
			allReceivers = {},
		},
	}) do
		assertCallInventory(record.source, record.label, "FireClient", record.fireClientCount)
		assertCallInventory(record.source, record.label, "FireAllClients", record.fireAllCount)
		sameStringSet(
			callReceivers(record.source, "FireClient"),
			stringSet(record.receivers),
			record.label .. " FireClient receivers"
		)
		sameStringSet(
			callReceivers(record.source, "FireAllClients"),
			stringSet(record.allReceivers),
			record.label .. " FireAllClients receivers"
		)
		check(countPlain(record.source, ":InvokeClient(") == 0, record.label .. " must not synchronously invoke clients")
	end
	for _, record in ipairs({
		{ source = sources.gameClient, label = "CooperGame client", count = 3 },
		{ source = sources.bunkerClient, label = "CooperBunker client", count = 3 },
		{ source = sources.interactionsClient, label = "CooperInteractions client", count = 1 },
		{ source = sources.rideablesClient, label = "CooperYardRideables client", count = 0 },
		{ source = sources.sprintClient, label = "CooperSprint client", count = 1 },
		{ source = sources.dialogueClient, label = "CooperFamilyDialogue client", count = 1 },
	}) do
		local actual = countPlain(record.source, "OnClientEvent:Connect")
		check(
			actual == record.count,
			string.format("%s listener inventory drifted: expected %d, found %d", record.label, record.count, actual)
		)
		check(countPlain(record.source, "OnClientInvoke") == 0, record.label .. " must not expose OnClientInvoke")
		inventoryRows += actual
	end
end
if lobbySourcePresent then
	assertCallInventory(sources.lobbyServer, "CooperLobby server", "FireClient", 2)
	assertCallInventory(sources.lobbyServer, "CooperLobby server", "FireAllClients", 0)
	sameStringSet(
		callReceivers(sources.lobbyServer, "FireClient"),
		stringSet({ "stateRemote", "clientCommandRemote" }),
		"CooperLobby FireClient receivers"
	)
	check(countPlain(sources.lobbyServer, ":InvokeClient(") == 0, "CooperLobby must not synchronously invoke clients")
	local listenerCount = countPlain(sources.lobbyClient, "OnClientEvent:Connect")
	check(listenerCount == 2, "CooperLobby client must have exactly State and ClientCommand listeners")
	check(countPlain(sources.lobbyClient, "OnClientInvoke") == 0, "CooperLobby client must not expose OnClientInvoke")
	inventoryRows += listenerCount
end
if sources.studioBridge then
	assertCallInventory(sources.studioBridge, "StudioHousePreview bridge", "FireClient", 1)
	assertCallInventory(sources.studioBridge, "StudioHousePreview bridge", "FireAllClients", 0)
	sameStringSet(
		callReceivers(sources.studioBridge, "FireClient"),
		stringSet({ "remote" }),
		"StudioHousePreview FireClient receivers"
	)
end

-- Every canonical server network handler. Server-to-client-only remotes must
-- never acquire a listener without an explicit inventory update.
if houseSourcePresent then
	check(countPlain(sources.gameServer, "OnServerEvent:Connect") == 2, "CooperGame must expose exactly two C2S handlers")
	check(countPlain(sources.interactionsServer, "OnServerEvent:Connect") == 1, "CooperInteractions must expose exactly one C2S handler")
	check(countPlain(sources.rideablesServer, "OnServerEvent:Connect") == 1, "CooperYardRideables must expose exactly one C2S handler")
	check(countPlain(sources.movementServer, "OnServerEvent:Connect") == 1, "CooperMovement must expose exactly one C2S handler")
	check(countPlain(sources.dialogueServer, "OnServerEvent:Connect") == 1, "CooperFamilyDialogue must expose exactly one C2S handler")
	for _, record in ipairs({
		{ source = sources.taskWorld, label = "CooperTaskWorld" },
		{ source = sources.bunkerServer, label = "CooperBunker" },
		{ source = sources.frontDoor, label = "FrontDoorController" },
		{ source = sources.patioDoor, label = "PatioDoorController" },
		{ source = sources.garageDoor, label = "GeorgieGarageDoorController" },
	}) do
		check(countPlain(record.source, "OnServerEvent:Connect") == 0, record.label .. " must not expose an unregistered C2S RemoteEvent")
		check(countPlain(record.source, "OnServerInvoke") == 0, record.label .. " must not expose an unregistered C2S RemoteFunction")
	end
	inventoryRows += 6
end
if lobbySourcePresent then
	check(countPlain(sources.lobbyServer, "OnServerInvoke") == 1, "CooperLobby must expose exactly one C2S RemoteFunction handler")
	check(countPlain(sources.lobbyServer, "OnServerEvent:Connect") == 0, "CooperLobby State/ClientCommand must stay server-to-client only")
	inventoryRows += 1
end

-- House RemoteEvent guards: action/type, party/role/phase, live context/range,
-- rate, replay/session identity, and server-authored values.
if houseSourcePresent then
	do
		local requestHandler = handlerSection(
			sources.gameServer,
			"requestEvent.OnServerEvent:Connect(function(player, action, payload)",
			"\nlocal function setupLeaderstats"
		)
		check(requestHandler ~= nil, "CooperGame Request handler is missing")
		sameStringSet(
			comparedLiteralActions(requestHandler, "action"),
			stringSet({
				"RequestSnapshot",
				"OrderChemistrySetup",
				"TutorialSeen",
				"CloseComputer",
				"CloseBunkerComputer",
				"OrderBeer",
				"OrderMachinePart",
				"OrderBoombox",
				"OrderTaskUpgrade",
				"UpgradeBoomboxAutoplay",
				"OrderSecretBunker",
				"HiddenSeen",
				"LegacyCommand",
			}),
			"CooperGame Request server actions"
		)
		markers(requestHandler, "CooperGame Request handler", {
			'if type(action) ~= "string" then',
			'if action == "RequestSnapshot" then',
			"not passSnapshotCooldown(player)",
			"not passRequestCooldown(player)",
			"not profile or not profile.loaded or profile.releasing or not partyIsMember(player)",
			'if action == "OrderChemistrySetup" and not validBunkerComputerSession(player) then',
			"and not validComputerSession(player)",
			'if action == "TutorialSeen" then',
			'elseif action == "HiddenSeen" then',
			"not partyCanProgress()",
			"record.markerName ~= markerName",
			"not playerNear(player, marker, 14)",
		})
		markers(sources.gameServer, "CooperGame terminal/host authority", {
			"local function validComputerSession(player)",
			"expiresAt > serverNow()",
			"playerNear(player, computerAnchor, 14)",
			"local function validBunkerComputerSession(player)",
			'player:GetAttribute("CooperSecretBunkerUnlocked") == true',
			"playerNear(player, anchor, 14)",
			"local function hostMutationAllowed(profile)",
			"not partyIsHost(profile.player) or hostProfile() ~= profile",
			"TransactionRuntime.commitHostPurchase(",
			"TransactionRuntime.commitPersistentTransition(",
			"TransactionRuntime.logicalOperationKind(",
		})
	end
	do
		local bankHandler = handlerSection(
			sources.gameServer,
			"bankHackEvent.OnServerEvent:Connect(function(player, action, payload)",
			"\nrequestEvent.OnServerEvent:Connect"
		)
		check(bankHandler ~= nil, "CooperGame BankHack handler is missing")
		sameStringSet(
			comparedLiteralActions(bankHandler, "action"),
			stringSet({ "Start", "Input", "Cancel" }),
			"CooperGame BankHack server actions"
		)
		markers(bankHandler, "CooperGame BankHack handler", {
			'if type(action) ~= "string" then',
			"not profile or not profile.loaded or profile.releasing or not partyIsMember(player)",
			'action ~= "Cancel" and not partyCanProgress()',
			'if action == "Start" then',
			"not passRequestCooldown(player)",
			'elseif action == "Input" then',
			'elseif action == "Cancel" then',
			'type(payload) == "table" and payload.sessionId or nil',
			"reportedId ~= session.id",
			"Unknown action",
		})
		markers(sources.gameServer, "CooperGame BankHack input authority", {
			"local function submitBankHackInput(profile, payload)",
			'if type(payload) ~= "table" then',
			'type(payload.sessionId) == "string"',
			"#sessionId > 128",
			"session.id ~= sessionId",
			"not validComputerSession(profile.player)",
			"not passBankInputCooldown(profile.player)",
			'type(rawKey) ~= "string" or #rawKey ~= 1',
			"not bankKeySet[key]",
			"serverNow()",
			"session.inputDeadline",
		})
	end
	do
		local interactionHandler = handlerSection(
			sources.interactionsServer,
			"requestEvent.OnServerEvent:Connect(function(player, action, payload)",
			"\nlocal function cleanupPlayer"
		)
		check(interactionHandler ~= nil, "CooperInteractions Request handler is missing")
		sameStringSet(
			comparedLiteralActions(interactionHandler, "action"),
			stringSet({
				"HeldAction",
				"TerminalCommand",
				"TerminalClose",
				"CubeMove",
				"CubeReshuffle",
				"CubeGiveUpThrow",
				"CubeClose",
			}),
			"CooperInteractions server actions"
		)
		markers(interactionHandler, "CooperInteractions Request handler", {
			'if type(action) ~= "string" then',
			'if action == "HeldAction" then',
			'payload == "Throw"',
			'payload == "Drop"',
			'payload == "Solve"',
			'elseif action == "TerminalCommand" then',
			'type(payload) ~= "string"',
			"not terminalSessions[player]",
			"not playerIsNear(player, computerAnchor, 18)",
			'not passCooldown(player, "TerminalCommand", 0.18)',
			'elseif action == "CubeMove" then',
			'elseif action == "CubeReshuffle" then',
			'payload.sessionId == session.id',
			"playerCanUseCube(player, session.container)",
			'passCooldown(player, "CubeGiveUpThrow", 0.5)',
		})
		markers(sources.interactionsServer, "CooperInteractions cube/ownership authority", {
			"local function handleCubeMove(player, payload)",
			'if type(payload) ~= "table" then',
			"payload.sessionId ~= session.id",
			"not playerCanUseCube(player, session.container)",
			"type(payload.face)",
			"not cubeMoveDefinitions[faceName]",
			'passCooldown(player, "CubeMove", 0.03)',
			"holderByObject[state.container]",
			"SetNetworkOwner(nil)",
		})
	end
	do
		local rideableHandler = handlerSection(
			sources.rideablesServer,
			"rideablesEvent.OnServerEvent:Connect(function(player, action, valueA, valueB)",
			"\nPlayers.PlayerRemoving:Connect"
		)
		check(rideableHandler ~= nil, "CooperYardRideables handler is missing")
		sameStringSet(
			comparedLiteralActions(rideableHandler, "action"),
			stringSet({ "SwingPump", "ResetSwing", "TrikeControl", "ResetTrike" }),
			"CooperYardRideables server actions"
		)
		markers(rideableHandler, "CooperYardRideables handler", {
			'if typeof(action) ~= "string" then',
			'action == "SwingPump"',
			"playerFromSeat(swingSeat) ~= player",
			"passesRateLimit(player, action, SWING_PUMP_INTERVAL)",
			"not finiteNumber(valueA)",
			"math.clamp(valueA, -1, 1)",
			'action == "ResetSwing"',
			'action == "TrikeControl"',
			"playerFromSeat(trikeSeat) ~= player",
			"not finiteNumber(valueA) or not finiteNumber(valueB)",
			"math.clamp(valueB, -1, 1)",
			'action == "ResetTrike"',
		})
	end
	do
		local movementHandler = handlerSection(
			sources.movementServer,
			"sprintIntent.OnServerEvent:Connect(function(player: Player, intentValue: any)",
			"\nRunService.Heartbeat:Connect"
		)
		check(movementHandler ~= nil, "CooperMovement SprintIntent handler is missing")
		markers(movementHandler, "CooperMovement SprintIntent handler", {
			'if type(intentValue) ~= "boolean" then',
			"if intentValue == false then",
			"not consumeIntentToken(state, now)",
			"humanoid.Health <= 0",
			"humanoid.SeatPart ~= nil",
			"state.exhausted",
			"state.stamina <= 0",
			"hasNamedLock(state)",
			"modalSessionActive(player, now)",
		})
		markers(sources.movementServer, "CooperMovement server authority", {
			"local function consumeIntentToken(state: MovementState, now: number): boolean",
			"INTENT_BUCKET_CAPACITY",
			"validSource(sourceValue)",
			'type(lockedValue) ~= "boolean"',
			"multiplier ~= multiplier",
			"multiplier == math.huge",
			"MIN_MULTIPLIER",
			"MAX_MULTIPLIER",
		})
	end
	do
		local dialogueHandler = handlerSection(
			sources.dialogueServer,
			"sessionRemote.OnServerEvent:Connect(function(player, action)",
			"\nPlayers.PlayerRemoving:Connect"
		)
		check(dialogueHandler ~= nil, "CooperFamilyDialogue Session handler is missing")
		markers(dialogueHandler, "CooperFamilyDialogue Session handler", {
			'if action == "Close" then',
			"sessionSerial[player]",
			"endSession(player)",
		})
		markers(sources.dialogueServer, "CooperFamilyDialogue prompt context", {
			"local function beginSession(player: Player, npc: Model)",
			"activeByPlayer[player]",
			"activePlayerByNPC[npc]",
			"(playerRoot.Position - npcRoot.Position).Magnitude > 12",
			"prompt.Triggered:Connect(function(player)",
		})
		-- Close is an idempotent caller-owned release with no value or expensive
		-- work. A separate rate limiter is therefore not required for authority.
		check(
			not contains(dialogueHandler, "FireClient") and not contains(dialogueHandler, "Invoke"),
			"Dialogue Close must remain a cheap caller-owned idempotent release"
		)
	end
end

if lobbySourcePresent then
	local lobbyHandler = handlerSection(
		sources.lobbyServer,
		"requestRemote.OnServerInvoke = function(player: Player, action: unknown, payload: unknown)",
		"\nTeleportService.TeleportInitFailed:Connect"
	)
	check(lobbyHandler ~= nil, "CooperLobby Request handler is missing")
	markers(lobbyHandler, "CooperLobby Request handler", {
		'type(action) ~= "string" or allowedRequests[action] ~= true',
		'reasonCode = "INVALID_ACTION"',
		'if action == "Refresh" then',
		"minimumRefreshGap",
		"consumeActionBudget(player.UserId, action, nowClock)",
		'if action == "SetReady" then',
		'type(payload) ~= "boolean"',
		"setReady(player, payload)",
		'elseif action == "Launch" then',
		"launchParty(player)",
	})
	markers(sources.lobbyServer, "CooperLobby action/rate allowlist", {
		"local allowedRequests: { [string]: boolean } = {",
		"CreateParty = true",
		"PlaySolo = true",
		"SetReady = true",
		"InviteFriends = true",
		"Launch = true",
		"LeaveParty = true",
		"Rejoin = true",
		"Refresh = true",
		"table.freeze(allowedRequests)",
		"local REQUEST_BURST_CAPACITY = 5",
		"local REQUEST_REFILL_PER_SECOND = 2",
		"local function consumeActionBudget(userId: number, action: string, nowClock: number)",
		"state.lastByAction[action]",
	})
	markers(sources.lobbyServer, "CooperLobby host/phase/replay authority", {
		"local function setReady(player: Player, ready: boolean)",
		"hasMember(current.memberUserIds, player.UserId)",
		"current.state == Protocol.PartyStates.Open",
		"local function launchParty(player: Player)",
		"party.hostUserId ~= player.UserId",
		"party.state ~= Protocol.PartyStates.Open",
		'party.readyByUserId[tostring(userId)] ~= true',
		"Players:GetPlayerByUserId(userId)",
		'local sessionId = Protocol.newOpaqueId("session")',
		'local operationId = Protocol.newOpaqueId("launch")',
		"current.launchSessionId = sessionId",
		"sameMembers(current.memberUserIds, party.memberUserIds)",
		'local ticketId = Protocol.newOpaqueId("arrival")',
		"ArrivalTicketTTLSeconds",
		"ReservedServerAccessCode",
	})
end

-- State-changing ProximityPrompt surfaces. Each group is one maintained
-- inventory row with explicit identity, context/phase, actor/ownership,
-- distance, replay/state, and bounded-work evidence.
if houseSourcePresent then
	do
		inventoryRows += 1
		local promptHandler = handlerSection(
			sources.interactionsServer,
			"local function handlePrompt(prompt, player)",
			"\nlocal connectedPrompts"
		)
		check(promptHandler ~= nil, "Interior CooperAction prompt handler is missing")
		sameStringSet(
			comparedLiteralActions(promptHandler, "action"),
			stringSet({
				"Pickup",
				"CubePuzzle",
				"ToiletSit",
				"ToiletFlush",
				"ShowerToggle",
				"ShowerUse",
				"SinkWash",
				"BrushTeeth",
				"Computer",
				"FridgeToggle",
				"FridgeBeer",
			}),
			"Interior CooperAction prompt actions"
		)
		markers(sources.interactionsServer, "Interior CooperAction prompt registry", {
			'descendant:IsA("ProximityPrompt") and descendant:GetAttribute("CooperAction")',
			"handlePrompt(descendant, player)",
			'if not player or not player:IsA("Player") then',
			"prompt.MaxActivationDistance + 4",
			"not playerIsNear(player, prompt.Parent, maximumDistance)",
			'type(action) ~= "string"',
			"not passCooldown(player, action, 0.25)",
			"holderByObject",
			"fixtureOwners",
			"toiletSeat.Occupant",
		})
	end
	do
		inventoryRows += 1
		local promptHandler = handlerSection(
			sources.taskWorld,
			"ProximityPromptService.PromptTriggered:Connect(function(prompt, player)",
			"\nPlayers.PlayerRemoving:Connect"
		)
		check(promptHandler ~= nil, "Family task prompt handler is missing")
		sameStringSet(
			comparedLiteralActions(promptHandler, "action"),
			stringSet({
				"Dishes",
				"TrashPickup",
				"TrashDrop",
				"MissyReturn",
				"DeliveryPickup",
				"BeerDrop",
				"MachineInstall",
				"BoomboxSetup",
				"BoomboxPower",
				"TaskUpgradeInstall",
			}),
			"Family task prompt actions"
		)
		markers(sources.taskWorld, "Family task prompt registry", {
			"ProximityPromptService.PromptTriggered:Connect(function(prompt, player)",
			"not prompt:IsDescendantOf(world)",
			"local action = actionForPrompt(prompt)",
			"not passCooldown(player, action, 0.45)",
			"not near(player, prompt.Parent, prompt.MaxActivationDistance + 3)",
			'current.party.state ~= "Active"',
			"taskData.id ~= id",
			"taskData.automated == true",
			'tool:GetAttribute("OwnerUserId") == player.UserId',
			"deliveryRecord.status",
			'familyAPI:Invoke("GetSnapshot", player)',
			'invokeFamily("ReportAction"',
			"PromptButtonHoldBegan:Connect(function(prompt, player)",
			"serverNow() - session.startedAt + DISH_HOLD_TOLERANCE >= prompt.HoldDuration",
		})
	end
	do
		inventoryRows += 1
		markers(sources.taskWorld, "Candy buyer delivery prompt", {
			"session.promptConnection = prompt.Triggered:Connect(function(triggeringPlayer)",
			"triggeringPlayer ~= player",
			"session.delivered or session.cancelled",
			"(root.Position - dropAnchor.Position).Magnitude > prompt.MaxActivationDistance + 3",
			"liveContract.active ~= true",
			'tostring(liveContract.batchToken or "") ~= session.batchToken',
			'tool:GetAttribute("OwnerUserId") ~= player.UserId',
			'tool:GetAttribute("BatchToken") ~= session.batchToken',
			'"CandyBatchDelivered"',
		})
	end
	do
		inventoryRows += 1
		markers(sources.bunkerServer, "Bunker research/chemistry/output prompts", {
			"researchPrompt.Triggered:Connect(function(player)",
			"not playerHasBunkerAccess(player)",
			'player:GetAttribute("CooperPartyState") ~= "Active"',
			"not isNear(player, bunkerTerminalInputAnchor, researchPrompt.MaxActivationDistance + 3)",
			'player:SetAttribute("CooperBunkerComputerSessionUntil"',
			"chemistryPrompt.Triggered:Connect(function(player)",
			'player:GetAttribute("CooperChemistrySetupPlaced") ~= true',
			"not isNear(player, chemistryPromptAnchor, chemistryPrompt.MaxActivationDistance + 3)",
			"chemistryExperimentActive",
			"chemistryExperimentReadyAt",
			"collectCandyPrompt.Triggered:Connect(function(player)",
			"chemistryRewardClaiming = true",
			'tool:SetAttribute("OwnerUserId", ownerPlayer.UserId)',
			'tool:SetAttribute("BatchToken", tostring(batchToken or ""))',
		})
	end
	do
		inventoryRows += 1
		markers(sources.bunkerServer, "Bunker hatch/blast/light prompts", {
			"local function consumePhysicalPromptRate(player, action)",
			"local _, _, root = playerCharacterState(player)",
			"PHYSICAL_PROMPT_RATE_SECONDS[action]",
			"hatchPrompt.Triggered:Connect(function(player)",
			'consumePhysicalPromptRate(player, "Hatch")',
			"not playerHasBunkerAccess(player)",
			"not isNear(player, hatchControl, hatchPrompt.MaxActivationDistance + 4)",
			"hatchSweepOccupied()",
			"blastDoorPrompt.Triggered:Connect(function(player)",
			'consumePhysicalPromptRate(player, "BlastDoor")',
			"not isNear(player, blastDoorControl, blastDoorPrompt.MaxActivationDistance + 4)",
			"blastDoorwayOccupied()",
			"lightPrompt.Triggered:Connect(function(player)",
			'consumePhysicalPromptRate(player, "MainLights")',
			"not isNear(player, lightControl, lightPrompt.MaxActivationDistance + 4)",
		})
	end
	do
		inventoryRows += 1
		markers(sources.rideablesServer, "Yard rideable prompts", {
			"swingPrompt.Triggered:Connect(function(player)",
			"if swingSeat.Occupant then",
			"mayUsePrompt(player, swingSeat, 11)",
			"trikePrompt.Triggered:Connect(function(player)",
			"if trikeSeat.Occupant then",
			"mayUsePrompt(player, trikeSeat, 12)",
			"not humanoid or humanoid.Sit",
			"(root.Position - part.Position).Magnitude > maximumDistance",
			"setAssemblyServerOwned",
		})
	end
	do
		inventoryRows += 1
		markers(sources.dialogueServer, "Family dialogue prompts", {
			"prompt.Triggered:Connect(function(player)",
			"beginSession(player, npc)",
			"activeByPlayer[player]",
			"activePlayerByNPC[npc]",
			'npc:GetAttribute("BoomboxDancing") == true',
			"(playerRoot.Position - npcRoot.Position).Magnitude > 12",
			"sessionSerial[player]",
		})
	end
	do
		local sharedDoorMarkers = {
			'game:GetService("Players")',
			"local function livePlayerRoot(player",
			'player:GetAttribute("CooperPartyMember") ~= true',
			'player:GetAttribute("CooperGameProfileLoaded") ~= true',
			'partyState ~= "Active" and partyState ~= "HostGrace"',
			"local function playerCanReachPrompt(player",
			"prompt.MaxActivationDistance + PROMPT_DISTANCE_SLACK",
			"PROMPT_DISTANCE_HARD_CAP",
			"local function consumePromptRate(player",
			"prompt.Triggered:Connect(function(player",
			"not playerCanReachPrompt(player) or not consumePromptRate(player)",
			"Players.PlayerRemoving:Connect(function(player)",
		}
		for _, door in ipairs({
			{ source = sources.frontDoor, label = "Front door prompt", state = 'door:GetAttribute("AutomationHoldOpen") == true' },
			{ source = sources.patioDoor, label = "Patio door prompt", state = 'door:GetAttribute("AutomationHoldOpen") == true' },
			{ source = sources.garageDoor, label = "Garage door prompt", state = "isDoorwayObstructed()" },
		}) do
			inventoryRows += 1
			markers(door.source, door.label, sharedDoorMarkers)
			check(contains(door.source, door.state), door.label .. " is missing obstruction/automation state authority")
		end
	end
end

-- Retire broad value mutation and keep privileged scenario/debug authority
-- structurally away from ordinary clients.
if houseSourcePresent then
	markers(sources.gameServer, "Retired broad currency API", {
		'operation == "AdjustCurrency" or operation == "SpendAllowance"',
		'return false, "DeprecatedOperation: use a named authoritative value operation"',
	})
	for _, record in ipairs({
		{ source = sources.gameClient, label = "CooperGame client" },
		{ source = sources.bunkerClient, label = "CooperBunker client" },
		{ source = sources.interactionsClient, label = "CooperInteractions client" },
		{ source = sources.rideablesClient, label = "CooperYardRideables client" },
		{ source = sources.sprintClient, label = "CooperSprint client" },
	}) do
		lacks(record.source, record.label, {
			'FireServer("AdjustCurrency"',
			'FireServer("SpendAllowance"',
			'FireServer("UnlockAll"',
			'FireServer("GrantAll"',
			'FireServer("DebugGrant"',
			'FireServer("ForceHorror"',
		})
	end
	lacks(sources.taskWorld, "CooperTaskWorld", {
		'invokeFamily("AdjustCurrency"',
		'invokeFamily("SpendAllowance"',
	})
	lacks(sources.bunkerServer, "CooperBunker", {
		'invokeFamily("AdjustCurrency"',
		'invokeFamily("SpendAllowance"',
	})
end
if lobbySourcePresent then
	lacks(sources.lobbyClient, "CooperLobby client", {
		'request("UnlockAll"',
		'request("GrantAll"',
		'request("DebugGrant"',
		'request("Scenario"',
	})
	lacks(sources.lobbyServer, "CooperLobby server", {
		"UnlockAll = true",
		"GrantAll = true",
		"DebugGrant = true",
		"ScenarioControl = true",
	})
end

-- Authoring-only Studio bridge: allowed in the lobby source place, but it may
-- expose only a server BindableFunction after a Studio guard. It must never
-- create or listen to a client remote.
if sources.studioBridge then
	markers(sources.studioBridge, "StudioHousePreview bridge isolation", {
		"if not RunService:IsStudio() then",
		'local LAUNCH_BINDABLE_NAME = "Launch"',
		'local launch = Instance.new("BindableFunction")',
		"launch.Name = LAUNCH_BINDABLE_NAME",
		"launch.OnInvoke = startStudioHouse",
		"intentionally contains no live RemoteEvents",
	})
	check(countPlain(sources.studioBridge, "OnServerEvent") == 0, "Studio preview bridge must not listen to RemoteEvents")
	check(countPlain(sources.studioBridge, "OnServerInvoke") == 0, "Studio preview bridge must not expose a RemoteFunction")
	check(countPlain(sources.studioBridge, 'Instance.new("RemoteFunction")') == 0, "Studio preview bridge must not create a RemoteFunction")
end

-- Live/edit DataModel network surface. Missing roots are valid when the other
-- place is being audited; present roots must match the exact documented shape.
local function verifyRemoteFolder(folder, label, expected)
	check(folder ~= nil and folder:IsA("Folder"), label .. " folder is missing or has the wrong class")
	if not folder or not folder:IsA("Folder") then
		return
	end
	local seen = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") then
			seen[child.Name] = true
			local expectedClass = expected[child.Name]
			check(expectedClass ~= nil, label .. " exposes undocumented remote " .. child.Name)
			if expectedClass then
				check(child:IsA(expectedClass), child:GetFullName() .. " must be a " .. expectedClass)
			end
			inventoryRows += 1
		end
	end
	for name in pairs(expected) do
		check(seen[name] == true, label .. " is missing remote " .. name)
	end
end

local gameRoot = ReplicatedStorage:FindFirstChild("CooperGame")
if gameRoot then
	local remotes = gameRoot:FindFirstChild("Remotes")
	verifyRemoteFolder(remotes, "CooperGame.Remotes", {
		Request = "RemoteEvent",
		Snapshot = "RemoteEvent",
		Feedback = "RemoteEvent",
		BankHack = "RemoteEvent",
	})
	local configModule = gameRoot:FindFirstChild("Config")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		check(ok and type(config) == "table", "CooperGame.Config could not be loaded read-only")
		if ok and type(config) == "table" then
			check(
				type(config.Features) == "table" and config.Features.StudioScenarioTools == false,
				"StudioScenarioTools must remain false"
			)
			check(config.Features.Horror == false, "Horror must remain disabled during Milestone 1")
			check(config.Features.SecretExploration == false, "SecretExploration must remain disabled during Milestone 1")
			check(config.Features.TimeMachineFinale == false, "TimeMachineFinale must remain disabled during Milestone 1")
			check(config.Features.Postgame == false, "Postgame must remain disabled during Milestone 1")
		end
	end
end

local interactionRemotes = ReplicatedStorage:FindFirstChild("CooperInteractionsRemotes")
if interactionRemotes then
	verifyRemoteFolder(interactionRemotes, "CooperInteractionsRemotes", {
		Request = "RemoteEvent",
		Client = "RemoteEvent",
	})
end
local rideableRemotes = ReplicatedStorage:FindFirstChild("CooperYardRideablesRemotes")
if rideableRemotes then
	verifyRemoteFolder(rideableRemotes, "CooperYardRideablesRemotes", {
		RideablesEvent = "RemoteEvent",
	})
end
local movementRemotes = ReplicatedStorage:FindFirstChild("CooperMovementRemotes")
if movementRemotes then
	verifyRemoteFolder(movementRemotes, "CooperMovementRemotes", {
		SprintIntent = "RemoteEvent",
	})
end
local dialogueRemotes = ReplicatedStorage:FindFirstChild("CooperFamilyDialogue")
if dialogueRemotes then
	verifyRemoteFolder(dialogueRemotes, "CooperFamilyDialogue", {
		Session = "RemoteEvent",
	})
end
local bunkerRemotes = ReplicatedStorage:FindFirstChild("CooperBunkerRemotes")
if bunkerRemotes then
	verifyRemoteFolder(bunkerRemotes, "CooperBunkerRemotes", {
		BunkerEvent = "RemoteEvent",
	})
end
local partyRemotes = ReplicatedStorage:FindFirstChild("CooperPartyLobby")
if partyRemotes then
	verifyRemoteFolder(partyRemotes, "CooperPartyLobby", {
		Request = "RemoteFunction",
		State = "RemoteEvent",
		ClientCommand = "RemoteEvent",
	})
end

local suspiciousRemoteFragments = {
	"scenario",
	"debuggrant",
	"unlockall",
	"grantall",
	"forcehorror",
	"forceending",
}
for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
	if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent") then
		local normalized = string.lower((descendant.Name:gsub("[^%w]", "")))
		for _, fragment in ipairs(suspiciousRemoteFragments) do
			check(
				not string.find(normalized, fragment, 1, true),
				"ReplicatedStorage exposes suspicious debug/scenario remote " .. descendant:GetFullName()
			)
		end
	end
end

local forbiddenAuthorityNames = {
	StudioScenarioRunner = true,
	CooperScenarioRunner = true,
	ScenarioControl = true,
	DebugGrant = true,
	UnlockAll = true,
	GrantAll = true,
}
for _, root in ipairs({
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterPlayer,
	Workspace,
}) do
	for _, descendant in ipairs(root:GetDescendants()) do
		check(
			forbiddenAuthorityNames[descendant.Name] ~= true,
			"DataModel exposes privileged scenario/debug object " .. descendant:GetFullName()
		)
		for _, attributeName in ipairs({
			"StudioScenarioControl",
			"CooperDebugAuthority",
			"UnlockAllEnabled",
		}) do
			check(
				descendant:GetAttribute(attributeName) == nil,
				"DataModel exposes privileged attribute " .. attributeName .. " on " .. descendant:GetFullName()
			)
		end
	end
end

-- A non-Studio candidate must not contain the authoring bridge/package at all.
if not RunService:IsStudio() then
	check(
		ServerScriptService:FindFirstChild("StudioHousePreview") == nil,
		"Production runtime contains the StudioHousePreview bridge"
	)
	check(
		ServerStorage:FindFirstChild("StudioHousePreviewPackage") == nil,
		"Production runtime contains the StudioHousePreviewPackage"
	)
end

-- Document deliberately incomplete runtime evidence without converting it into
-- a pass. These messages are part of the audit result and correspond directly
-- to the open rows in REMOTE_SECURITY_MATRIX.md and PLAN.md.
advise(
	false,
	"STATIC ONLY: run published malformed-payload, NaN/infinity, arbitrary-Instance, replay, and flood probes for every C2S row"
)
advise(
	false,
	"STATIC ONLY: run the lobby ticket/MemoryStore/TeleportService suite in privately published solo/2/4-player sessions"
)
advise(
	false,
	"STATIC ONLY: run moved-prompt, impossible-distance, simultaneous-trigger, reset/death, streaming, and mobile prompt scenarios"
)

if #failures > 0 then
	error(string.format(
		"[Milestone1RemoteInventory] FAIL — %d failures across %d checks / %d inventoried sites or surfaces:\n - %s",
		#failures,
		checks,
		inventoryRows,
		table.concat(failures, "\n - ")
	))
end

print(string.format(
	"[Milestone1RemoteInventory] PASS — %d checks; %d client/server/prompt/remote sites or surfaces inventoried",
	checks,
	inventoryRows
))
for _, message in ipairs(advisories) do
	warn("[Milestone1RemoteInventory] " .. message)
end
