--!nonstrict
-- Standalone, non-mutating audit for the paid secret-bunker phase unlock.
-- Safe to run from Studio's command bar in edit mode or after play-mode startup.
--
-- This verifier intentionally combines source-contract checks with installed
-- geometry checks. The economy remains personal and server-authoritative, while
-- the construction convoy is a shared world presentation driven only by the
-- player's durable purchase timestamp.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local running = RunService:IsRunning()
local checks = 0

local function check(condition, message)
	checks += 1
	assert(condition, "[SecretBunkerAudit] " .. message)
end

local function need(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	check(item ~= nil, string.format(
		"Missing %s.%s",
		parent and parent:GetFullName() or "nil",
		name
	))
	if className then
		check(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function needDescendant(parent, name, className)
	local item = parent and parent:FindFirstChild(name, true)
	check(item ~= nil, string.format(
		"Missing descendant %s under %s",
		name,
		parent and parent:GetFullName() or "nil"
	))
	if className then
		check(item:IsA(className), item:GetFullName() .. " must be a " .. className)
	end
	return item
end

local function sourceOf(scriptObject, minimumLength)
	check(
		scriptObject:IsA("Script")
			or scriptObject:IsA("LocalScript")
			or scriptObject:IsA("ModuleScript"),
		scriptObject:GetFullName() .. " is not source-bearing"
	)
	if scriptObject:IsA("Script") or scriptObject:IsA("LocalScript") then
		check(not scriptObject.Disabled, scriptObject:GetFullName() .. " is disabled")
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	check(ok and type(source) == "string", "Studio could not read " .. scriptObject:GetFullName() .. ".Source")
	check(
		#source >= (minimumLength or 1000),
		scriptObject:GetFullName() .. " has empty, placeholder, or incomplete source"
	)
	return source
end

local function has(source, marker, message)
	check(
		string.find(source, marker, 1, true) ~= nil,
		message or ("Source is missing " .. marker)
	)
end

local function lacks(source, marker, message)
	check(
		string.find(source, marker, 1, true) == nil,
		message or ("Source unexpectedly contains " .. marker)
	)
end

local function hasAny(source, markers, message)
	for _, marker in ipairs(markers) do
		if string.find(source, marker, 1, true) then
			checks += 1
			return marker
		end
	end
	check(false, message or ("Source is missing every accepted marker: " .. table.concat(markers, ", ")))
	return nil
end

local function section(source, startMarker, endMarker, label)
	local startAt = string.find(source, startMarker, 1, true)
	check(startAt ~= nil, (label or "Source") .. " is missing section start " .. startMarker)
	local endAt = startAt and string.find(source, endMarker, startAt + #startMarker, true) or nil
	check(endAt ~= nil, (label or "Source") .. " is missing section end " .. endMarker)
	return string.sub(source, startAt, endAt - 1)
end

local function ordered(source, markers, message)
	local cursor = 1
	for _, marker in ipairs(markers) do
		local found = string.find(source, marker, cursor, true)
		check(found ~= nil, (message or "Required source ordering is missing") .. ": " .. marker)
		cursor = found + #marker
	end
end

local function countPlain(source, marker)
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

local function hasLower(source, marker, message)
	check(
		string.find(string.lower(source), string.lower(marker), 1, true) ~= nil,
		message or ("Source is missing case-insensitive marker " .. marker)
	)
end

local function descendantNameContains(root, token)
	local count = 0
	local lowered = string.lower(token)
	for _, descendant in ipairs(root:GetDescendants()) do
		if string.find(string.lower(descendant.Name), lowered, 1, true) then
			count += 1
		end
	end
	return count
end

local function baseParts(root)
	local result = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(result, descendant)
		end
	end
	return result
end

local function findSemanticPart(root, preferredName, attributes)
	local preferred = root:FindFirstChild(preferredName, true)
	if preferred and preferred:IsA("BasePart") then
		return preferred
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, attributeName in ipairs(attributes) do
				local value = descendant:GetAttribute(attributeName)
				if value == true
					or value == preferredName
					or value == "GrassCover"
					or value == "BunkerGrassCover"
				then
					return descendant
				end
			end
		end
	end
	return nil
end

-- Canonical schema, balance, and migration defaults ------------------------

local gameRoot = need(ReplicatedStorage, "CooperGame", "Folder")
local configModule = need(gameRoot, "Config", "ModuleScript")
local state = need(gameRoot, "State", "Folder")
local remotes = need(gameRoot, "Remotes", "Folder")
need(remotes, "Snapshot", "RemoteEvent")
need(remotes, "Feedback", "RemoteEvent")
need(remotes, "Request", "RemoteEvent")

local Config
if running then
	Config = require(configModule)
else
	-- Studio's plugin/command VM may retain a previous require result after an
	-- installer rerun. Require a temporary clone, then immediately remove it.
	local freshConfig = configModule:Clone()
	freshConfig.Name = "__SecretBunkerAuditConfig"
	freshConfig.Parent = gameRoot
	Config = require(freshConfig)
	freshConfig:Destroy()
end

check(type(Config) == "table", "CooperGame.Config did not return a table")
check(table.isfrozen(Config), "The top-level gameplay config must remain frozen")
check(Config.SchemaVersion == 12, "Secret bunker persistence requires schema 12")
check(Config.DataStoreName == "CooperFamilyTasks_v2", "The bunker must migrate the existing profile DataStore")
check(Config.DataStoreKeyPrefix == "player_", "Unexpected profile key prefix")

local bunkerConfig = Config.SecretBunker
check(type(bunkerConfig) == "table", "Config.SecretBunker is missing")
check(bunkerConfig.Id == "secretbunker.underground", "Secret bunker terminal id changed")
check(bunkerConfig.Name == "Secret Underground Bunker", "Secret bunker display name changed")
check(bunkerConfig.Price == 2500, "Secret bunker must cost exactly $2,500")
check(bunkerConfig.ConstructionSeconds == 45, "Secret bunker construction must last exactly 45 seconds")

local highestTaskReward = 0
for _, definition in ipairs(Config.Tasks) do
	highestTaskReward = math.max(highestTaskReward, tonumber(definition.reward) or 0)
end
check(
	bunkerConfig.Price > highestTaskReward,
	"Bunker price is not meaningfully above an ordinary task reward"
)
local highestAutomationPrice = 0
for _, definition in ipairs(Config.TaskAutomationUpgrades) do
	highestAutomationPrice = math.max(highestAutomationPrice, tonumber(definition.price) or 0)
end
check(
	bunkerConfig.Price > highestAutomationPrice,
	"Bunker phase unlock must cost more than every individual chore robot"
)

local defaults = Config.ProfileDefaults
check(type(defaults) == "table" and defaults.schemaVersion == 12, "Profile defaults are not schema 12")
check(defaults.secretBunkerPurchased == false, "Fresh profiles must not own the secret bunker")
check(defaults.secretBunkerReadyAt == 0, "Fresh profiles must not begin with a bunker deadline")
check(state:GetAttribute("SchemaVersion") == 12, "Shared State does not expose schema 12")
check(
	state:GetAttribute("SupportsSecretBunkerUnlock") == true,
	"Shared State does not advertise the secret-bunker phase unlock"
)

local serverEvents = need(ServerScriptService, Config.ServerEventsName, "Folder")
need(serverEvents, "RequestBunkerConstruction", "BindableEvent")
need(serverEvents, "API", "BindableFunction")

-- Server authority, timestamp persistence, replay, and duplicate safety -----

local serverScript = need(ServerScriptService, "CooperGame", "Script")
local serverSource = sourceOf(serverScript, 12000)

for _, marker in ipairs({
	"local requestBunkerConstruction = ensureServerEvent(\"BindableEvent\", \"RequestBunkerConstruction\")",
	"local secretBunkerConfig = Config.SecretBunker",
	"secretBunkerConfig.Id == \"secretbunker.underground\"",
	"secretBunkerConfig.Name == \"Secret Underground Bunker\"",
	"tonumber(secretBunkerConfig.Price) == 2500",
	"tonumber(secretBunkerConfig.ConstructionSeconds) == 45",
	"state:SetAttribute(\"SupportsSecretBunkerUnlock\", true)",
}) do
	has(serverSource, marker, "Server foundation is missing bunker contract marker " .. marker)
end

local sanitizeSource = section(
	serverSource,
	"local function sanitizeData(raw)",
	"local function profileKey",
	"Secret-bunker profile sanitizer"
)
for _, marker in ipairs({
	"local secretBunkerPurchased = raw.secretBunkerPurchased == true",
	"finiteInteger(raw.secretBunkerReadyAt, 1, 1, 4_102_444_800)",
	"secretBunkerPurchased = secretBunkerPurchased",
	"secretBunkerReadyAt = secretBunkerReadyAt",
}) do
	has(sanitizeSource, marker, "Schema-7 bunker sanitizer is missing " .. marker)
end
ordered(sanitizeSource, {
	"local secretBunkerPurchased = raw.secretBunkerPurchased == true",
	"local secretBunkerReadyAt = secretBunkerPurchased",
	"or 0",
	"secretBunkerPurchased = secretBunkerPurchased",
	"secretBunkerReadyAt = secretBunkerReadyAt",
}, "Bunker migration must repair purchase/deadline state before returning sanitized data")
lacks(
	sanitizeSource,
	"secretBunkerPurchased = raw.secretBunkerPurchased,",
	"Sanitizer must not copy an arbitrary non-boolean purchase value"
)

local bunkerSnapshotSource = section(
	serverSource,
	"local function secretBunkerSnapshot(profile)",
	"local function syncSecretBunkerAttributes",
	"Secret-bunker snapshot"
)
for _, marker in ipairs({
	"profile.data.secretBunkerPurchased == true",
	"profile.data.secretBunkerReadyAt",
	"readyAt - unixNow()",
	"local unlocked = purchased and remaining <= 0",
	"id = secretBunkerConfig.Id",
	"name = secretBunkerConfig.Name",
	"price = finiteInteger(secretBunkerConfig.Price, 2500",
	"constructionSeconds = finiteInteger(secretBunkerConfig.ConstructionSeconds, 45",
	"purchased = purchased",
	"readyAt = readyAt",
	"remaining = remaining",
	"unlocked = unlocked",
	"status = status",
	"canOrder = profile ~= nil and profile.loaded == true and not profile.releasing and not purchased",
}) do
	has(bunkerSnapshotSource, marker, "Authoritative bunker snapshot is missing " .. marker)
end
lacks(bunkerSnapshotSource, "serverNow()", "Persistent bunker completion must use Unix time, not session time")

local playerAttributeSource = section(
	serverSource,
	"local function syncSecretBunkerAttributes(profile)",
	"-- The attributes above are the durable replay surface",
	"Secret-bunker player attributes"
)
for _, attributeName in ipairs({
	"CooperSecretBunkerId",
	"CooperSecretBunkerPurchased",
	"CooperSecretBunkerReadyAt",
	"CooperSecretBunkerUnlocked",
	"CooperSecretBunkerStatus",
}) do
	has(
		playerAttributeSource,
		"player:SetAttribute(\"" .. attributeName .. "\"",
		"Server does not publish player attribute " .. attributeName
	)
	has(
		serverSource,
		"player:SetAttribute(\"" .. attributeName .. "\", nil)",
		"Player removal does not clear " .. attributeName
	)
end

local presentationSource = section(
	serverSource,
	"local function requestSecretBunkerPresentation(profile, reason)",
	"local function taskDescription",
	"Secret-bunker presentation replay"
)
for _, marker in ipairs({
	"profile.data.secretBunkerPurchased ~= true",
	"local expectedReadyAt = finiteInteger(profile.data.secretBunkerReadyAt",
	"local requestKey = string.format(\"%d:%d\", player.UserId, expectedReadyAt)",
	"profile.data.secretBunkerReadyAt ~= expectedReadyAt",
	"requestBunkerConstruction:Fire(player, {",
	"requestKey = requestKey",
	"readyAt = bunkerState.readyAt",
	"remaining = bunkerState.remaining",
	"instant = bunkerState.unlocked",
	"resumed = reason == \"ProfileLoadedResume\"",
	"serverUnixTime = unixNow()",
	"task.delay(1.5, emit)",
	"task.delay(4.5, emit)",
}) do
	has(presentationSource, marker, "Construction replay/de-dup contract is missing " .. marker)
end
check(
	countPlain(presentationSource, "requestBunkerConstruction:Fire") == 1,
	"Presentation retries must share one guarded emit path"
)

local orderSource = section(
	serverSource,
	"local function orderSecretBunker(profile)",
	"local function orderChemistrySetup(profile)",
	"Secret-bunker purchase"
)
for _, marker in ipairs({
	"profile.data.secretBunkerPurchased == true",
	"secretBunkerConfig.Price",
	"secretBunkerConfig.ConstructionSeconds",
	"profile.data.allowance < price",
	"unixNow() + constructionSeconds",
	"SecretBunkerPurchased",
	"requestSecretBunkerPresentation(profile, \"Purchased\")",
	"task.defer(saveProfile, profile.player, false)",
}) do
	has(orderSource, marker, "Authoritative bunker purchase is missing " .. marker)
end
lacks(orderSource, "task.wait", "Atomic bunker purchase path must not yield")
ordered(orderSource, {
	"if profile.data.secretBunkerPurchased == true then",
	"profile.data.allowance < price",
	"setAllowance(profile, profile.data.allowance - price)",
	"profile.data.secretBunkerPurchased = true",
	"profile.data.secretBunkerReadyAt = finiteInteger(",
	"profile.secretBunkerCompletionAnnounced = false",
	"markDirty(profile)",
	"syncSecretBunkerAttributes(profile)",
	"feedback(profile.player, \"SecretBunkerPurchased\"",
	"broadcastState()",
	"requestSecretBunkerPresentation(profile, \"Purchased\")",
	"task.defer(saveProfile, profile.player, false)",
}, "Bunker purchase must reject duplicates, debit, persist, announce, present, and save in order")
check(
	countPlain(orderSource, "setAllowance(profile, profile.data.allowance - price)") == 1,
	"Bunker purchase contains more than one debit path"
)
check(
	countPlain(orderSource, "profile.data.secretBunkerPurchased = true") == 1,
	"Bunker purchase contains more than one entitlement mutation"
)

local completionSource = section(
	serverSource,
	"local function completeSecretBunkerIfReady(profile)",
	"local function reportPlayerAction",
	"Secret-bunker completion"
)
for _, marker in ipairs({
	"profile.data.secretBunkerPurchased ~= true",
	"profile.secretBunkerCompletionAnnounced == true",
	"local bunkerState = secretBunkerSnapshot(profile)",
	"if not bunkerState.unlocked then",
	"profile.secretBunkerCompletionAnnounced = true",
	"syncSecretBunkerAttributes(profile)",
	"feedback(profile.player, \"SecretBunkerConstructionComplete\"",
	"requestSecretBunkerPresentation(profile, \"ConstructionComplete\")",
}) do
	has(completionSource, marker, "Idempotent bunker completion is missing " .. marker)
end
ordered(completionSource, {
	"profile.secretBunkerCompletionAnnounced == true",
	"if not bunkerState.unlocked then",
	"profile.secretBunkerCompletionAnnounced = true",
	"feedback(profile.player, \"SecretBunkerConstructionComplete\"",
}, "Completion must reject duplicate/early announcements before notifying")

local apiSource = section(
	serverSource,
	"serverAPI.OnInvoke = function",
	"local function passRequestCooldown",
	"Trusted internal API"
)
ordered(apiSource, {
	"elseif operation == \"OrderSecretBunker\" then",
	"not validComputerSession(player)",
	"return orderSecretBunker(profiles[player])",
}, "Internal bunker ordering must enforce the trusted computer session")

local requestSource = section(
	serverSource,
	"requestEvent.OnServerEvent:Connect",
	"local function setupLeaderstats",
	"Remote request router"
)
ordered(requestSource, {
	"or action == \"OrderSecretBunker\"",
	"and not validComputerSession(player)",
	"elseif action == \"OrderSecretBunker\" then",
	"orderSecretBunker(profile)",
}, "Remote bunker ordering must pass through the trusted computer-session gate")
lacks(
	requestSource,
	"payload.price",
	"Client-supplied prices must never participate in bunker authorization"
)

local loadSource = section(
	serverSource,
	"local function loadPlayer(player)",
	"Players.PlayerAdded:Connect",
	"Profile load/rejoin recovery"
)
for _, marker in ipairs({
	"local loadedBunkerState = secretBunkerSnapshot(profile)",
	"profile.secretBunkerCompletionAnnounced = loadedBunkerState.unlocked",
	"syncSecretBunkerAttributes(profile)",
	"if loadedBunkerState.purchased then",
	"loadedBunkerState.unlocked and \"ProfileLoadedUnlocked\" or \"ProfileLoadedResume\"",
	"requestSecretBunkerPresentation(",
}) do
	has(loadSource, marker, "Bunker rejoin recovery is missing " .. marker)
end
has(
	serverSource,
	"completeSecretBunkerIfReady(profile)",
	"Server loop never completes a purchased bunker at its durable deadline"
)

-- Client terminal, snapshot price, affordability, and phase presentation ----

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientScript = need(starterScripts, "CooperGame", "LocalScript")
local clientSource = sourceOf(clientScript, 12000)

local noticeSource = section(
	clientSource,
	"function upgradeNoticeUi.update(snapshot)",
	"local function taskIsAutomated",
	"Affordability notification"
)
for _, marker in ipairs({
	"local secretBunker = type(snapshot.secretBunker) == \"table\" and snapshot.secretBunker or {}",
	"\"SecretBunker\"",
	"secretBunker.name or \"Secret Underground Bunker\"",
	"secretBunker.price",
	"secretBunker.purchased == true",
	"secretBunker.canOrder == true",
}) do
	has(noticeSource, marker, "Bunker affordability coverage is missing " .. marker)
end
check(
	countPlain(noticeSource, "\n\t\t\"SecretBunker\",") == 1,
	"Client must contribute exactly one bunker affordability candidate"
)
lacks(noticeSource, "Config.SecretBunker", "Affordability must use authoritative snapshot pricing")
has(clientSource, "upgradeNoticeUi.hint.Text =", "Affordability banner has no terminal guidance")
has(
	clientSource,
	"Secret Underground Bunker",
	"Client does not expose the kid-friendly bunker name"
)

local terminalSource = section(
	clientSource,
	"function renderTerminal()",
	"terminalBack.Activated:Connect",
	"Computer terminal"
)
local terminalHomeSource = section(
	terminalSource,
	"elseif terminalPage == \"Home\" then",
	"elseif terminalPage == \"Beer\" then",
	"Computer terminal home menu"
)
check(
	countPlain(terminalHomeSource, "\"Secret Underground Bunker\"") == 1,
	"Terminal home must contain exactly one kid-friendly Secret Underground Bunker option"
)
for _, marker in ipairs({
	"showPage(\"SecretBunker\")",
	"terminalPage == \"SecretBunker\"",
	"local secretBunker = type(snapshot.secretBunker) == \"table\" and snapshot.secretBunker or {}",
	"tonumber(secretBunker.price)",
	"secretBunker.unlocked == true",
	"secretBunker.purchased == true",
	"secretBunkerConstructionRemaining(snapshot)",
	"secretBunker.canOrder == true",
	"\"Buy Secret Underground Bunker — $\"",
	"requestEvent:FireServer(\"OrderSecretBunker\")",
	"treeLine(\"BUNKER READY\"",
}) do
	has(terminalSource, marker, "Secret Underground Bunker terminal page is missing " .. marker)
end
ordered(terminalSource, {
	"elseif allowance < price then",
	"elseif secretBunker.canOrder == true then",
	"requestEvent:FireServer(\"OrderSecretBunker\")",
}, "Unaffordable or blocked bunker orders must remain non-clickable")
lacks(terminalSource, "Config.SecretBunker.Price", "Terminal must not use a client-owned bunker price")

local countdownSource = section(
	clientSource,
	"local function secretBunkerConstructionRemaining(snapshot)",
	"local function boomboxStatus(snapshot)",
	"Locally derived bunker construction countdown"
)
for _, marker in ipairs({
	"secretBunker.purchased ~= true",
	"secretBunker.unlocked == true",
	"local readyAt = tonumber(secretBunker.readyAt)",
	"os.clock() - currentSnapshotReceivedAt",
	"local serverUnixTime = tonumber(snapshot.serverUnixTime)",
	"serverUnixTime + elapsed",
	"return roundedNonnegative(readyAt - currentUnixTime)",
	"tonumber(secretBunker.remaining)",
}) do
	has(countdownSource, marker, "Bunker countdown derivation is missing " .. marker)
end
ordered(countdownSource, {
	"local readyAt = tonumber(secretBunker.readyAt)",
	"os.clock() - currentSnapshotReceivedAt",
	"local serverUnixTime = tonumber(snapshot.serverUnixTime)",
	"return roundedNonnegative(readyAt - currentUnixTime)",
	"tonumber(secretBunker.remaining)",
}, "Bunker countdown must prefer the epoch deadline and only then use the relative fallback")

local bunkerTerminalPageSource = section(
	terminalSource,
	"elseif terminalPage == \"SecretBunker\" then",
	"elseif terminalPage == \"DOS\" then",
	"Secret Underground Bunker terminal page"
)
has(
	bunkerTerminalPageSource,
	"local remaining = secretBunkerConstructionRemaining(snapshot)",
	"Terminal does not display the locally advancing bunker construction deadline"
)
lacks(
	bunkerTerminalPageSource,
	"tonumber(secretBunker.remaining)",
	"Terminal directly displays a stale snapshot-relative bunker countdown"
)
lacks(
	bunkerTerminalPageSource,
	"local remaining = secretBunker.remaining",
	"Terminal bypasses the locally derived bunker construction countdown"
)

local countdownRefreshSource = section(
	clientSource,
	"local previousBunkerRemaining = nil",
	"-- The server owns formation and restoration",
	"Bunker countdown refresh loop"
)
ordered(countdownRefreshSource, {
	"local previousBunkerRemaining = nil",
	"local secretBunker = type(snapshot) == \"table\" and snapshot.secretBunker or nil",
	"local remaining = secretBunkerConstructionRemaining(snapshot)",
	"if remaining ~= previousBunkerRemaining then",
	"previousBunkerRemaining = remaining",
	"terminal.Visible and terminalPage == \"SecretBunker\"",
	"renderTerminal()",
}, "Bunker countdown must refresh the visible terminal when its displayed second changes")
check(
	countPlain(clientSource, "secretBunkerConstructionRemaining(snapshot)") >= 3,
	"Bunker countdown helper must be defined, rendered, and refreshed between snapshots"
)

for _, marker in ipairs({
	"bunkerPhaseUi.frame.Name = \"SecretBunkerPhaseBanner\"",
	"function bunkerPhaseUi.showConstruction",
	"function bunkerPhaseUi.complete",
	"GetAttributeChangedSignal(\"UnlockState\")",
	"GetAttributeChangedSignal(\"ConstructionStage\")",
	"GetAttributeChangedSignal(\"ConstructionProgress\")",
	"kind == \"SecretBunkerPurchased\"",
	"kind == \"SecretBunkerConstructionStarted\"",
	"kind == \"SecretBunkerConstructionComplete\"",
	"kind == \"SecretBunkerError\"",
	"bunkerPhaseUi.stage.Text = \"THE SECRET UNDERGROUND BUNKER IS READY TO ENTER.\"",
}) do
	has(clientSource, marker, "Client construction/completion presentation is missing " .. marker)
end

local boomboxReadyCardSource = section(
	clientSource,
	"upgradeNoticeUi.readyFrame = Instance.new(\"Frame\")",
	"-- Bunker construction uses the same prominent bottom-center notification-card",
	"BoomboxReadyNotice reference card"
)
for _, marker in ipairs({
	"upgradeNoticeUi.readyFrame.Name = \"BoomboxReadyNotice\"",
	"upgradeNoticeUi.readyFrame.AnchorPoint = Vector2.new(0.5, 1)",
	"upgradeNoticeUi.readyFrame.Position = UDim2.new(0.5, 0, 1, 35)",
	"upgradeNoticeUi.readyFrame.Size = UDim2.fromOffset(560, 100)",
	"{ Position = UDim2.new(0.5, 0, 1, -112), BackgroundTransparency = 0.02 }",
}) do
	has(boomboxReadyCardSource, marker, "BoomboxReadyNotice card contract is missing " .. marker)
end

local bunkerNotificationCardSource = section(
	clientSource,
	"-- Bunker construction uses the same prominent bottom-center notification-card",
	"task.spawn(function()",
	"Bunker bottom-center notification card"
)
for _, marker in ipairs({
	"bunkerPhaseUi.frame.Name = \"SecretBunkerPhaseBanner\"",
	"bunkerPhaseUi.frame.AnchorPoint = Vector2.new(0.5, 1)",
	"bunkerPhaseUi.frame.Position = UDim2.new(0.5, 0, 1, 35)",
	"bunkerPhaseUi.frame.Size = UDim2.fromOffset(560, 100)",
	"bunkerPhaseUi.frame.Parent = scaleRoot",
	"corner(bunkerPhaseUi.frame, 14)",
	"local targetPosition = if readyCard",
	"else UDim2.new(0.5, 0, 1, -112)",
	"{ Position = targetPosition, BackgroundTransparency = 0.02 }",
	"{ Position = UDim2.new(0.5, 0, 1, 35), BackgroundTransparency = 1 }",
}) do
	has(
		bunkerNotificationCardSource,
		marker,
		"Bunker notification does not match the BoomboxReadyNotice card format: " .. marker
	)
end
lacks(
	bunkerNotificationCardSource,
	"UDim2.fromOffset(900, 170)",
	"Bunker notification regressed to the old oversized banner"
)

local personalPhaseSource = section(
	clientSource,
	"local function playerIsWatchingOwnConstruction()",
	"-- Button-driven Cooper computer",
	"Personal construction phase banner"
)
for _, marker in ipairs({
	"player:GetAttribute(\"CooperSecretBunkerPurchased\") == true",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") ~= true",
	"player:GetAttribute(\"CooperSecretBunkerStatus\") or \"\"",
	"local function syncWorldConstruction()",
	"stateName == \"Constructing\" and playerIsWatchingOwnConstruction()",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") == true",
	"GetAttributeChangedSignal(\"CooperSecretBunkerPurchased\")",
	"GetAttributeChangedSignal(\"CooperSecretBunkerUnlocked\")",
	"GetAttributeChangedSignal(\"CooperSecretBunkerStatus\")",
}) do
	has(personalPhaseSource, marker, "Personal construction banner gating is missing " .. marker)
end
ordered(personalPhaseSource, {
	"local function playerIsWatchingOwnConstruction()",
	"player:GetAttribute(\"CooperSecretBunkerPurchased\") == true",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") ~= true",
	"local function syncWorldConstruction()",
	"stateName == \"Constructing\" and playerIsWatchingOwnConstruction()",
	"bunkerPhaseUi.showConstruction",
}, "Shared world construction may show a phase banner only for its purchasing local player")
check(
	countPlain(personalPhaseSource, "playerIsWatchingOwnConstruction()") >= 3,
	"Construction banner does not consistently re-check the local player's personal entitlement"
)

for _, forbiddenAuthority in ipairs({
	"setAllowance(",
	"AdjustCurrency",
	"secretBunkerPurchased = true",
	"secretBunkerReadyAt =",
	"RequestBunkerConstruction:Fire",
}) do
	lacks(
		clientSource,
		forbiddenAuthority,
		"Client contains forbidden bunker/economy authority: " .. forbiddenAuthority
	)
end

-- Installed construction assets and neutral template physics ---------------

local assetRoot = need(ServerStorage, "CooperBunkerConstructionAssets")
check(
	assetRoot:IsA("Folder") or assetRoot:IsA("Model"),
	"ServerStorage.CooperBunkerConstructionAssets must be a Folder or Model"
)

local assetContracts = {
	{
		name = "DumpTruck",
		minimumParts = 10,
		requiredTokens = { "Cab", "Bed" },
		countedTokens = { Wheel = 4 },
	},
	{
		name = "Excavator",
		minimumParts = 10,
		requiredTokens = { "Cab", "Boom", "Bucket" },
		countedTokens = { Track = 2 },
	},
	{
		name = "SkidSteer",
		minimumParts = 10,
		requiredTokens = { "Cab", "Bucket", "Arm" },
		countedTokens = { Wheel = 4 },
	},
	{
		name = "MobileCrane",
		minimumParts = 12,
		requiredTokens = { "Cab", "Boom", "Hook" },
		countedTokens = { Wheel = 4, Outrigger = 2 },
	},
}

local templatePartCount = 0
for _, contract in ipairs(assetContracts) do
	local asset = need(assetRoot, contract.name, "Model")
	check(asset.PrimaryPart ~= nil, contract.name .. " needs a deterministic PrimaryPart")
	local parts = baseParts(asset)
	templatePartCount += #parts
	check(
		#parts >= contract.minimumParts,
		string.format("%s is not a detailed construction asset (%d parts)", contract.name, #parts)
	)
	for _, token in ipairs(contract.requiredTokens) do
		check(
			descendantNameContains(asset, token) >= 1,
			contract.name .. " is missing detailed component " .. token
		)
	end
	for token, minimum in pairs(contract.countedTokens) do
		check(
			descendantNameContains(asset, token) >= minimum,
			string.format("%s needs at least %d %s components", contract.name, minimum, token)
		)
	end
	for _, part in ipairs(parts) do
		check(part.Anchored, part:GetFullName() .. " template part must be anchored")
		check(not part.CanCollide, part:GetFullName() .. " template part must not collide")
		check(not part.CanTouch, part:GetFullName() .. " template part must not fire touches")
		check(not part.CanQuery, part:GetFullName() .. " template part must not affect queries")
	end
end
check(templatePartCount >= 42, "The four-machine construction set is unexpectedly sparse")

local particleCount = 0
local dustCount = 0
local smokeCount = 0
for _, descendant in ipairs(assetRoot:GetDescendants()) do
	if descendant:IsA("ParticleEmitter") then
		particleCount += 1
		local lowerName = string.lower(descendant.Name)
		if string.find(lowerName, "dust", 1, true) then
			dustCount += 1
		end
		if string.find(lowerName, "smoke", 1, true)
			or string.find(lowerName, "exhaust", 1, true)
		then
			smokeCount += 1
		end
		check(not descendant.Enabled, descendant:GetFullName() .. " template emitter must start disabled")
		check(descendant.Rate <= 200, descendant:GetFullName() .. " particle rate is excessive")
		check(descendant.Lifetime.Max <= 5, descendant:GetFullName() .. " particles linger too long")
	end
end
check(particleCount >= 2, "Construction templates need both dust and smoke effects")
check(dustCount >= 1, "Construction templates are missing a dust-cloud emitter")
check(smokeCount >= 1, "Construction templates are missing machinery smoke/exhaust")

for _, part in ipairs(baseParts(assetRoot)) do
	check(part.Anchored, part:GetFullName() .. " must remain anchored in ServerStorage")
	check(not part.CanCollide, part:GetFullName() .. " must remain noncolliding in ServerStorage")
	check(not part.CanTouch, part:GetFullName() .. " must remain nontouching in ServerStorage")
	check(not part.CanQuery, part:GetFullName() .. " must remain nonquerying in ServerStorage")
end

-- Installed cover, runtime uniqueness, and live state -----------------------

local environment = need(Workspace, "CooperHouseEnvironment", "Model")
local site = need(environment, "SiteAndStreet", "Model")
local lot = need(site, "CooperLot", "BasePart")
local bunker = need(environment, "BackyardBunker", "Model")
local surface = need(bunker, "SurfaceEntrance", "Model")
local shaftOpening = need(surface, "ShaftOpening", "BasePart")
local accessGateInstance = surface:FindFirstChild("BunkerAccessGate")
if running then
	check(accessGateInstance ~= nil, "Running bunker has no personal-access throat gate")
end
if accessGateInstance then
	check(accessGateInstance:IsA("BasePart"), "SurfaceEntrance.BunkerAccessGate must be a BasePart")
	local accessGate = accessGateInstance :: BasePart
	check(accessGate.Parent == surface, "BunkerAccessGate must remain directly under SurfaceEntrance")
	check(accessGate.Anchored, "BunkerAccessGate must be anchored")
	check(accessGate.CanCollide, "BunkerAccessGate must physically stop unauthorized players")
	check(not accessGate.CanTouch, "BunkerAccessGate must not fire touch events")
	check(not accessGate.CanQuery, "BunkerAccessGate must not interfere with world queries")
	check(not accessGate.CastShadow, "Invisible BunkerAccessGate must not cast a shadow")
	check(accessGate.Transparency == 1, "BunkerAccessGate must remain fully invisible")
	check(
		accessGate:GetAttribute("BunkerAccessGate") == true,
		"BunkerAccessGate is missing its semantic attribute"
	)
	check(
		accessGate.Size.X >= shaftOpening.Size.X - 0.05
			and accessGate.Size.Z >= shaftOpening.Size.Z - 0.05,
		"BunkerAccessGate does not cover the entire shaft throat"
	)
	check(
		accessGate.Size.Y >= 0.2 and accessGate.Size.Y <= 0.75,
		"BunkerAccessGate is too thin to be reliable or too thick for clean entry"
	)
	local gateInShaft = shaftOpening.CFrame:ToObjectSpace(accessGate.CFrame)
	check(
		math.abs(gateInShaft.Position.X) <= 0.05
			and math.abs(gateInShaft.Position.Z) <= 0.05
			and gateInShaft.Position.Y <= -0.1
			and gateInShaft.Position.Y >= -0.9,
		"BunkerAccessGate is not aligned beneath ShaftOpening"
	)
end
local grassCover = findSemanticPart(bunker, "BunkerGrassCover", {
	"BunkerConstructionCover",
	"SecretBunkerGroundCover",
	"ConstructionRole",
	"RuntimeRole",
})
check(grassCover ~= nil, "BackyardBunker is missing its semantically tagged BunkerGrassCover")
check(grassCover.Anchored, "BunkerGrassCover must be anchored")
check(not grassCover.CanTouch, "BunkerGrassCover must not fire stray touch events")
check(grassCover.Material == Enum.Material.Grass, "BunkerGrassCover must look like the surrounding lawn")
check(
	grassCover.Size.X >= shaftOpening.Size.X - 0.05
		and grassCover.Size.Z >= shaftOpening.Size.Z - 0.05,
	"BunkerGrassCover does not fully support the cut shaft"
)
local coverInShaft = shaftOpening.CFrame:PointToObjectSpace(grassCover.Position)
check(
	math.abs(coverInShaft.X) <= 0.15 and math.abs(coverInShaft.Z) <= 0.15,
	"BunkerGrassCover is not centered on ShaftOpening"
)
local lotTop = lot.CFrame:PointToWorldSpace(Vector3.new(0, lot.Size.Y * 0.5, 0))
local coverTop = grassCover.CFrame:PointToWorldSpace(Vector3.new(0, grassCover.Size.Y * 0.5, 0))
check(
	math.abs(coverTop.Y - lotTop.Y) <= 0.45,
	"BunkerGrassCover is floating above or buried below the lawn"
)

local viewingAnchor = needDescendant(environment, "BunkerConstructionViewingAnchor", "BasePart")
check(viewingAnchor.Anchored, "BunkerConstructionViewingAnchor must be anchored")
check(not viewingAnchor.CanCollide, "BunkerConstructionViewingAnchor must not block the player")
check(not viewingAnchor.CanTouch, "BunkerConstructionViewingAnchor must not fire touches")
check(not viewingAnchor.CanQuery, "BunkerConstructionViewingAnchor must not affect raycasts")
check(viewingAnchor.Transparency == 1, "BunkerConstructionViewingAnchor must remain invisible")
check(
	(viewingAnchor.Position - shaftOpening.Position).Magnitude <= 40,
	"BunkerConstructionViewingAnchor is detached from the backyard work site"
)

local unlockState = bunker:GetAttribute("UnlockState")
local constructionStage = bunker:GetAttribute("ConstructionStage")
local constructionProgress = bunker:GetAttribute("ConstructionProgress")
local constructionReadyAt = bunker:GetAttribute("ConstructionReadyAt")
local constructionRequestKey = bunker:GetAttribute("ConstructionRequestKey")
local constructionControllerVersion = bunker:GetAttribute("ConstructionControllerVersion")
check(
	unlockState == "Locked" or unlockState == "Constructing" or unlockState == "Unlocked",
	"BackyardBunker.UnlockState is invalid"
)
check(type(constructionStage) == "string" and constructionStage ~= "", "ConstructionStage must be a nonempty string")
check(
	type(constructionProgress) == "number"
		and constructionProgress >= 0
		and constructionProgress <= 1,
	"ConstructionProgress must remain within 0..1"
)
check(
	type(constructionReadyAt) == "number" and constructionReadyAt >= 0,
	"ConstructionReadyAt must be a nonnegative Unix timestamp"
)
check(type(constructionRequestKey) == "string", "ConstructionRequestKey must be a string")
check(
	type(constructionControllerVersion) == "string" and constructionControllerVersion ~= "",
	"ConstructionControllerVersion must identify the installed lifecycle controller"
)
if unlockState == "Unlocked" then
	check(not grassCover.CanCollide, "Unlocked bunker still has a solid grass cover")
	check(grassCover.Transparency >= 0.95, "Unlocked bunker grass cover remains visible")
else
	check(grassCover.CanCollide, "Locked/constructing shaft has no solid grass support")
	check(grassCover.CanQuery, "Locked/constructing grass support cannot be queried")
	check(grassCover.Transparency < 0.95, "Locked/constructing grass support is invisible")
end

local runtimeRoots = {}
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if (descendant:IsA("Folder") or descendant:IsA("Model"))
		and (
			descendant.Name == "BunkerConstructionRuntime"
			or descendant:GetAttribute("BunkerConstructionRuntime") == true
			or descendant:GetAttribute("ConstructionRuntime") == true
		)
	then
		table.insert(runtimeRoots, descendant)
	end
end
check(#runtimeRoots <= 1, "More than one BunkerConstructionRuntime exists")
if unlockState == "Constructing" then
	check(#runtimeRoots == 1, "Constructing bunker has no runtime machinery root")
else
	check(#runtimeRoots == 0, "Idle/completed bunker retained a runtime machinery root")
end
if runtimeRoots[1] then
	local runtimeRoot = runtimeRoots[1]
	check(runtimeRoot:IsDescendantOf(environment), "Construction runtime left the movable Cooper environment")
	for _, contract in ipairs(assetContracts) do
		local machine = runtimeRoot:FindFirstChild(contract.name, true)
		check(machine and machine:IsA("Model"), "Runtime is missing " .. contract.name)
		check(
			(machine:GetPivot().Position - shaftOpening.Position).Magnitude <= 75,
			contract.name .. " runtime model is detached from the backyard work site"
		)
		for _, part in ipairs(baseParts(machine)) do
			check(part.Anchored, part:GetFullName() .. " runtime machinery must be anchored")
			check(not part.CanCollide, part:GetFullName() .. " runtime machinery must not collide")
			check(not part.CanTouch, part:GetFullName() .. " runtime machinery must not fire touches")
			check(not part.CanQuery, part:GetFullName() .. " runtime machinery must not affect queries")
		end
	end
end

-- Construction controller: resume-aware, local, phased, and idempotent -----

local constructionController = need(ServerScriptService, "CooperBunkerConstruction", "Script")
local constructionSource = sourceOf(constructionController, 5000)
for _, marker in ipairs({
	"CooperBunkerConstructionAssets",
	"RequestBunkerConstruction",
	"DumpTruck",
	"Excavator",
	"SkidSteer",
	"MobileCrane",
	"BunkerConstructionRuntime",
	"BunkerGrassCover",
	"ShaftOpening",
	"shaftOpening.CFrame",
	"requestKey",
	"readyAt",
	"os.time()",
	"UnlockState",
	"ConstructionStage",
	"ConstructionProgress",
	"ConstructionReadyAt",
	"ConstructionRequestKey",
	"ConstructionControllerVersion",
	"BunkerConstructionViewingAnchor",
	"Clone()",
	"Anchored = true",
	"CanCollide = false",
	"CanTouch = false",
	"CanQuery = false",
	"Destroy()",
}) do
	has(constructionSource, marker, "Construction controller is missing " .. marker)
end
for _, phaseMarker in ipairs({
	"arrival",
	"excavat",
	"crane",
	"dust",
	"reveal",
	"departure",
	"complete",
}) do
	hasLower(
		constructionSource,
		phaseMarker,
		"Construction controller lacks a distinct " .. phaseMarker .. " phase"
	)
end
check(
	countPlain(constructionSource, "SetAttribute(\"ConstructionStage\"") >= 1,
	"Construction controller does not publish phased stage updates"
)
check(
	countPlain(constructionSource, "SetAttribute(\"ConstructionProgress\"") >= 1,
	"Construction controller does not publish progress updates"
)
check(
	countPlain(constructionSource, "requestKey") >= 3,
	"Construction request de-duplication does not consistently use requestKey"
)
hasAny(constructionSource, {
	"activeRequestKey",
	"processedRequestKeys",
	"completedRequestKeys",
	"runtimeRequestKey",
}, "Construction controller has no explicit request-key idempotency registry")
hasAny(constructionSource, {
	"payload.readyAt",
	"request.readyAt",
	"metadata.readyAt",
}, "Construction controller does not consume the durable readyAt deadline")
hasAny(constructionSource, {
	"payload.resumed",
	"request.resumed",
	"metadata.resumed",
}, "Construction controller cannot distinguish a rejoin/resume request")
hasAny(constructionSource, {
	"payload.instant",
	"request.instant",
	"metadata.instant",
}, "Construction controller cannot instantly reveal an already-complete purchase")
hasLower(constructionSource, "remaining", "Construction controller is not deadline/resume aware")
hasLower(constructionSource, "instant", "Completed rejoin cannot reveal the bunker instantly")
hasLower(constructionSource, "active", "Construction controller has no active-session guard")
hasAny(constructionSource, {
	"FindFirstChild(\"BunkerConstructionRuntime\"",
	"descendant.Name == \"BunkerConstructionRuntime\"",
	"GetAttribute(\"BunkerConstructionRuntime\")",
}, "Construction controller does not discover and clear an existing runtime root")

local lowerConstructionSource = string.lower(constructionSource)
local revealAt = string.find(lowerConstructionSource, "reveal", 1, true)
local coverDisableAt = nil
for _, marker in ipairs({
	"setcoverenabled(false",
	"setcoverstate(false",
	"setcovervisible(false",
	"setgrasscover(false",
	"setcover(false",
	"grasscover.cancollide = false",
	"cover.cancollide = false",
}) do
	local found = revealAt and string.find(lowerConstructionSource, marker, revealAt, true) or nil
	if found and (not coverDisableAt or found < coverDisableAt) then
		coverDisableAt = found
	end
end
check(revealAt ~= nil, "Construction controller has no reveal phase")
check(
	coverDisableAt ~= nil and coverDisableAt > revealAt,
	"Grass cover is removed before the final reveal phase"
)
local cleanupAt = coverDisableAt and string.find(lowerConstructionSource, "destroy()", coverDisableAt, true) or nil
check(
	cleanupAt ~= nil and cleanupAt > coverDisableAt,
	"Construction runtime is not cleaned up after the cover/reveal transition"
)

lacks(
	constructionSource,
	"HumanoidRootPart.CFrame =",
	"Construction controller must not teleport a player"
)
lacks(
	constructionSource,
	"LoadCharacter",
	"Construction controller must not reset a player's character"
)
check(
	string.find(constructionSource, "shaftOpening.CFrame", 1, true) ~= nil
		and (
			string.find(constructionSource, ":PointToWorldSpace", 1, true) ~= nil
			or string.find(constructionSource, "shaftOpening.CFrame *", 1, true) ~= nil
		),
	"Construction choreography is not authored relative to the live ShaftOpening"
)

-- Existing bunker interaction and under-map controllers must honor unlock ---

local bunkerController = need(ServerScriptService, "CooperBunker", "Script")
local bunkerSource = sourceOf(bunkerController, 4000)

local accessGateSource = section(
	bunkerSource,
	"local accessGate = surface:FindFirstChild(\"BunkerAccessGate\")",
	"local blastDoor = underground:WaitForChild(\"BlastDoor\")",
	"Personal bunker access gate"
)
for _, marker in ipairs({
	"accessGate = Instance.new(\"Part\")",
	"accessGate.Name = \"BunkerAccessGate\"",
	"accessGate.Parent = surface",
	"accessGate.Anchored = true",
	"accessGate.CanCollide = true",
	"accessGate.CanTouch = false",
	"accessGate.CanQuery = false",
	"accessGate.CastShadow = false",
	"accessGate.Transparency = 1",
	"math.max(1, shaftOpening.Size.X)",
	"math.max(1, shaftOpening.Size.Z)",
	"shaftOpening.CFrame * CFrame.new(0, -0.55, 0)",
	"accessGate:SetAttribute(\"BunkerAccessGate\", true)",
}) do
	has(accessGateSource, marker, "Bunker access-gate construction is missing " .. marker)
end
ordered(accessGateSource, {
	"accessGate.Parent = surface",
	"accessGate.Anchored = true",
	"accessGate.CanCollide = true",
	"accessGate.Transparency = 1",
	"accessGate.Size = Vector3.new(",
	"shaftOpening.Size.X",
	"shaftOpening.Size.Z",
	"accessGate.CFrame = shaftOpening.CFrame",
}, "BunkerAccessGate must be a shaft-relative, invisible, solid throat barrier")

local characterAccessSource = section(
	bunkerSource,
	"local accessCharacterConnections = {}",
	"-- CFrame attributes do not move with an ancestor Model.",
	"Per-character bunker collision exemptions"
)
for _, marker in ipairs({
	"local ACCESS_CONSTRAINT_FOLDER = \"CooperBunkerAccessPass\"",
	"local function clearCharacterAccess(character)",
	"existing:Destroy()",
	"local function grantCharacterAccess(player, character)",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") ~= true",
	"local constraint = Instance.new(\"NoCollisionConstraint\")",
	"constraint.Name = \"BunkerAccessPass\"",
	"constraint.Part0 = part",
	"constraint.Part1 = accessGate",
	"constraint.Parent = folder",
	"character:GetDescendants()",
	"character.DescendantAdded:Connect(function(descendant)",
	"local function syncPlayerCharacterAccess(player)",
	"oldConnection:Disconnect()",
	"local function watchPlayerAccess(player)",
	"player.CharacterAdded:Connect(function()",
	"task.defer(syncPlayerCharacterAccess, player)",
	"player:GetAttributeChangedSignal(\"CooperSecretBunkerUnlocked\"):Connect(function()",
	"Players.PlayerAdded:Connect(watchPlayerAccess)",
	"for _, player in ipairs(Players:GetPlayers()) do",
}) do
	has(characterAccessSource, marker, "Per-character bunker access is missing " .. marker)
end
ordered(characterAccessSource, {
	"local function grantCharacterAccess(player, character)",
	"clearCharacterAccess(character)",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") ~= true",
	"return",
	"folder.Name = ACCESS_CONSTRAINT_FOLDER",
	"local constraint = Instance.new(\"NoCollisionConstraint\")",
}, "Unauthorized characters must be cleared before any gate collision exemption is created")
ordered(characterAccessSource, {
	"local function watchPlayerAccess(player)",
	"player.CharacterAdded:Connect(function()",
	"syncPlayerCharacterAccess",
	"player:GetAttributeChangedSignal(\"CooperSecretBunkerUnlocked\")",
	"syncPlayerCharacterAccess(player)",
}, "Gate exemptions must resync on both respawn and personal entitlement changes")
check(
	countPlain(characterAccessSource, "Instance.new(\"NoCollisionConstraint\")") == 1,
	"Gate exemption source should have one centralized NoCollisionConstraint creation path"
)

for _, marker in ipairs({
	"bunker:GetAttribute(\"UnlockState\") == \"Unlocked\"",
	"CooperSecretBunkerUnlocked",
	"local function playerHasBunkerAccess",
	"if not playerHasBunkerAccess(player) then",
	"hatchPrompt.Enabled = unlocked",
	"blastDoorPrompt.Enabled = unlocked",
	"lightPrompt.Enabled = unlocked",
	"if bunkerIsUnlocked() and mainLightsOn",
	"setMainLightsState(bunkerIsUnlocked())",
	"GetAttributeChangedSignal(\"UnlockState\")",
}) do
	has(bunkerSource, marker, "CooperBunker unlock gate is missing " .. marker)
end
check(
	countPlain(bunkerSource, "if not playerHasBunkerAccess(player) then") >= 4,
	"Hatch, blast door, lights, and recovery are not all entitlement-gated"
)

local recoveryTouchSource = section(
	bunkerSource,
	"recoveryZone.Touched:Connect(function(hit)",
	"Players.PlayerRemoving:Connect(function(player)",
	"RecoveryZone entitlement routing"
)
local unauthorizedRecoverySource = section(
	recoveryTouchSource,
	"if not playerHasBunkerAccess(player) then",
	"-- This fail-safe is the bunker's only character relocation.",
	"Unauthorized RecoveryZone return"
)
for _, marker in ipairs({
	"environment:FindFirstChild(\"BunkerConstructionViewingAnchor\", true)",
	"viewingAnchor.CFrame * CFrame.new(0, 3.2, 0)",
	"shaftOpening.CFrame * CFrame.new(0, 3.2, 8)",
	"root.AssemblyLinearVelocity = Vector3.zero",
	"root.AssemblyAngularVelocity = Vector3.zero",
	"currentCharacter:PivotTo(destination)",
	"Bunker access is locked to its construction authorization.",
	"return",
}) do
	has(unauthorizedRecoverySource, marker, "Unauthorized RecoveryZone handling is missing " .. marker)
end
lacks(
	unauthorizedRecoverySource,
	"recoveryAnchor.CFrame",
	"Unauthorized players are incorrectly returned to an underground recovery point"
)
ordered(unauthorizedRecoverySource, {
	"if not playerHasBunkerAccess(player) then",
	"local viewingAnchor = environment:FindFirstChild(\"BunkerConstructionViewingAnchor\", true)",
	"else shaftOpening.CFrame * CFrame.new(0, 3.2, 8)",
	"currentCharacter:PivotTo(destination)",
	"return",
}, "Unauthorized RecoveryZone contacts must return to the surface before normal underground recovery")
ordered(recoveryTouchSource, {
	"if not playerHasBunkerAccess(player) then",
	"currentCharacter:PivotTo(destination)",
	"return",
	"currentCharacter:PivotTo(recoveryAnchor.CFrame)",
}, "Only authorized players may use the underground RecoveryAnchor")

if running and accessGateInstance and accessGateInstance:IsA("BasePart") then
	local accessGate = accessGateInstance :: BasePart
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local passFolder = character:FindFirstChild("CooperBunkerAccessPass")
			if player:GetAttribute("CooperSecretBunkerUnlocked") == true then
				check(passFolder ~= nil, player.Name .. " has bunker access but no collision-exemption folder")
				check(
					passFolder:IsA("Folder"),
					player.Name .. "'s CooperBunkerAccessPass must be a Folder"
				)
				local characterParts = {}
				for _, descendant in ipairs(character:GetDescendants()) do
					if descendant:IsA("BasePart") then
						table.insert(characterParts, descendant)
					end
				end
				local constraints = {}
				for _, descendant in ipairs(passFolder:GetDescendants()) do
					check(
						descendant:IsA("NoCollisionConstraint"),
						descendant:GetFullName() .. " must be a NoCollisionConstraint"
					)
					table.insert(constraints, descendant)
				end
				check(
					#constraints == #characterParts,
					string.format(
						"%s has %d character parts but %d bunker gate exemptions",
						player.Name,
						#characterParts,
						#constraints
					)
				)
				for _, part in ipairs(characterParts) do
					local matching = 0
					for _, constraint in ipairs(constraints) do
						local otherPart = nil
						if constraint.Part0 == accessGate then
							otherPart = constraint.Part1
						elseif constraint.Part1 == accessGate then
							otherPart = constraint.Part0
						end
						if otherPart == part then
							matching += 1
						end
					end
					check(
						matching == 1,
						part:GetFullName() .. " needs exactly one personal BunkerAccessGate exemption"
					)
				end
			else
				check(
					passFolder == nil,
					player.Name .. " is unauthorized but retained a CooperBunkerAccessPass"
				)
			end
		end
	end
end

local spawnSafety = need(ServerScriptService, "CooperSpawnSafety", "Script")
local spawnSource = sourceOf(spawnSafety, 1500)
for _, marker in ipairs({
	"insideLegitimateBunkerSpace(player: Player",
	"bunker:GetAttribute(\"UnlockState\") ~= \"Unlocked\"",
	"player:GetAttribute(\"CooperSecretBunkerUnlocked\") ~= true",
	"not insideLegitimateBunkerSpace(player, root.Position)",
}) do
	has(spawnSource, marker, "Spawn safety bunker gate is missing " .. marker)
end

print(string.format(
	"[SecretBunkerAudit] PASS: %d checks, schema 12, $%d unlock, %ds construction, %d neutral template parts",
	checks,
	bunkerConfig.Price,
	bunkerConfig.ConstructionSeconds,
	templatePartCount
))
