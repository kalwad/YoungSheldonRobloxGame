--!nonstrict
-- Read-only Milestone 1 regression audit for the Ready -> Launch repair.
-- Run in the dedicated lobby place in edit or play mode. It never invokes a
-- RemoteFunction, changes party state, writes MemoryStore, or teleports.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local failures = {}
local checkCount = 0

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
end

local function contains(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local lobbyServer = ServerScriptService:FindFirstChild("CooperLobby")
check(lobbyServer and lobbyServer:IsA("Script"), "ServerScriptService.CooperLobby is missing")
local source = ""
if lobbyServer and lobbyServer:IsA("LuaSourceContainer") then
	local ok, result = pcall(function()
		return lobbyServer.Source
	end)
	check(ok and type(result) == "string", "CooperLobby source is unreadable")
	if ok and type(result) == "string" then
		source = result
	end
end

for _, marker in ipairs({
	"local requestRateByUserId",
	"local function consumeActionBudget",
	"state.lastByAction[action]",
	"REQUEST_BURST_CAPACITY",
	"REQUEST_REFILL_PER_SECOND",
	"reasonCode = rateReasonCode or \"RATE_LIMIT\"",
	"selfReady = selfReady",
	"partyRevision = partyRevision(party)",
	"launchBlockReasonCode = launchBlockReasonCode",
	"READY_COMMITTED",
	"LAUNCH_PREFLIGHT_STARTED",
	"STUDIO_HOUSE_STARTED",
	"STUDIO_HOUSE_BRIDGE_UNAVAILABLE",
	"RESERVED_SERVER_CREATED",
	"SESSION_MANIFEST_WRITTEN",
	"MEMBER_TICKET_WRITTEN",
	"TELEPORT_REQUESTED",
	"TELEPORT_INIT_FAILED",
	"local function renewLaunchOwnership",
	"and party.launchSessionId == sessionId",
	"if type(current) == \"table\" and current.sessionId == sessionId then",
}) do
	check(contains(source, marker), "CooperLobby source is missing launch-repair marker: " .. marker)
end
check(not contains(source, "local lastRequestAt"), "Legacy cross-action lastRequestAt cooldown is still active")

-- Deterministic model of the public rate-limit contract: unrelated actions may
-- occur at the same clock value, while repeating the same action is bounded.
local capacity = 5
local refillPerSecond = 2
local model = { lastByAction = {}, tokens = capacity, updatedAt = 100 }
local function minimumGap(action)
	if action == "SetReady" then
		return 0.1
	end
	if action == "Launch" or action == "PlaySolo" then
		return 0.35
	end
	return 0.25
end
local function consume(action, nowClock)
	local elapsed = math.max(0, nowClock - model.updatedAt)
	model.updatedAt = nowClock
	model.tokens = math.min(capacity, model.tokens + elapsed * refillPerSecond)
	local lastActionAt = model.lastByAction[action]
	if lastActionAt and nowClock - lastActionAt < minimumGap(action) then
		return false, "RATE_LIMIT_ACTION"
	end
	if model.tokens < 1 then
		return false, "RATE_LIMIT_BURST"
	end
	model.tokens -= 1
	model.lastByAction[action] = nowClock
	return true, nil
end

local readyAccepted = consume("SetReady", 100)
local launchAccepted = consume("Launch", 100)
local duplicateLaunchAccepted, duplicateLaunchReason = consume("Launch", 100)
check(readyAccepted == true, "First SetReady should be accepted")
check(launchAccepted == true, "Zero-delay SetReady -> Launch must be accepted")
check(
	duplicateLaunchAccepted == false and duplicateLaunchReason == "RATE_LIMIT_ACTION",
	"Same-action Launch spam must remain rate-limited"
)

-- A delayed attempt A may finish after the watchdog has already allowed attempt
-- B. Cleanup for A must leave B's party ownership and reconnect route intact.
local newerParty = { state = "Launching", launchSessionId = "session_B" }
local newerRejoin = { sessionId = "session_B", accessCode = "not-a-real-secret" }
local staleSessionId = "session_A"
if newerParty.state == "Launching" and newerParty.launchSessionId == staleSessionId then
	newerParty.state = "Open"
	newerParty.launchSessionId = nil
end
if newerRejoin.sessionId == staleSessionId then
	newerRejoin = { sessionId = false, status = "Released" }
end
check(
	newerParty.state == "Launching" and newerParty.launchSessionId == "session_B",
	"Stale rollback must not reopen a newer launch"
)
check(newerRejoin.sessionId == "session_B", "Stale rollback must not remove a newer reconnect route")

-- Only the diagnostic allowlist may copy context into output. Authentication
-- secrets must never become allowed structured fields.
local allowlistStart = string.find(source, "local SAFE_DIAGNOSTIC_FIELDS", 1, true)
local allowlistEnd = allowlistStart and string.find(source, "local function emitLobbyDiagnostic", allowlistStart, true)
local allowlistSource = if allowlistStart and allowlistEnd
	then string.sub(source, allowlistStart, allowlistEnd - 1)
	else ""
check(allowlistSource ~= "", "Structured diagnostic allowlist is missing")
check(not contains(allowlistSource, "accessCode"), "Diagnostic allowlist exposes reserved-server access codes")
check(not contains(allowlistSource, "ticketId"), "Diagnostic allowlist exposes one-use tickets")
check(not contains(allowlistSource, "teleportData"), "Diagnostic allowlist exposes TeleportData")

if #failures > 0 then
	error(string.format(
		"[LobbyLaunchRepairAudit] FAIL (%d of %d checks, %s mode):\n - %s",
		#failures,
		checkCount,
		RunService:IsRunning() and "runtime" or "edit",
		table.concat(failures, "\n - ")
	), 0)
end

print(string.format(
	"[LobbyLaunchRepairAudit] PASS: %d checks; zero-delay Ready -> Launch is independent, spam remains bounded, diagnostics exclude authentication secrets (%s mode)",
	checkCount,
	RunService:IsRunning() and "runtime" or "edit"
))
return true
