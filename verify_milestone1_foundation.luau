--!nonstrict
-- Read-only Studio edit/runtime audit for Milestone 1: Lobby and Co-op.
--
-- Run this file in BOTH the house place and the dedicated lobby place. It does
-- not create, destroy, reparent, rename, save, teleport, invoke a Remote, or
-- write MemoryStore/DataStore data. Cross-place and disconnect behavior still
-- requires the human scenarios in MILESTONE1_TEST_MATRIX.md.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local running = RunService:IsRunning()
local failures = {}
local advisories = {}
local checkCount = 0

local EXPECTED_UNIVERSE_ID = 10480337589
local EXPECTED_LOBBY_PLACE_ID = 100748614383412
local EXPECTED_HOUSE_PLACE_ID = 98645411943406
local MINIMUM_LOBBY_CAPACITY = 4
local RECOMMENDED_LOBBY_CAPACITY = 50
local EXPECTED_UI_THEME_VERSION = 1

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function advise(condition, message)
	if not condition then
		table.insert(advisories, message)
	end
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
		local at = string.find(source, marker, cursor, true)
		if not at then
			return count
		end
		count += 1
		cursor = at + #marker
	end
end

local function lacks(source, marker, label)
	check(not contains(source, marker), (label or "Source") .. " unexpectedly contains " .. marker)
end

local function markers(source, label, expected)
	for _, marker in ipairs(expected) do
		check(contains(source, marker), label .. " is missing source contract marker: " .. marker)
	end
end

local function functionSection(source, functionName)
	local startMarkers = {
		"local function " .. functionName .. "(",
		"function " .. functionName .. "(",
		functionName .. " = function(",
	}
	local startAt = nil
	local startMarker = nil
	if type(source) == "string" then
		for _, candidate in ipairs(startMarkers) do
			local candidateAt = string.find(source, candidate, 1, true)
			if candidateAt and (not startAt or candidateAt < startAt) then
				startAt = candidateAt
				startMarker = candidate
			end
		end
	end
	if not startAt then
		return nil
	end
	local markerLength = #(startMarker or "")
	local endAt = #source + 1
	for _, boundary in ipairs({
		"\nlocal function ",
		"\nfunction ",
		"\nreturn ",
	}) do
		local candidate = string.find(source, boundary, startAt + markerLength, true)
		if candidate and candidate < endAt then
			endAt = candidate
		end
	end
	return string.sub(source, startAt, endAt - 1)
end

local function sourceOf(instance, label)
	check(instance ~= nil, label .. " is missing")
	if not instance then
		return nil
	end
	check(instance:IsA("LuaSourceContainer"), label .. " must contain Luau source")
	if not instance:IsA("LuaSourceContainer") then
		return nil
	end
	if instance:IsA("BaseScript") then
		check(instance.Enabled == true, label .. " is disabled")
	end
	local ok, source = pcall(function()
		return instance.Source
	end)
	check(ok and type(source) == "string", label .. ".Source is unreadable from this context")
	if not ok or type(source) ~= "string" then
		return nil
	end
	check(#source > 100, label .. " has empty or placeholder source")
	return source
end

local function loadDataModule(module, label)
	local source = sourceOf(module, label)
	if not source then
		return nil, source
	end
	local ok, result
	if not running and type(loadstring) == "function" then
		local compileOk, chunkOrError = pcall(loadstring, source, label .. "Audit")
		if compileOk and type(chunkOrError) == "function" then
			ok, result = pcall(chunkOrError)
		else
			ok, result = false, chunkOrError
		end
	else
		ok, result = pcall(require, module)
	end
	check(ok and type(result) == "table", label .. " did not return a table: " .. tostring(result))
	return ok and type(result) == "table" and result or nil, source
end

local function directChild(parent, name, className, label)
	local child = parent and parent:FindFirstChild(name) or nil
	check(child ~= nil, label or ((parent and parent:GetFullName() or "<missing>") .. " is missing " .. name))
	if child and className then
		check(child:IsA(className), child:GetFullName() .. " must be a " .. className)
	end
	return child
end

local function linearColorChannel(channel)
	return if channel <= 0.04045
		then channel / 12.92
		else ((channel + 0.055) / 1.055) ^ 2.4
end

local function relativeLuminance(color)
	return 0.2126 * linearColorChannel(color.R)
		+ 0.7152 * linearColorChannel(color.G)
		+ 0.0722 * linearColorChannel(color.B)
end

local function contrastRatio(foreground, background)
	local foregroundLuminance = relativeLuminance(foreground)
	local backgroundLuminance = relativeLuminance(background)
	local lighter = math.max(foregroundLuminance, backgroundLuminance)
	local darker = math.min(foregroundLuminance, backgroundLuminance)
	return (lighter + 0.05) / (darker + 0.05)
end

-- CooperUITheme is deliberately installed in both places. The Studio
-- in-place preview retains the lobby's replicated copy during handoff instead
-- of cloning a second module that could drift.
local uiThemeModule = directChild(ReplicatedStorage, "CooperUITheme", "ModuleScript")
local UITheme, uiThemeSource = loadDataModule(uiThemeModule, "ReplicatedStorage.CooperUITheme")
if uiThemeSource then
	markers(uiThemeSource, "CooperUITheme", {
		"Theme.VERSION = 1",
		'Theme.ID = "Cooper1980sRecRoom.v1"',
		"ActionHeight = 60",
		"MinimumTouchTarget = 56",
		"Enum.ScreenInsets.CoreUISafeInsets",
		"return table.freeze(Theme)",
	})
end
if UITheme then
	check(table.isfrozen(UITheme), "CooperUITheme root must be frozen")
	check(UITheme.VERSION == EXPECTED_UI_THEME_VERSION, "CooperUITheme version must be 1")
	check(UITheme.ID == "Cooper1980sRecRoom.v1", "CooperUITheme ID changed")
	check(type(UITheme.Colors) == "table" and table.isfrozen(UITheme.Colors), "CooperUITheme.Colors must be frozen")
	check(type(UITheme.Fonts) == "table" and table.isfrozen(UITheme.Fonts), "CooperUITheme.Fonts must be frozen")
	check(type(UITheme.Metrics) == "table" and table.isfrozen(UITheme.Metrics), "CooperUITheme.Metrics must be frozen")
	check(
		type(UITheme.Accessibility) == "table" and table.isfrozen(UITheme.Accessibility),
		"CooperUITheme.Accessibility must be frozen"
	)
	local colors = UITheme.Colors or {}
	local expectedColors = {
		Scrim = Color3.fromRGB(25, 18, 13),
		Cabinet = Color3.fromRGB(104, 55, 31),
		Screen = Color3.fromRGB(27, 37, 30),
		ScreenRaised = Color3.fromRGB(42, 54, 40),
		ScreenSoft = Color3.fromRGB(53, 62, 45),
		Outline = Color3.fromRGB(181, 153, 91),
		Cream = Color3.fromRGB(255, 244, 207),
		Muted = Color3.fromRGB(220, 213, 181),
		Mustard = Color3.fromRGB(238, 179, 54),
		MustardText = Color3.fromRGB(48, 31, 10),
		Avocado = Color3.fromRGB(174, 207, 90),
		Teal = Color3.fromRGB(133, 208, 197),
		Rust = Color3.fromRGB(255, 151, 112),
		Disabled = Color3.fromRGB(75, 76, 62),
	}
	for colorName, expectedColor in pairs(expectedColors) do
		check(colors[colorName] == expectedColor, "CooperUITheme approved color changed: " .. colorName)
	end
	local fonts = UITheme.Fonts or {}
	check(fonts.Body == Enum.Font.Gotham, "CooperUITheme body font changed")
	check(fonts.Medium == Enum.Font.GothamMedium, "CooperUITheme medium font changed")
	check(fonts.Strong == Enum.Font.GothamBold, "CooperUITheme strong font changed")
	check(fonts.Mono == Enum.Font.RobotoMono, "CooperUITheme mono font changed")
	local metrics = UITheme.Metrics or {}
	check(metrics.SpacingUnit == 8, "CooperUITheme spacing unit must be 8")
	check(metrics.MinimumTouchTarget == 56, "CooperUITheme minimum touch target must be 56 pixels")
	check(metrics.ActionHeight == 60, "CooperUITheme lobby action height must remain 60 pixels")
	check(
		type(metrics.ActionHeight) == "number"
			and type(metrics.MinimumTouchTarget) == "number"
			and metrics.ActionHeight >= metrics.MinimumTouchTarget,
		"CooperUITheme action height is below its touch-target minimum"
	)
	local accessibility = UITheme.Accessibility or {}
	check(accessibility.BodyTextContrastMinimum == 4.5, "CooperUITheme body-text contrast contract must be 4.5:1")
	check(accessibility.LargeTextContrastMinimum == 3, "CooperUITheme large-text contrast contract must be 3:1")
	check(
		accessibility.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets,
		"CooperUITheme must use CoreUISafeInsets"
	)
	check(accessibility.ClipToDeviceSafeArea == true, "CooperUITheme must clip to the device safe area")
	local bodyContrastMinimum = tonumber(accessibility.BodyTextContrastMinimum) or math.huge
	for _, pair in ipairs({
		{ "Cream", "Screen" },
		{ "Muted", "Screen" },
		{ "Muted", "ScreenRaised" },
		{ "MustardText", "Mustard" },
		{ "Avocado", "ScreenRaised" },
		{ "Teal", "ScreenRaised" },
		{ "Rust", "ScreenRaised" },
		{ "Muted", "Disabled" },
	}) do
		local foreground = colors[pair[1]]
		local background = colors[pair[2]]
		check(typeof(foreground) == "Color3" and typeof(background) == "Color3", "Contrast pair is missing: " .. pair[1] .. "/" .. pair[2])
		if typeof(foreground) == "Color3" and typeof(background) == "Color3" then
			check(
				contrastRatio(foreground, background) >= bodyContrastMinimum,
				"CooperUITheme contrast is below 4.5:1 for " .. pair[1] .. "/" .. pair[2]
			)
		end
	end
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
check(starterScripts and starterScripts:IsA("StarterPlayerScripts"), "StarterPlayerScripts is missing")

local houseRoot = ReplicatedStorage:FindFirstChild("CooperGame")
local lobbyRoot = ReplicatedStorage:FindFirstChild("CooperLobby")
local isHouse = houseRoot and houseRoot:IsA("Folder")
local isLobby = lobbyRoot and lobbyRoot:IsA("Folder")
check(isHouse ~= isLobby, "Install exactly one Milestone 1 place role: house OR lobby")
local placeRole = isHouse and "house" or (isLobby and "lobby" or "unknown")

-- Shared, server-validated teleport protocol -------------------------------

local protocolModule = directChild(ReplicatedStorage, "CooperPartyProtocol", "ModuleScript")
local Protocol, protocolSource = loadDataModule(protocolModule, "ReplicatedStorage.CooperPartyProtocol")
if Protocol then
	check(table.isfrozen(Protocol), "CooperPartyProtocol must be frozen")
	check(Protocol.VERSION == 1, "CooperPartyProtocol.VERSION must be 1")
	check(Protocol.MAX_PARTY_SIZE == 4, "CooperPartyProtocol.MAX_PARTY_SIZE must be 4")
	check(Protocol.HOUSE_TELEPORT_KIND == "CooperHouseSession", "House teleport kind changed")
	check(Protocol.INVITE_LAUNCH_KIND == "CooperPartyInvite", "Invite launch kind changed")
	check(type(Protocol.validateHouseTeleportData) == "function", "Protocol lacks destination validation")
	check(type(Protocol.makeHouseTeleportData) == "function", "Protocol lacks house teleport-data construction")
	check(type(Protocol.parseInviteLaunchData) == "function", "Protocol lacks invitation validation")
	check(type(Protocol.containsMember) == "function", "Protocol lacks membership validation")

	local memoryStoreNames = Protocol.MemoryStoreNames
	check(type(memoryStoreNames) == "table" and table.isfrozen(memoryStoreNames), "Protocol.MemoryStoreNames must be frozen")
	local uniqueMapNames = {}
	local mapCount = 0
	if type(memoryStoreNames) == "table" then
		for _, mapName in pairs(memoryStoreNames) do
			mapCount += 1
			check(type(mapName) == "string" and mapName ~= "", "MemoryStore map name must be nonempty")
			check(uniqueMapNames[mapName] == nil, "MemoryStore map names must be unique: " .. tostring(mapName))
			uniqueMapNames[mapName] = true
		end
	end
	check(mapCount == 6, "Protocol must declare six distinct MemoryStore maps")
	check(memoryStoreNames and memoryStoreNames.Parties == "CooperPartyLobbyParties_v1", "Canonical party map name changed")
	check(memoryStoreNames and memoryStoreNames.Invites == "CooperPartyInvites_v1", "Canonical invite map name changed")
	check(memoryStoreNames and memoryStoreNames.Memberships == "CooperPartyMemberships_v1", "Canonical membership map name changed")
	check(memoryStoreNames and memoryStoreNames.Tickets == "CooperPartyLaunchTickets_v1", "Canonical ticket map name changed")
	check(memoryStoreNames and memoryStoreNames.Sessions == "CooperPartySessions_v1", "Canonical session map name changed")
	check(memoryStoreNames and memoryStoreNames.Rejoins == "CooperPartyRejoin_v1", "Canonical rejoin map name changed")

	-- Execute the pure payload validator. This proves party size, membership,
	-- duplicate-ID, and expiry checks rather than merely finding their names.
	local nowUnix = 2_000_000_000
	local ids = {
		sessionId = "session_0123456789abcdef0123456789abcdef",
		partyId = "party_0123456789abcdef0123456789abcdef",
		ticketId = "ticket_0123456789abcdef0123456789abcdef",
	}
	local madeOk, validPayload = pcall(
		Protocol.makeHouseTeleportData,
		ids.sessionId,
		ids.partyId,
		ids.ticketId,
		101,
		{ 101, 202, 303, 404 },
		nowUnix - 1,
		nowUnix + 120
	)
	check(madeOk and type(validPayload) == "table", "Protocol could not construct a four-player payload")
	if madeOk and type(validPayload) == "table" then
		local validated, validationError = Protocol.validateHouseTeleportData(validPayload, 404, nowUnix)
		check(validated ~= nil and validationError == nil, "Valid member payload was rejected: " .. tostring(validationError))
		local nonmember = Protocol.validateHouseTeleportData(validPayload, 505, nowUnix)
		check(nonmember == nil, "Nonmember teleport data was accepted")

		local expired = table.clone(validPayload)
		expired.expiresAt = nowUnix
		check(Protocol.validateHouseTeleportData(expired, 101, nowUnix) == nil, "Expired teleport data was accepted")
		local duplicates = table.clone(validPayload)
		duplicates.memberUserIds = { 101, 202, 202 }
		check(Protocol.validateHouseTeleportData(duplicates, 101, nowUnix) == nil, "Duplicate party membership was accepted")
		local oversized = table.clone(validPayload)
		oversized.memberUserIds = { 101, 202, 303, 404, 505 }
		check(Protocol.validateHouseTeleportData(oversized, 101, nowUnix) == nil, "A five-player party was accepted")

		for key in pairs(validPayload) do
			local normalized = string.lower(tostring(key))
			check(not string.find(normalized, "accesscode", 1, true), "TeleportData exposed an access-code field")
			check(not string.find(normalized, "reservedserver", 1, true), "TeleportData exposed a reserved-server field")
		end
	end
end
if protocolSource then
	markers(protocolSource, "CooperPartyProtocol", {
		"TeleportData and LaunchData are hints, never authority.",
		"Reserved-server access codes are deliberately absent",
		"function Protocol.validateHouseTeleportData(",
		"if not Protocol.containsMember(memberUserIds, arrivingUserId) then",
		"if value.expiresAt <= nowUnix then",
	})
end

-- No client is permitted to become a reward, task, party-authority, or
-- movement-authority source. These exact request names are deliberately more
-- specific than UI words such as "TaskComplete" in feedback listeners.
for _, root in ipairs({ starterScripts, StarterGui }) do
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("LocalScript") then
				local clientSource = sourceOf(descendant, descendant:GetFullName())
				if clientSource then
					for _, forbidden in ipairs({
						':FireServer("CompleteTask"',
						':InvokeServer("CompleteTask"',
						':FireServer("AwardAllowance"',
						':InvokeServer("AwardAllowance"',
						':FireServer("SetAllowance"',
						':InvokeServer("SetAllowance"',
						':FireServer("AdjustAllowance"',
						':InvokeServer("AdjustAllowance"',
						'leaderstats.Allowance.Value =',
						'SetAttribute("PartyHostUserId"',
						'SetAttribute("CooperStamina"',
						'GetService("MemoryStoreService")',
						':TeleportAsync(',
					}) do
						lacks(clientSource, forbidden, descendant:GetFullName())
					end
				end
			end
		end
	end
end

-- Retired panic/crisis/progression content stays absent in both places.
for _, specification in ipairs({
	{ ReplicatedStorage, "CooperProgression" },
	{ ReplicatedStorage, "CooperCrisis" },
	{ ServerScriptService, "CooperProgression" },
	{ ServerScriptService, "CooperProgressionServerEvents" },
	{ ServerScriptService, "CooperCrisis" },
	{ ServerScriptService, "CooperCrisisServerEvents" },
	{ starterScripts, "CooperProgression" },
	{ starterScripts, "CooperCrisisClient" },
	{ StarterGui, "CooperProgressionHUD" },
	{ StarterGui, "CooperCrisisHUD" },
	{ Workspace, "CooperFutureApartment" },
	{ Lighting, "CooperCharacterPanicColor" },
	{ SoundService, "CrisisAlert" },
	{ SoundService, "PanicWarningAudio" },
}) do
	local parent, name = specification[1], specification[2]
	check(not parent or parent:FindFirstChild(name) == nil, "Retired runtime object remains: " .. name)
end

if isHouse then
	-- House config and unchanged pre-horror content -------------------------
	local configModule = directChild(houseRoot, "Config", "ModuleScript")
	local transactionLedgerModule = directChild(houseRoot, "TransactionLedger", "ModuleScript")
	local state = directChild(houseRoot, "State", "Folder")
	local Config, configSource = loadDataModule(configModule, "ReplicatedStorage.CooperGame.Config")
	local TransactionLedger, transactionLedgerSource = loadDataModule(
		transactionLedgerModule,
		"ReplicatedStorage.CooperGame.TransactionLedger"
	)
	if transactionLedgerSource then
		markers(transactionLedgerSource, "CooperTransactionLedger", {
			"Ledger.VERSION = 1",
			"Ledger.MAX_COMMITTED = 256",
				"Ledger.MAX_PENDING = 32",
				"Ledger.MAX_ROLLED_BACK = 64",
				"function Ledger.logicalKind(",
				"function Ledger.sanitize(",
			"function Ledger.begin(",
			"function Ledger.commit(",
			"function Ledger.markNeedsReconciliation(",
			"function Ledger.issuedHighWater(",
			"function Ledger.rollback(",
			"function Ledger.sessionMatches(",
			"return table.freeze(Ledger)",
		})
	end
	if TransactionLedger then
		check(table.isfrozen(TransactionLedger), "TransactionLedger root must be frozen")
		check(TransactionLedger.VERSION == 1, "TransactionLedger version must be 1")
		check(
			type(TransactionLedger.MAX_COMMITTED) == "number" and TransactionLedger.MAX_COMMITTED >= 256,
			"TransactionLedger must retain at least 256 committed operation records"
		)
		check(
			type(TransactionLedger.MAX_ROLLED_BACK) == "number"
				and TransactionLedger.MAX_ROLLED_BACK > 0,
			"TransactionLedger needs a separate bounded rollback tombstone history"
		)
			check(
				type(TransactionLedger.MAX_PENDING) == "number" and TransactionLedger.MAX_PENDING > 0,
				"TransactionLedger needs a bounded reconciliation queue"
			)
			check(
				TransactionLedger.logicalKind("CandySale", "batch-123") == "CandySale:batch-123",
				"TransactionLedger logical operation identities are not stable"
			)
			check(
				TransactionLedger.logicalKind("CandySale", "../client") == nil,
				"TransactionLedger accepts client-shaped logical operation keys"
			)
	end
	if Config then
		check(Config.SchemaVersion == 12, "Milestone 1 transaction integration requires profile schema 12")
		check(Config.DataStoreName == "CooperFamilyTasks_v2", "Milestone 1 must retain the production DataStore")
		check(Config.ReleasePlayerCap == 4, "House release cap must be four")
		local defaultJournal = Config.ProfileDefaults and Config.ProfileDefaults.operationJournal
		check(type(defaultJournal) == "table", "Schema 12 ProfileDefaults.operationJournal is missing")
		check(defaultJournal and defaultJournal.version == 1, "Fresh operation journal version must be 1")
		check(
			defaultJournal and type(defaultJournal.pending) == "table" and next(defaultJournal.pending) == nil,
			"Fresh operation journal must not contain pending operations"
		)
		check(
			defaultJournal and type(defaultJournal.committed) == "table" and next(defaultJournal.committed) == nil,
			"Fresh operation journal must not contain committed operations"
		)

		local expectedFeatures = {
			Lobby = true,
			Horror = false,
			SecretExploration = false,
			TimeMachineFinale = false,
			Postgame = false,
			StudioScenarioTools = false,
		}
		local featureCount = 0
		check(type(Config.Features) == "table" and table.isfrozen(Config.Features), "Config.Features must be frozen")
		if type(Config.Features) == "table" then
			for featureName, value in pairs(Config.Features) do
				featureCount += 1
				check(expectedFeatures[featureName] ~= nil, "Unexpected feature flag: " .. tostring(featureName))
				check(value == expectedFeatures[featureName], "Incorrect Milestone 1 feature value: " .. tostring(featureName))
			end
		end
		check(featureCount == 6, "Config.Features must contain exactly six flags")

		local expectedTaskOrder = { "GeorgeBeer", "MaryDishes", "MaryTrash", "MissyPlush", "MedfordBankHack" }
		check(type(Config.Tasks) == "table" and #Config.Tasks == 5, "House must retain exactly five tasks")
		check(type(Config.TaskOrder) == "table" and #Config.TaskOrder == 5, "TaskOrder must retain exactly five tasks")
		for index, taskId in ipairs(expectedTaskOrder) do
			check(Config.Tasks[index] and Config.Tasks[index].id == taskId, "Task definition order changed at " .. index)
			check(Config.TaskOrder[index] == taskId, "TaskOrder changed at " .. index)
		end
		check(type(Config.MachineStages) == "table" and #Config.MachineStages == 11, "House must retain eleven machine stages")
		for stage = 1, 11 do
			check(Config.MachineStages[stage] and Config.MachineStages[stage].stage == stage, "Machine stage is missing/out of order: " .. stage)
		end

		check(type(Config.Party) == "table" and table.isfrozen(Config.Party), "Config.Party must be frozen")
		check(Config.Party and Config.Party.ProtocolVersion == 1, "Party protocol version must be 1")
		check(Config.Party and Config.Party.MaxMembers == 4, "Party max must be four")
		check(Config.Party and Config.Party.HostReconnectGraceSeconds == 60, "Host grace must be exactly 60 seconds")
		check(Config.Party and Config.Party.GuestReconnectGraceSeconds == 90, "Guest grace must be exactly 90 seconds")
		check(Config.Party and Config.Party.HostOnlyPersistentPurchases == true, "Persistent world purchases must be host-only")
		check(Config.Party and Config.Party.LobbyPlaceId == EXPECTED_LOBBY_PLACE_ID, "House config must route back to the published lobby place")
		check(Config.Party and Config.Party.HousePlaceId == EXPECTED_HOUSE_PLACE_ID, "House place ID changed")
		check(Config.Party and Config.Party.LobbyPlaceId ~= Config.Party.HousePlaceId, "Lobby and house must be different places")
		check(Config.Party and Protocol and Config.Party.TicketMapName == Protocol.MemoryStoreNames.Tickets, "House ticket map must match CooperPartyProtocol")
		check(Config.Party and Protocol and Config.Party.SessionMapName == Protocol.MemoryStoreNames.Sessions, "House session map must match CooperPartyProtocol")
		check(Config.Party and Protocol and Config.Party.RejoinMapName == Protocol.MemoryStoreNames.Rejoins, "House rejoin map must match CooperPartyProtocol")

		check(type(Config.Movement) == "table" and table.isfrozen(Config.Movement), "Config.Movement must be frozen")
		check(Config.Movement and Config.Movement.WalkSpeed == 16, "Walk speed must be 16")
		check(Config.Movement and Config.Movement.SprintSpeed == 22, "Sprint speed must be 22")
		check(Config.Movement and Config.Movement.SprintStaminaSeconds == 6, "Sprint stamina must be six seconds")
	end

	if game.PlaceId > 0 then
		check(game.PlaceId == EXPECTED_HOUSE_PLACE_ID, "House content is installed in the wrong place: " .. tostring(game.PlaceId))
	end
	if game.GameId > 0 then
		check(game.GameId == EXPECTED_UNIVERSE_ID, "House is outside the configured universe")
	end
	if RunService:IsStudio() then
		-- An already-open edit DataModel can retain a stale, read-only MaxPlayers
		-- cache. The frozen config is testable here; the Dashboard value remains a
		-- mandatory evidence row in MILESTONE1_TEST_MATRIX.md.
		check(Config and Config.ReleasePlayerCap == 4, "House release contract must remain exactly four")
		advise(Players.MaxPlayers == 4, "Studio reports house MaxPlayers=" .. tostring(Players.MaxPlayers)
			.. "; confirm the Creator Dashboard maximum visitor count is exactly 4")
	else
		check(Players.MaxPlayers == 4, "Published house capacity must be exactly four; current MaxPlayers is " .. tostring(Players.MaxPlayers))
	end

	local gameServer = directChild(ServerScriptService, "CooperGame", "Script")
	local gameServerSource = sourceOf(gameServer, "ServerScriptService.CooperGame")
	if gameServerSource then
		markers(gameServerSource, "CooperGame", {
			"M1_SHARED_TASK_SESSION_CONTRACT",
			"M1_TASK_ELIGIBILITY_CONTRACT",
			"local function sanitizeCalmTaskCheckpoint(raw)",
			"TransactionRuntime.commitCalmTaskStart(profile, recovered)",
			"CALM_TASK_START_EXPOSURE_AFTER_DURABLE_SAVE",
			"TransactionRuntime.armRecoveredEligibilityGrace(profile, record, checkpoint)",
			"local retainedInGuestGrace = eligibleProfile",
			"local retainedWhileLoading = loading",
			"hydrationGraceExpiresAtUnix",
			"local nextBoundaryUnix = expiresAt",
			"return nil, \"ProfileLoading\"",
			"recoveryGraceExpiresAt = recovered == true and checkpoint.recoveryGraceExpiresAt or 0",
			"return nil, \"RecoveredTaskGraceExpired\"",
			"recipient.data.calmTaskCheckpoint = nil",
			"M1_SERVER_TRANSACTION_JOURNAL_CONTRACT",
			"M1_HOST_ONLY_PURCHASE_GUARD",
			"M1_HOST_RECONNECT_GRACE_CONTRACT",
			"M1_GUEST_RECONNECT_GRACE_CONTRACT",
			"FoundationContract\", \"PartyV1",
			"PartySessionId",
			"PartyHostUserId",
			"PartyState",
			"PartyMemberCount",
			"HostGraceDeadline",
			"GetJoinData()",
			"Protocol.validateHouseTeleportData",
			"Protocol.MemoryStoreNames.Tickets",
			"Protocol.MemoryStoreNames.Sessions",
			"MemoryStoreService",
			"HostReconnectGraceSeconds",
			"GuestReconnectGraceSeconds",
			"partySession.state = \"HostGrace\"",
			"partySession.hostGraceDeadline = partySession.pausedAt + partyConfig.HostReconnectGraceSeconds",
			"task.delay(partyConfig.HostReconnectGraceSeconds, function()",
			"syncSessionManifest(\"HostGrace\", partySession.hostGraceUnixExpiresAt)",
			"syncSessionManifest(\"InHouse\", 0)",
			"syncSessionManifest(\"Closed\", 0)",
			"returnSavedPartyToLobby(savedPlayers)",
			"retained.detached ~= true",
			"tonumber(ticket.userId) ~= player.UserId",
			"if ticket.consumedByJobId ~= nil or ticket.consumedAt ~= nil then",
			"local claimNonce = Protocol.newOpaqueId(\"claim\")",
			"result.consumedClaimNonce ~= claimNonce",
			"manifest.expiresAt = renewedExpiresAt",
			"for userId, player in pairs(partySession.activePlayers) do",
			"local occupiedSlot = partySession.activePlayers[player.UserId]",
			"local guestReconnectAllowed = not retainedIsHost",
			"retained.loaded ~= true",
			"recoverHostWorldState(retained, player)",
			"closePartyAndReturn(",
			"reconnectRemaining",
			"cycleIndex",
			"local function captureTaskEligibility(version)",
			-- Schema 12 freezes the roster against the durable task ordinal, not
			-- the transient in-memory serial used by the older M1 implementation.
			"local eligibility = captureTaskEligibility(profile.data.totalTasks + 1)",
			"eligibilityResolutionByUserId = {}",
			"rewardOperationIdsByUserId = {}",
			"record.status = \"Completing\"",
			"record.completionWorkerActive = true",
			"if record.completionWorkerActive == true then",
			"if partySession.task ~= record or record.status ~= \"Completing\" then",
			"record.status = \"Completed\"",
			"local everyGuestTerminal = true",
			"if not everyGuestTerminal then",
			"The host's totalTasks value is the durable logical-task checkpoint.",
			"for _, userId in ipairs(record.eligibility.userIds) do",
			"local recipient, unavailableReason = eligibleProfileForTask(record, userId)",
			"forfeitTaskEligibility(record, userId, unavailableReason)",
			"setAllowance(recipient, recipient.data.allowance + reward)",
				"TransactionRuntime.commitProfileValueOperation(",
				"TransactionRuntime.commitPersistentTransition(",
				"TransactionRuntime.logicalOperationKind(",
				"TransactionRuntime.reserveProfileValueOperation(",
				"TransactionRuntime.resumePersistedReconciliations(profile)",
			"profile.reconciliationScheduled[operationId] ~= nil",
			"TransactionRuntime.purchaseStillAuthorized(profile, operationKind, price)",
				"return true, false, \"SavePendingAccepted\"",
			"TransactionLedger.markNeedsReconciliation(",
				"TransactionLedger.sessionMatches(existing, activeSessionId)",
				"expectedSessionId ~= activeSessionId",
				"profile.transactionReconciliationBlocked = true",
				"locked against another charge",
				'"CandyProduce"',
				'"CandyCollect"',
				'"CandySale"',
				'"InstallTaskUpgrade"',
				'"InstallChemistrySetup"',
				'"InstallBoombox"',
				'"InstallMachineStage"',
				'"BoomboxTick"',
				'operation == "AdjustCurrency" or operation == "SpendAllowance"',
				"DeprecatedOperation: use a named authoritative value operation",
				"partySession.completedTasks += 1",
			"math.floor(partySession.completedTasks / #Config.TaskOrder) + 1",
			"partySession.task = nil",
			"local worldProfile = hostProfile()",
			"delivery = deliverySnapshot(worldProfile, profile)",
			"boombox = boomboxSnapshot(worldProfile, profile)",
			"secretBunker = secretBunkerSnapshot(worldProfile, profile)",
			"chemistrySetup = chemistrySetupSnapshot(worldProfile, profile)",
			"automation = automationSnapshot(worldProfile, profile)",
		})
			lacks(gameServerSource, "rewardedUserIds", "CooperGame immutable task eligibility")
			lacks(gameServerSource, "local recipients = presentProfiles()", "CooperGame task completion")
			lacks(gameServerSource, "payload.operationId", "CooperGame client-supplied value operation id")
			lacks(gameServerSource, "local function adjustAllowance", "CooperGame legacy broad allowance authority")
		markers(gameServerSource, "CooperGame guest route cap", {
			"local function rejoinRouteExpiration(userId, sessionState, renewedExpiresAt, hostGraceExpiresAt)",
			"and activeProfile.loaded and not activeProfile.releasing",
			"An expected guest who has not yet arrived keeps the lobby-issued 90-second",
			"profile.guestGraceDeadline = serverNow() + partyConfig.GuestReconnectGraceSeconds",
			"expectedDetachedProfile.guestGraceSerial ~= expectedGraceSerial",
			"serverNow() < (tonumber(profile.guestGraceDeadline) or 0)",
			"serverNow() < (tonumber(retained.guestGraceDeadline) or 0)",
			"beginGuestReconnectGrace(profile, player)",
			"while resolution and resolution.status == \"Committing\"",
			"profilesByUserId[leavingPlayer.UserId] == profile",
		})
		lacks(gameServerSource, "serverNow() <= (tonumber(profile.guestGraceDeadline) or 0)", "Guest task eligibility expiry boundary")
		lacks(gameServerSource, "serverNow() <= (tonumber(retained.guestGraceDeadline) or 0)", "Guest rejoin expiry boundary")
		local guestGraceSection = functionSection(gameServerSource, "beginGuestReconnectGrace")
		if guestGraceSection then
			local settleAt = string.find(
				guestGraceSection,
				'while resolution and resolution.status == "Committing"',
				1,
				true
			)
			local releaseAt = string.find(guestGraceSection, "local saved = saveProfile(leavingPlayer, true)", 1, true)
			check(
				settleAt ~= nil and releaseAt ~= nil and settleAt < releaseAt,
				"Guest grace must settle a reserved task reward before releasing its profile lease"
			)
		end

		-- A profile-local task can silently split the party scheduler or duplicate
		-- rewards. Persistent delivery fields named taskUpgrade remain valid.
		for _, retiredPersonalTaskMarker in ipairs({
			"local record = profile.task",
			"local activeTask = profile.task",
			"not profile.task and",
			"profile.task ~= bankSession.record",
			"profile.taskCursor =",
			"profile.nextTaskAt",
		}) do
			lacks(gameServerSource, retiredPersonalTaskMarker, "CooperGame shared scheduler")
		end

		local purchaseFunctions = {
			"orderMachinePart",
			"orderBoombox",
			"upgradeBoomboxAutoplay",
			"orderTaskUpgrade",
			"orderSecretBunker",
			"orderChemistrySetup",
		}
		for _, purchaseFunction in ipairs(purchaseFunctions) do
			local section = functionSection(gameServerSource, purchaseFunction)
			check(section ~= nil, "Host-gated purchase function is missing: " .. purchaseFunction)
			if section then
				check(
					contains(section, "hostMutationAllowed(profile)"),
					purchaseFunction .. " must invoke the shared host/progression guard before mutation"
				)
				local guardAt = string.find(section, "hostMutationAllowed(profile)", 1, true)
				local transactionAt = string.find(section, "TransactionRuntime.commitHostPurchase(", 1, true)
				local debitAt = string.find(section, "setAllowance(profile, profile.data.allowance -", 1, true)
				check(
					transactionAt ~= nil,
					purchaseFunction .. " must use the shared schema-12 transaction journal"
				)
				check(
					guardAt ~= nil and transactionAt ~= nil and guardAt < transactionAt
						and (debitAt == nil or transactionAt < debitAt),
					purchaseFunction .. " must authorize the host and open a transaction before any debit"
				)
			end
		end
			local purchaseCommitSection = functionSection(gameServerSource, "TransactionRuntime.commitHostPurchase")
		check(purchaseCommitSection ~= nil, "Schema-12 purchase commit helper is missing")
		if purchaseCommitSection then
			check(
				contains(
					purchaseCommitSection,
					"TransactionRuntime.purchaseStillAuthorized(profile, operationKind, price)"
				),
				"Queued purchases must revalidate domain ownership and delivery preconditions inside the serialized transaction"
			)
		end
		local valueCommitSection = functionSection(
			gameServerSource,
			"TransactionRuntime.commitProfileValueOperation"
		)
		check(valueCommitSection ~= nil, "Profile value-operation commit helper is missing")
		if type(valueCommitSection) == "string" then
			local lookupAt = string.find(valueCommitSection, "TransactionLedger.lookup(journal, operationId)", 1, true)
			local committedRetryAt = string.find(valueCommitSection, 'if existing.state == "Committed" then', 1, true)
			local reconciliationBlockAt = string.find(
				valueCommitSection,
				"if profile.transactionReconciliationBlocked == true then",
				1,
				true
			)
			local authorizeAt = string.find(valueCommitSection, "local authorizeOk, authorized, denial = pcall(authorize)", 1, true)
			check(
				lookupAt ~= nil and committedRetryAt ~= nil and reconciliationBlockAt ~= nil
					and authorizeAt ~= nil and lookupAt < committedRetryAt
					and committedRetryAt < reconciliationBlockAt
					and reconciliationBlockAt < authorizeAt,
				"Terminal operation retries must return their saved result before mutable domain authorization"
			)
		end
		local completeTaskSection = functionSection(gameServerSource, "completeTask")
		if completeTaskSection then
			local casAt = string.find(completeTaskSection, 'record.status = "Completed"', 1, true)
			local advanceAt = string.find(completeTaskSection, "partySession.completedTasks += 1", 1, true)
			local closeAt = string.find(completeTaskSection, "partySession.task = nil", 1, true)
			check(
				casAt ~= nil and advanceAt ~= nil and closeAt ~= nil and casAt < advanceAt and advanceAt < closeAt,
				"Shared task finalization must claim Completed before advancing and atomically close the same record"
			)
		end
		local checkpointCommitSection = functionSection(
			gameServerSource,
			"TransactionRuntime.commitCalmTaskStart"
		)
		check(checkpointCommitSection ~= nil, "CalmTaskStart durable commit helper is missing")
		if type(checkpointCommitSection) == "string" then
			local saveAt = string.find(
				checkpointCommitSection,
				"durable = TransactionRuntime.safeSave(profile)",
				1,
				true
			)
			local exposeAt = string.find(
				checkpointCommitSection,
				"TransactionRuntime.exposeCalmTaskCheckpoint(profile, checkpoint, recovered)",
				saveAt or 1,
				true
			)
			check(
				saveAt ~= nil and exposeAt ~= nil and saveAt < exposeAt,
				"CalmTaskStart must be durably saved before any task exposure"
			)
			check(
				contains(checkpointCommitSection, "profile.calmTaskCheckpointWriteInFlight")
					and contains(checkpointCommitSection, "profile.calmTaskCheckpointRetryAt")
					and contains(checkpointCommitSection, "profile.calmTaskCheckpointRetryCount"),
				"CalmTaskStart persistence retries need a single-writer bounded backoff"
			)
		end
		local saveProfileSection = functionSection(gameServerSource, "saveProfile")
		check(saveProfileSection ~= nil, "Serialized profile save helper is missing")
		if type(saveProfileSection) == "string" then
			local loopAt = string.find(saveProfileSection, "repeat", 1, true)
			local revisionAt = string.find(saveProfileSection, "local savedRevision = profile.revision or 0", 1, true)
			local payloadAt = string.find(saveProfileSection, "local payload = sanitizeData(profile.data)", 1, true)
			local updateAt = string.find(saveProfileSection, "dataStore:UpdateAsync", 1, true)
			check(
				loopAt ~= nil and revisionAt ~= nil and payloadAt ~= nil and updateAt ~= nil
					and loopAt < revisionAt and revisionAt < payloadAt and payloadAt < updateAt,
				"Every serialized save retry must snapshot the matching current revision and payload"
			)
		end
		lacks(gameServerSource, "FeatureHorrorEnabled\", true", "CooperGame")
	end

	local movementServer = directChild(ServerScriptService, "CooperMovement", "Script")
	local movementSource = sourceOf(movementServer, "ServerScriptService.CooperMovement")
	if movementSource then
		markers(movementSource, "CooperMovement", {
			"local WALK_SPEED = 16",
			"local SPRINT_SPEED = 22",
			"local MAX_STAMINA = 6",
			"local REMOTES_NAME = \"CooperMovementRemotes\"",
			"local INTENT_EVENT_NAME = \"SprintIntent\"",
			"local API_NAME = \"CooperMovementAPI\"",
			"RunService.Heartbeat",
			"humanoid.MoveDirection",
			"humanoid.SeatPart",
			"INTENT_BUCKET_CAPACITY",
			"CooperMovementLocked",
			"CooperCarrySpeedMultiplier",
			"CooperComputerSessionUntil",
			"CooperBunkerComputerSessionUntil",
		})
		lacks(movementSource, "OnServerEvent:Connect(function(player, stamina", "CooperMovement")
	end
	for _, consumerName in ipairs({ "CooperTaskWorld", "CooperInteractions" }) do
		local consumer = directChild(ServerScriptService, consumerName, "Script")
		local consumerSource = sourceOf(consumer, "ServerScriptService." .. consumerName)
		if consumerSource then
			lacks(consumerSource, "humanoid.WalkSpeed =", "ServerScriptService." .. consumerName)
			check(
				contains(consumerSource, "CooperMovementAPI"),
				"ServerScriptService." .. consumerName .. " must compose movement through CooperMovementAPI"
			)
			if consumerName == "CooperTaskWorld" then
				local activeTaskSource = functionSection(consumerSource, "activeTask")
				check(activeTaskSource ~= nil, "CooperTaskWorld.activeTask is missing")
				if activeTaskSource then
					check(
						contains(activeTaskSource, 'current.party.state ~= "Active"'),
						"CooperTaskWorld must reject task prompts while host-grace pauses the party"
					)
				end
				markers(consumerSource, "CooperTaskWorld host-grace commits", {
					'if invokeFamily("ReportAction", player, "TrashDelivered", {}) == true then',
					'if fridge and invokeFamily("ReportAction", player, "BeerDelivered", {}) == true then',
					"The party may have paused between validation and commit.",
				})
			end
			local transitionCommitSection = functionSection(
				gameServerSource,
				"TransactionRuntime.commitPersistentTransition"
			)
			check(transitionCommitSection ~= nil, "Persistent value-transition helper is missing")
			if transitionCommitSection then
				markers(transitionCommitSection, "Persistent value-transition helper", {
					"TransactionRuntime.findLogicalOperation(profile, kind)",
					"existing and existing.id or nil",
					"TransactionRuntime.commitProfileValueOperation(",
					'"TransactionReconciliation"',
				})
			end
			local installSection = functionSection(gameServerSource, "reportPlayerAction")
			check(installSection ~= nil, "Persistent install action section is missing")
			if installSection then
				check(
					countPlain(installSection, "TransactionRuntime.commitPersistentTransition(") == 4,
					"Exactly four paid physical install transitions must be journaled"
				)
				check(
					countPlain(installSection, "if appliedNow then") == 4,
					"Paid install presentation must run only on the first application"
				)
				lacks(installSection, "setAllowance(", "Paid install transition")
				lacks(installSection, "task.defer(saveProfile", "Paid install transition")
			end
			for _, candyFunction in ipairs({
				"createCandyBatch",
				"beginCandyDelivery",
				"completeCandyDelivery",
			}) do
				local section = functionSection(gameServerSource, candyFunction)
				check(section ~= nil, "Candy value transition is missing: " .. candyFunction)
				if section then
					check(
						countPlain(section, "TransactionRuntime.commitPersistentTransition(") == 1,
						candyFunction .. " must contain exactly one journaled transition"
					)
				end
			end
			local boomboxCreditSection = functionSection(
				gameServerSource,
				"TransactionRuntime.creditBoomboxTick"
			)
			check(boomboxCreditSection ~= nil, "Journaled boombox tick helper is missing")
				if boomboxCreditSection then
				markers(boomboxCreditSection, "Journaled boombox tick helper", {
					'"BoomboxTick"',
					"tostring(playback.sessionId) .. \":\" .. tostring(tickIndex)",
					"TransactionRuntime.commitPersistentTransition(",
					"playback.paidTicks == tickIndex - 1",
					"return appliedNow and payout or 0, true, status",
				})
				check(
					countPlain(boomboxCreditSection, "setAllowance(profile, profile.data.allowance + payout)") == 1,
					"One boombox tick must contain exactly one allowance mutation"
					)
				end
				local boomboxSettlementSection = functionSection(
					gameServerSource,
					"TransactionRuntime.settleCompletedBoombox"
				)
				check(boomboxSettlementSection ~= nil, "Completed-song boombox settlement helper is missing")
				if boomboxSettlementSection then
					markers(boomboxSettlementSection, "Completed-song boombox settlement", {
						'"BoomboxSettle"',
						"playback.settlementValue",
						"setAllowance(profile, profile.data.allowance + settlementValue)",
						"paidTicks = maximumTicks",
						"TransactionRuntime.commitPersistentTransition(",
					})
					check(
						countPlain(boomboxSettlementSection, "setAllowance(") == 1,
						"Completed-song settlement must contain exactly one catch-up allowance mutation"
					)
				end
		end
	end

	local sprintClient = directChild(starterScripts, "CooperSprint", "LocalScript")
	local sprintSource = sourceOf(sprintClient, "StarterPlayer.StarterPlayerScripts.CooperSprint")
	if sprintSource then
		markers(sprintSource, "CooperSprint", {
			"ContextActionService",
			"Enum.KeyCode.LeftShift",
			"Enum.KeyCode.RightShift",
			"Enum.ScreenInsets.CoreUISafeInsets",
			"CooperStamina",
			"CooperStaminaMax",
			"CooperSprinting",
			"TOUCH_BUTTON_SIZE = 64",
			"ContextActionService:BindActionAtPriority(",
			"staminaCard.Visible = not blockedByWorld and (sprinting or stamina < staminaMax - 0.01)",
		})
		lacks(sprintSource, "humanoid.WalkSpeed =", "CooperSprint client")
	end

	if running then
		local partyDeadline = os.clock() + 15
		while os.clock() < partyDeadline
			and (state:GetAttribute("FoundationContract") ~= "PartyV1"
				or (tonumber(state:GetAttribute("PartyMemberCount")) or 0) < 1)
		do
			task.wait(0.1)
		end
		check(state:GetAttribute("FoundationContract") == "PartyV1", "Runtime foundation contract must be PartyV1")
		check(state:GetAttribute("FeatureLobbyEnabled") == true, "Runtime lobby feature must be enabled")
		for _, attributeName in ipairs({
			"FeatureHorrorEnabled",
			"FeatureSecretExplorationEnabled",
			"FeatureTimeMachineFinaleEnabled",
			"FeaturePostgameEnabled",
			"FeatureStudioScenarioToolsEnabled",
		}) do
			check(state:GetAttribute(attributeName) == false, attributeName .. " must remain false")
		end
		check(state:GetAttribute("ReleasePlayerCap") == 4, "Runtime release cap attribute must be four")
		check(type(state:GetAttribute("PartySessionId")) == "string" and state:GetAttribute("PartySessionId") ~= "", "Runtime party session ID is missing")
		check(type(state:GetAttribute("PartyHostUserId")) == "number" and state:GetAttribute("PartyHostUserId") > 0, "Runtime party host is missing")
		check(type(state:GetAttribute("PartyState")) == "string", "Runtime party state is missing")
		check(type(state:GetAttribute("PartyMemberCount")) == "number" and state:GetAttribute("PartyMemberCount") >= 1 and state:GetAttribute("PartyMemberCount") <= 4, "Runtime party member count is invalid")
		check(type(state:GetAttribute("HostGraceDeadline")) == "number", "Runtime host grace deadline attribute is missing")

		local movementRemotes = directChild(ReplicatedStorage, "CooperMovementRemotes", "Folder")
		directChild(movementRemotes, "SprintIntent", "RemoteEvent")
		check(movementRemotes:GetAttribute("WalkSpeed") == 16, "Movement remotes must advertise walk speed 16")
		check(movementRemotes:GetAttribute("SprintSpeed") == 22, "Movement remotes must advertise sprint speed 22")
		check(movementRemotes:GetAttribute("SprintStaminaSeconds") == 6, "Movement remotes must advertise six-second stamina")
		check(movementRemotes:GetAttribute("ServerAuthoritative") == true, "Movement remotes must advertise server authority")
		local movementAPI = directChild(ServerScriptService, "CooperMovementAPI", "Folder")
		check(movementAPI:GetAttribute("ContractVersion") == 1, "Movement server API contract must be v1")
		directChild(movementAPI, "SetLock", "BindableFunction")
		directChild(movementAPI, "SetSpeedMultiplier", "BindableFunction")
		directChild(movementAPI, "ReleaseSource", "BindableEvent")
		directChild(movementAPI, "StateChanged", "BindableEvent")
		for _, player in ipairs(Players:GetPlayers()) do
			local movementDeadline = os.clock() + 10
			while player.Parent == Players
				and player:GetAttribute("CooperMovementReady") ~= true
				and os.clock() < movementDeadline
			do
				task.wait(0.1)
			end
			check(player:GetAttribute("CooperMovementReady") == true, player.Name .. " movement is not ready")
			check(type(player:GetAttribute("CooperStamina")) == "number", player.Name .. " has no server stamina")
			check(player:GetAttribute("CooperStaminaMax") == 6, player.Name .. " stamina max must be six")
			check(type(player:GetAttribute("CooperSprinting")) == "boolean", player.Name .. " sprint state is missing")
		end
	end

	-- Exactly four approved normal cutout family NPCs. M1 does not introduce
	-- Sheldon, Billy, Mandy, Meemaw, cards, or horror art.
	local approved = { George = true, Mary = true, Missy = true, Georgie = true }
	local approvedOrder = { "George", "Mary", "Missy", "Georgie" }
	local npcServer = directChild(ServerScriptService, "CooperFamilyNPCs", "Script")
	local npcSource = sourceOf(npcServer, "ServerScriptService.CooperFamilyNPCs")
	if npcSource then
		local definitionsAt = string.find(npcSource, "local definitions = {", 1, true)
		local definitionsEnd = definitionsAt and string.find(npcSource, "local randomizer = Random.new()", definitionsAt, true) or nil
		check(definitionsAt ~= nil and definitionsEnd ~= nil, "Family NPC definition boundaries are missing")
		if definitionsAt and definitionsEnd then
			local section = string.sub(npcSource, definitionsAt, definitionsEnd - 1)
			local foundNames = {}
			for characterName in string.gmatch(section, 'name%s*=%s*"([^"]+)"') do
				table.insert(foundNames, characterName)
			end
			check(#foundNames == 4, "CooperFamilyNPCs must define exactly four NPCs")
			for index, characterName in ipairs(approvedOrder) do
				check(foundNames[index] == characterName, "Family NPC order changed at position " .. index)
			end
		end
		lacks(npcSource, "HorrorMode", "CooperFamilyNPCs")
	end
	local imageFolder = ReplicatedStorage:FindFirstChild("CooperFamilyLocalImages")
	check(imageFolder and imageFolder:IsA("Folder"), "CooperFamilyLocalImages is missing")
	if imageFolder then
		local count = 0
		for _, child in ipairs(imageFolder:GetChildren()) do
			count += 1
			check(child:IsA("StringValue") and approved[child.Name] == true, "Unapproved family image entry: " .. child.Name)
		end
		check(count == 4, "There must be exactly four normal family image entries")
	end
	local environment = Workspace:FindFirstChild("CooperHouseEnvironment")
	check(environment and environment:IsA("Model"), "CooperHouseEnvironment is missing")
	local npcWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
	if running and not npcWorld then
		local deadline = os.clock() + 12
		while not npcWorld and os.clock() < deadline do
			task.wait(0.1)
			npcWorld = environment and environment:FindFirstChild("CooperFamilyNPCs")
		end
	end
	if running then
		check(npcWorld and npcWorld:IsA("Folder"), "Runtime family NPC folder did not start")
	end
	if npcWorld then
		local count = 0
		for _, child in ipairs(npcWorld:GetChildren()) do
			if child:IsA("Model") then
				count += 1
				check(approved[child.Name] == true, "Unapproved runtime NPC: " .. child.Name)
				check(child:GetAttribute("Cooper2DCharacter") == true, child.Name .. " is not a 2D cutout")
				check(not child:FindFirstChildWhichIsA("TextLabel", true), child.Name .. " has a forbidden text card")
			end
		end
		check(count == 4, "Runtime must contain exactly four family NPC models")
	end
elseif isLobby then
	-- Dedicated lobby place --------------------------------------------------
	local lobbyEnvironment = directChild(Workspace, "CooperPartyLobbyEnvironment", "Model")
	check(Workspace:FindFirstChild("CooperHouseEnvironment") == nil, "Lobby must not retain the Cooper house environment")
	check(Workspace.StreamingEnabled == false, "Lightweight lobby should not enable workspace streaming")
	if lobbyEnvironment then
		check(lobbyEnvironment:GetAttribute("Milestone") == 1, "Lobby environment milestone marker must be 1")
		check(lobbyEnvironment:GetAttribute("EnvironmentVersion") == "2.0.0", "Lobby environment version changed")
		check(lobbyEnvironment:GetAttribute("Purpose") == "PrivatePartyLobby", "Lobby environment purpose marker changed")
		check(lobbyEnvironment:GetAttribute("Theme") == "1980sSuburbanRecRoom", "Lobby must retain its 1980s suburban rec-room theme")
		check(lobbyEnvironment:GetAttribute("VisualUpdater") == "ScopedIdempotent", "Lobby visuals must come from the scoped idempotent updater")
		directChild(lobbyEnvironment, "LobbySpawn", "SpawnLocation")
		local architecture = directChild(lobbyEnvironment, "Architecture", "Folder")
		local furniture = directChild(lobbyEnvironment, "Furniture", "Folder")
		local decor = directChild(lobbyEnvironment, "PeriodDecor", "Folder")
		directChild(lobbyEnvironment, "PracticalLights", "Folder")
		if architecture then
			directChild(architecture, "PrivateHouseDoorway", "Model")
		end
		if furniture then
			directChild(furniture, "CRTPartyDisplay", "Model")
			directChild(furniture, "AvocadoSofa", "Model")
			directChild(furniture, "RustArmchair", "Model")
		end
		if decor then
			directChild(decor, "FamilyBulletinBoard", "Part")
			directChild(decor, "HouseBlueprint", "Part")
			local partyRugs = directChild(decor, "PartyRugMarkers", "Folder")
			if partyRugs then
				local rugCount = 0
				local insetCount = 0
				for _, child in ipairs(partyRugs:GetChildren()) do
					if child:IsA("BasePart") and string.match(child.Name, "^PartyRug%d+$") then
						rugCount += 1
					elseif child:IsA("BasePart") and string.match(child.Name, "^PartyRugInset%d+$") then
						insetCount += 1
					end
				end
				check(rugCount == 4, "Lobby must retain exactly four woven party rugs")
				check(insetCount == 4, "Lobby must retain exactly four numbered party-rug insets")
			end
		end
		check(lobbyEnvironment:FindFirstChild("PrivateHousePortal", true) == nil, "Retired sci-fi portal returned to the lobby")
		check(lobbyEnvironment:FindFirstChild("PartyPads", true) == nil, "Retired glowing party pads returned to the lobby")
	end
	check(StarterPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable, "Lobby computer movement must stay UI-only")
	check(StarterPlayer.DevTouchMovementMode == Enum.DevTouchMovementMode.Scriptable, "Lobby touch movement must stay UI-only")
	check(StarterPlayer.AutoJumpEnabled == false, "Lobby auto-jump must remain disabled")

	local configModule = directChild(lobbyRoot, "Config", "ModuleScript")
	local LobbyConfig = loadDataModule(configModule, "ReplicatedStorage.CooperLobby.Config")
	if LobbyConfig then
		check(table.isfrozen(LobbyConfig), "Lobby config must be frozen")
		check(LobbyConfig.ProtocolVersion == 1, "Lobby protocol version must be 1")
		check(LobbyConfig.UniverseId == EXPECTED_UNIVERSE_ID, "Lobby universe ID changed")
		check(LobbyConfig.HousePlaceId == EXPECTED_HOUSE_PLACE_ID, "Lobby house place ID changed")
		check(LobbyConfig.LobbyPlaceId == EXPECTED_LOBBY_PLACE_ID, "LobbyPlaceId must identify the published start place")
		check(LobbyConfig.LobbyPlaceId ~= LobbyConfig.HousePlaceId, "Lobby and house must be different places")
		check(LobbyConfig.MinimumPartySize == 1 and LobbyConfig.MaximumPartySize == 4, "Lobby party bounds must be 1–4")
		check(LobbyConfig.GuestAdmissionGraceSeconds == 90, "Guest admission grace must be exactly 90 seconds")
		check(LobbyConfig.RejoinTicketTTLSeconds == 90, "Guest rejoin ticket must expire after 90 seconds")
		check(Protocol and LobbyConfig.MaximumPartySize == Protocol.MAX_PARTY_SIZE, "Lobby and protocol party caps differ")
		check(LobbyConfig.StudioPreview == true, "Studio preview adapter must remain explicitly configured")
		if game.PlaceId > 0 then
			check(game.PlaceId == LobbyConfig.LobbyPlaceId, "This place does not match Config.LobbyPlaceId")
		end
		if game.GameId > 0 then
			check(game.GameId == LobbyConfig.UniverseId, "Lobby is not in the configured universe")
		end
	end
	check(
		Players.MaxPlayers >= MINIMUM_LOBBY_CAPACITY,
		"Lobby capacity must be at least four; current MaxPlayers is " .. tostring(Players.MaxPlayers)
	)
	advise(
		Players.MaxPlayers >= RECOMMENDED_LOBBY_CAPACITY,
		"Lobby MaxPlayers=" .. tostring(Players.MaxPlayers)
			.. "; 50 is recommended so multiple private parties can form concurrently"
	)

	local lobbyServer = directChild(ServerScriptService, "CooperLobby", "Script")
	local lobbyServerSource = sourceOf(lobbyServer, "ServerScriptService.CooperLobby")
	if lobbyServerSource then
		markers(lobbyServerSource, "CooperLobby server", {
			"HttpService",
			"MemoryStoreService",
			"TeleportService",
				"ReserveServerAsync",
				"local TELEPORT_REQUEST_ATTEMPTS = 2",
				"local TELEPORT_RETRY_DELAY_SECONDS = 0.35",
				"ReservedServerAccessCode",
			"makeHouseTeleportData",
			"Protocol.MemoryStoreNames.Tickets",
			"Protocol.MemoryStoreNames.Sessions",
			"Protocol.MemoryStoreNames.Rejoins",
			"M1_GUEST_ADMISSION_GRACE_CONTRACT",
			"lobbyPlaceId = Config.LobbyPlaceId",
			"housePlaceId = Config.HousePlaceId",
			"local ticketIdsByUserId",
			'local ticketId = Protocol.newOpaqueId("arrival")',
			"local rejoinRouteLifetime = if userId == party.hostUserId",
			"local arrivalTicketLifetime = if userId == party.hostUserId",
			"else Config.GuestAdmissionGraceSeconds",
			"expiresAt = now + arrivalTicketLifetime",
			"expiresAt = now + rejoinRouteLifetime",
			"userId = userId",
			"type TeleportRetryContext = {",
			"local teleportRetryContexts: { [number]: TeleportRetryContext } = {}",
			"local function requestTeleportWithContext(player: Player, context: TeleportRetryContext): boolean",
			"TeleportService:TeleportAsync(context.placeId, { player }, context.options)",
			"local retryContext: TeleportRetryContext = {",
			"placeId = Config.HousePlaceId",
			"options = options",
			"token = teleportToken",
			"teleportRetryContexts[userId] = retryContext",
			"requestTeleportWithContext(member, retryContext)",
			'if action == "CreateParty" then',
			'elseif action == "PlaySolo" then',
			'elseif action == "SetReady" then',
			'elseif action == "InviteFriends" then',
			'elseif action == "Launch" then',
			"Only the party host can start the house session.",
			"Everyone must be ready before the host can start.",
			"partyRevision = partyRevision(party)",
			'launchBlockReasonCode = "WAITING_FOR_READY"',
			"local requestRateByUserId",
			"local function consumeActionBudget",
			"state.lastByAction[action]",
			'emitLobbyDiagnostic("ready_committed", "READY_COMMITTED"',
			'emitLobbyDiagnostic("launch_preflight_started", "LAUNCH_PREFLIGHT_STARTED"',
			'emitLobbyDiagnostic("party_snapshot_locked", "LAUNCH_SNAPSHOT_LOCKED"',
			'emitLobbyDiagnostic("reserved_server_created", "RESERVED_SERVER_CREATED"',
			'emitLobbyDiagnostic("session_manifest_written", "SESSION_MANIFEST_WRITTEN"',
			'emitLobbyDiagnostic("member_ticket_written", "MEMBER_TICKET_WRITTEN"',
				'emitLobbyDiagnostic("teleport_requested", "TELEPORT_REQUESTED"',
				'emitLobbyDiagnostic("teleport_retry_requested", "TELEPORT_REQUEST_RETRY"',
				'emitLobbyDiagnostic("teleport_retry_requested", "TELEPORT_INIT_RETRY"',
				"for attempt = 1, TELEPORT_REQUEST_ATTEMPTS do",
				"retryContext.attempts < retryContext.maximumAttempts",
				"teleporting[userId] == teleportToken",
				"TeleportService.TeleportInitFailed:Connect(function(",
				"returnedData.sessionId == retryContext.sessionId",
				"returnedData.partyId == retryContext.partyId",
				"returnedData.ticketId == retryContext.ticketId",
				"retryContext.options = teleportOptions",
				"requestTeleportWithContext(player, retryContext)",
				"local function renewLaunchOwnership",
			"and party.launchSessionId == sessionId",
			"if type(current) == \"table\" and current.sessionId == sessionId then",
		})
		lacks(lobbyServerSource, "local lastRequestAt", "CooperLobby server")
		local rateLimiterSource = functionSection(lobbyServerSource, "consumeActionBudget")
		check(rateLimiterSource ~= nil, "CooperLobby request-rate function is missing")
		if rateLimiterSource then
			markers(rateLimiterSource, "CooperLobby request-rate function", {
				"lastByAction",
				"REQUEST_BURST_CAPACITY",
				"REQUEST_REFILL_PER_SECOND",
				"minimumActionGap(action)",
			})
		end
		local diagnosticSource = functionSection(lobbyServerSource, "emitLobbyDiagnostic")
		check(diagnosticSource ~= nil, "CooperLobby structured diagnostic function is missing")
		if diagnosticSource then
			lacks(diagnosticSource, "accessCode", "CooperLobby diagnostic function")
			lacks(diagnosticSource, "ticketId", "CooperLobby diagnostic function")
			lacks(diagnosticSource, "TeleportData", "CooperLobby diagnostic function")
		end
		lacks(lobbyServerSource, 'GetService("MatchmakingService")', "CooperLobby server")
	end

	local lobbyClient = directChild(starterScripts, "CooperLobby", "LocalScript")
	local lobbyClientSource = sourceOf(lobbyClient, "StarterPlayer.StarterPlayerScripts.CooperLobby")
	if lobbyClientSource then
		markers(lobbyClientSource, "CooperLobby client", {
			"PLAY SOLO",
			"CREATE A PRIVATE PARTY",
			"INVITE FRIENDS",
			"I'M READY",
			"START PRIVATE HOUSE",
			"local UITheme = loadCooperUITheme()",
			"local THEME = UITheme.Colors",
			"gui.ScreenInsets = UITheme.Accessibility.ScreenInsets",
			"gui.ClipToDeviceSafeArea = UITheme.Accessibility.ClipToDeviceSafeArea",
			"authoritativeSelfReady = state.selfReady == true",
			"tonumber(state.partyRevision)",
			"state.launchBlockMessage",
			"button.Size = UDim2.new(1, 0, 0, UITheme.Metrics.ActionHeight)",
			"button.NextSelectionDown",
			"updateResponsiveLayout",
			"camera.CameraType = Enum.CameraType.Scriptable",
			"camera.CFrame = CFrame.lookAt",
			"STUDIO PARTY TEST",
			"validatedPartyRevision",
		})
		lacks(lobbyClientSource, "string.find(readyButton.Text", "CooperLobby client")
		lacks(lobbyClientSource, "local THEME = table.freeze({", "CooperLobby client")
		markers(lobbyClientSource, "CooperLobby stale-place fallback", {
			"if themeModule == nil then",
			"using embedded v1 compatibility palette for this stale place",
			'assert(themeModule:IsA("ModuleScript")',
			"CooperUITheme v1 is required",
		})
		lacks(lobbyClientSource, "pcall(require", "CooperLobby theme loader")
	end

	if running then
		local remotes = directChild(ReplicatedStorage, "CooperPartyLobby", "Folder")
		directChild(remotes, "Request", "RemoteFunction")
		directChild(remotes, "State", "RemoteEvent")
		directChild(remotes, "ClientCommand", "RemoteEvent")
	end
end

for _, advisory in ipairs(advisories) do
	warn("[Milestone1FoundationAudit] ADVISORY: " .. advisory)
end

if #failures > 0 then
	error(string.format(
		"[Milestone1FoundationAudit] FAIL (%d of %d checks, %s %s mode):\n - %s",
		#failures,
		checkCount,
		placeRole,
		running and "runtime" or "edit",
		table.concat(failures, "\n - ")
	), 0)
end

print(string.format(
	"[Milestone1FoundationAudit] PASS: %d read-only checks in %s %s mode; party v1, 1–4 players, shared tasks, host authority, 60-second grace, sprint 16/22/6, and pre-horror lock verified",
	checkCount,
	placeRole,
	running and "runtime" or "edit"
))
return true
