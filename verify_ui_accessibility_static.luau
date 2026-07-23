--!nonstrict
-- Read-only UI accessibility and structure audit for the active Cooper lobby
-- or house authoring surface.
--
-- This verifier never creates, destroys, reparents, enables, invokes, focuses,
-- or edits an Instance. Run it in edit mode for source contracts, or from the
-- CLIENT Command Bar during Play to add inspection of locally created
-- PlayerGui instances. A server-side Play run cannot see client-owned GUI
-- instances and is reported as source/runtime-server evidence only.
--
-- PASS means that objective accessibility contracts inspected here are
-- present. It is not evidence of visual aesthetics, physical-device behavior,
-- touch feel, localization, or published-client behavior.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local failures = {}
local advisories = {}
local checkCount = 0
local sourceProducerCount = 0
local runtimeGuiCount = 0

local function check(condition, message)
	checkCount += 1
	if not condition then
		table.insert(failures, message)
	end
	return condition
end

local function advise(message)
	table.insert(advisories, message)
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

local function markers(source, label, expected)
	for _, marker in ipairs(expected) do
		check(contains(source, marker), label .. " is missing accessibility marker: " .. marker)
	end
end

local function sourceOf(instance, label)
	check(instance and instance:IsA("LuaSourceContainer"), label .. " source container is missing")
	if not instance or not instance:IsA("LuaSourceContainer") then
		return nil
	end
	local ok, result = pcall(function()
		return instance.Source
	end)
	check(ok and type(result) == "string" and #result > 100, label .. " source is unreadable")
	return if ok and type(result) == "string" then result else nil
end

local function linearChannel(channel)
	if channel <= 0.04045 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

local function relativeLuminance(color)
	return 0.2126 * linearChannel(color.R)
		+ 0.7152 * linearChannel(color.G)
		+ 0.0722 * linearChannel(color.B)
end

local function contrastRatio(foreground, background)
	local foregroundLuminance = relativeLuminance(foreground)
	local backgroundLuminance = relativeLuminance(background)
	local lighter = math.max(foregroundLuminance, backgroundLuminance)
	local darker = math.min(foregroundLuminance, backgroundLuminance)
	return (lighter + 0.05) / (darker + 0.05)
end

local themeModule = ReplicatedStorage:FindFirstChild("CooperUITheme")
check(themeModule and themeModule:IsA("ModuleScript"), "ReplicatedStorage.CooperUITheme is missing")
local theme = nil
if themeModule and themeModule:IsA("ModuleScript") then
	local ok, result = pcall(require, themeModule)
	check(ok and type(result) == "table", "CooperUITheme could not be read")
	if ok and type(result) == "table" then
		theme = result
	end
end

local minimumTouchTarget = 56
if theme then
	check(theme.VERSION == 1, "CooperUITheme version must remain 1")
	check(type(theme.Metrics) == "table", "CooperUITheme.Metrics is missing")
	check(type(theme.Accessibility) == "table", "CooperUITheme.Accessibility is missing")
	check(type(theme.Colors) == "table", "CooperUITheme.Colors is missing")

	local metrics = type(theme.Metrics) == "table" and theme.Metrics or {}
	local accessibility = type(theme.Accessibility) == "table" and theme.Accessibility or {}
	local colors = type(theme.Colors) == "table" and theme.Colors or {}
	minimumTouchTarget = tonumber(metrics.MinimumTouchTarget) or 0
	local actionHeight = tonumber(metrics.ActionHeight) or 0
	local bodyContrastMinimum = tonumber(accessibility.BodyTextContrastMinimum) or math.huge

	check(minimumTouchTarget >= 44, "CooperUITheme minimum touch target is below 44 pixels")
	check(actionHeight >= minimumTouchTarget, "CooperUITheme action height is below its touch-target minimum")
	check(
		accessibility.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets,
		"CooperUITheme must use CoreUISafeInsets"
	)
	check(accessibility.ClipToDeviceSafeArea == true, "CooperUITheme must clip to the device safe area")
	check(accessibility.BodyTextContrastMinimum == 4.5, "Body-text contrast contract must be 4.5:1")
	check(accessibility.LargeTextContrastMinimum == 3, "Large-text contrast contract must be 3:1")

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
		check(
			typeof(foreground) == "Color3" and typeof(background) == "Color3",
			"CooperUITheme contrast pair is missing: " .. pair[1] .. "/" .. pair[2]
		)
		if typeof(foreground) == "Color3" and typeof(background) == "Color3" then
			check(
				contrastRatio(foreground, background) >= bodyContrastMinimum,
				"CooperUITheme contrast is below 4.5:1 for " .. pair[1] .. "/" .. pair[2]
			)
		end
	end
end

local producerSpecs = {
	CooperLobby = {
		guiName = "CooperLobbyUI",
		contexts = { "lobby" },
		markers = {
			'gui.Name = "CooperLobbyUI"',
			"gui.ScreenInsets = UITheme.Accessibility.ScreenInsets",
			"gui.ClipToDeviceSafeArea = UITheme.Accessibility.ClipToDeviceSafeArea",
			'local content = Instance.new("ScrollingFrame")',
			"content.AutomaticCanvasSize = Enum.AutomaticSize.Y",
			"button.Size = UDim2.new(1, 0, 0, UITheme.Metrics.ActionHeight)",
			"button.NextSelectionDown",
			"SelectionGained",
			"local function launchReason",
			"launchStatus.Text = reason",
		},
	},
	CooperGame = {
		guiName = "CooperGameHUD",
		contexts = { "houseTerminal", "bank", "notifications" },
		markers = {
			'gui.Name = "CooperGameHUD"',
			"gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
			"gui.ClipToDeviceSafeArea = true",
			'terminal.Name = "CooperComputer"',
			'button(terminal, "Close"',
			'button(terminal, "Back"',
			"terminalClose.Activated",
			"terminalBack.Activated",
			'terminalButtons.Name = "TreeList"',
			"terminalButtons.AutomaticCanvasSize = Enum.AutomaticSize.Y",
			'bankPanel.Name = "MedfordBankLink"',
			"bankStartButton.Selectable = enabled",
			'"NO BANK TASK AVAILABLE"',
			'upgradeNoticeUi.frame.Name = "UpgradeAffordableNotice"',
			'upgradeNoticeUi.readyFrame.Name = "BoomboxReadyNotice"',
			'bunkerPhaseUi.frame.Name = "SecretBunkerPhaseBanner"',
			"SelectionGained",
			"GuiService.SelectedObject",
			"IsDescendantOf",
		},
	},
	CooperBunkerClient = {
		guiName = "CooperBunkerNoticeGui",
		contexts = { "bunkerTerminal", "notifications" },
		markers = {
			'gui.Name = "CooperBunkerNoticeGui"',
			"gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
			"gui.ClipToDeviceSafeArea = true",
			'shade.Name = "ResearchTerminalShade"',
			'panel.Name = "ResearchTerminal"',
			'local closeButton = button(',
			'"Close",',
			'"Exit",',
			'local backButton = button(',
			"closeButton.Activated",
			"backButton.Activated",
			'actionList.Name = "Actions"',
			"actionList.AutomaticCanvasSize = Enum.AutomaticSize.Y",
			"row.Selectable = enabled ~= false",
			'rowDetail = label(row, "Detail", detailText',
			"GuiService.SelectedObject",
			"IsDescendantOf",
		},
	},
	CooperInteractions = {
		guiName = "CooperInteractionsGui",
		contexts = { "interactionTerminal", "cube", "held" },
		markers = {
			'gui.Name = "CooperInteractionsGui"',
			"gui.ScreenInsets = touchDevice and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.DeviceSafeInsets",
			"gui.ClipToDeviceSafeArea = true",
			'heldPanel.Name = "HeldPanel"',
			'terminal.Name = "Terminal"',
			'local terminalClose = makeButton(terminal, "Close"',
			"terminalClose.Activated",
			'terminalOutput.Name = "Output"',
			"terminalOutput.AutomaticCanvasSize = Enum.AutomaticSize.Y",
			'cubeWindow.Name = "PuzzleCube"',
			'cubeClose = makeButton(cubeWindow, "Close"',
			"cubeClose.Activated",
			"GuiService.SelectedObject",
			"IsDescendantOf",
		},
	},
	CooperFamilyDialogue = {
		guiName = "CooperFamilyDialogueUI",
		contexts = { "dialogue" },
		markers = {
			'gui.Name = "CooperFamilyDialogueUI"',
			"gui.ClipToDeviceSafeArea = true",
			"gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
			'closeButton.Name = "Close"',
			"closeButton.Activated",
			"choiceButton.Selectable = true",
			"GuiService.SelectedObject",
			"IsDescendantOf",
		},
	},
	CooperSprint = {
		guiName = "CooperSprintHUD",
		contexts = { "sprint" },
		markers = {
			'gui.Name = "CooperSprintHUD"',
			"gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
			"gui.ClipToDeviceSafeArea = true",
			'ContextActionService:SetTitle(ACTION_NAME, "SPRINT")',
			"button.Size = UDim2.fromOffset(TOUCH_BUTTON_SIZE, TOUCH_BUTTON_SIZE)",
			'"SPRINT EXHAUSTED',
			'"SPRINT RECOVERING',
			"GuiService.SelectedObject",
			"IsDescendantOf",
		},
	},
	CooperYardRideables = {
		guiName = "CooperRideableHints",
		contexts = { "rideableHints" },
		markers = {
			'hintGui.Name = "CooperRideableHints"',
			"hintGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
			"hintGui.ClipToDeviceSafeArea = true",
			"local TOUCH_BUTTON_SIZE = 56",
			"button.Size = UDim2.fromOffset(TOUCH_BUTTON_SIZE, TOUCH_BUTTON_SIZE)",
			"ContextActionService:SetTitle",
		},
	},
}

local roots = {}
local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if starterScripts then
	table.insert(roots, { instance = starterScripts, label = "StarterPlayerScripts", active = true })
end
table.insert(roots, { instance = StarterGui, label = "StarterGui", active = true })

local localPlayer = if RunService:IsRunning() and RunService:IsClient() then Players.LocalPlayer else nil
if localPlayer then
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	if playerScripts then
		table.insert(roots, { instance = playerScripts, label = "LocalPlayer.PlayerScripts", active = true })
	end
end

local previewPlayerScripts = ReplicatedStorage:FindFirstChild("CooperStudioPlayerScripts")
if previewPlayerScripts and previewPlayerScripts:IsA("Folder") then
	table.insert(roots, {
		instance = previewPlayerScripts,
		label = "ReplicatedStorage.CooperStudioPlayerScripts (inert source reference)",
		active = false,
	})
end

local sourceInventory = {}
for _, rootDefinition in ipairs(roots) do
	for _, descendant in ipairs(rootDefinition.instance:GetDescendants()) do
		if descendant:IsA("LocalScript") and (not rootDefinition.active or descendant.Enabled) then
			local ok, source = pcall(function()
				return descendant.Source
			end)
			if ok and type(source) == "string" and contains(source, 'Instance.new("ScreenGui")') then
				local existing = sourceInventory[descendant.Name]
				if not existing or (rootDefinition.active and not existing.active) then
					sourceInventory[descendant.Name] = {
						instance = descendant,
						source = source,
						label = rootDefinition.label .. "." .. descendant.Name,
						active = rootDefinition.active,
					}
				end
			end
		end
	end
end

for producerName, definition in pairs(sourceInventory) do
	sourceProducerCount += 1
	local spec = producerSpecs[producerName]
	check(spec ~= nil, "Uninventoried ScreenGui-producing LocalScript: " .. definition.label)
	if spec then
		check(
			contains(definition.source, 'Instance.new("ScreenGui")'),
			definition.label .. " no longer constructs a ScreenGui"
		)
		check(
			contains(definition.source, "ScreenInsets"),
			definition.label .. " does not declare a safe-area ScreenInsets policy"
		)
		check(
			contains(definition.source, "ClipToDeviceSafeArea"),
			definition.label .. " does not declare ClipToDeviceSafeArea"
		)
		markers(definition.source, definition.label, spec.markers)

		local scaledTextCount = countPlain(definition.source, "TextScaled = true")
		local textConstraintCount = countPlain(definition.source, 'Instance.new("UITextSizeConstraint")')
		check(
			textConstraintCount >= scaledTextCount,
			definition.label .. " creates TextScaled text without enough UITextSizeConstraint declarations"
		)

		if contains(definition.source, "GuiService.SelectedObject =") then
			check(
				contains(definition.source, "IsDescendantOf"),
				definition.label .. " writes GuiService.SelectedObject without descendant-scoped cleanup"
			)
			check(
				contains(definition.source, "GuiService.SelectedObject = nil"),
				definition.label .. " writes GuiService.SelectedObject without clearing owned selection"
			)
		end
	end
end
check(sourceProducerCount > 0, "No active or role-relevant ScreenGui-producing client sources were inventoried")

local houseRole = ReplicatedStorage:FindFirstChild("CooperGame") ~= nil
	and Workspace:FindFirstChild("CooperHouseEnvironment") ~= nil
local lobbyRole = not houseRole and ReplicatedStorage:FindFirstChild("CooperLobby") ~= nil
check(houseRole or lobbyRole, "Could not identify an active Cooper house or lobby role")

local expectedProducerNames = if houseRole
	then {
		"CooperGame",
		"CooperBunkerClient",
		"CooperInteractions",
		"CooperFamilyDialogue",
		"CooperSprint",
		"CooperYardRideables",
	}
	else { "CooperLobby" }

for _, producerName in ipairs(expectedProducerNames) do
	local definition = sourceInventory[producerName]
	check(definition ~= nil, "Expected ScreenGui producer source is missing for active role: " .. producerName)
	if definition then
		local source = sourceOf(definition.instance, definition.label)
		local spec = producerSpecs[producerName]
		check(source ~= nil and contains(source, spec.guiName), producerName .. " does not declare " .. spec.guiName)
	end
end

local contextCoverage = {}
for producerName, definition in pairs(sourceInventory) do
	local spec = producerSpecs[producerName]
	if spec then
		for _, contextName in ipairs(spec.contexts) do
			contextCoverage[contextName] = true
		end
	end
end
for _, contextName in ipairs({
	"lobby",
	"houseTerminal",
	"bank",
	"bunkerTerminal",
	"interactionTerminal",
	"cube",
	"held",
	"dialogue",
	"sprint",
	"notifications",
}) do
	local requiredForRole = contextName == "lobby" and lobbyRole
		or (contextName ~= "lobby" and houseRole)
	if requiredForRole then
		check(contextCoverage[contextName] == true, "UI audit context is not covered: " .. contextName)
	end
end

local lobbySource = sourceInventory.CooperLobby and sourceInventory.CooperLobby.source or nil
if lobbySource then
	check(
		not contains(lobbySource, "GuiService.SelectedObject"),
		"CooperLobby must not force global GuiService.SelectedObject during initialization"
	)
end

local sprintSource = sourceInventory.CooperSprint and sourceInventory.CooperSprint.source or nil
if sprintSource then
	local touchTarget = tonumber(string.match(sprintSource, "local TOUCH_BUTTON_SIZE = (%d+)"))
	check(
		touchTarget ~= nil and touchTarget >= minimumTouchTarget,
		"CooperSprint touch target is smaller than the shared minimum"
	)
end

local rideableSource = sourceInventory.CooperYardRideables
		and sourceInventory.CooperYardRideables.source
	or nil
if rideableSource then
	local touchTarget = tonumber(string.match(rideableSource, "local TOUCH_BUTTON_SIZE = (%d+)"))
	check(
		touchTarget ~= nil and touchTarget >= minimumTouchTarget,
		"CooperYardRideables touch target is smaller than the shared minimum"
	)
end

local runtimeGuiByName = {}
local function collectRuntimeGuis(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ScreenGui") and string.sub(descendant.Name, 1, 6) == "Cooper" then
			runtimeGuiByName[descendant.Name] = descendant
		end
	end
end

if RunService:IsRunning() and RunService:IsClient() and localPlayer then
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	check(playerGui ~= nil, "LocalPlayer.PlayerGui is missing during client runtime")
	if playerGui then
		collectRuntimeGuis(playerGui)
	end
elseif RunService:IsRunning() then
	advise("Runtime is server-side; client-owned PlayerGui instances were not inspectable.")
else
	collectRuntimeGuis(StarterGui)
	advise("Edit-mode run: source and installed StarterGui structure were audited; dynamic PlayerGui instances were not expected.")
end

local allowedScreenInsets = {
	[Enum.ScreenInsets.CoreUISafeInsets] = true,
	[Enum.ScreenInsets.DeviceSafeInsets] = true,
}

local function nonzeroCanvasSize(value)
	return value.X.Scale ~= 0 or value.X.Offset ~= 0 or value.Y.Scale ~= 0 or value.Y.Offset ~= 0
end

local function isEffectivelyVisible(guiObject)
	local current = guiObject
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

local function auditRuntimeGui(screenGui, producerName)
	runtimeGuiCount += 1
	check(screenGui.ClipToDeviceSafeArea == true, screenGui.Name .. " does not clip to the device safe area")
	local ok, screenInsets = pcall(function()
		return screenGui.ScreenInsets
	end)
	check(ok and allowedScreenInsets[screenInsets] == true, screenGui.Name .. " has an unsupported ScreenInsets policy")

	for _, descendant in ipairs(screenGui:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			if descendant.TextScaled then
				check(
					descendant:FindFirstChildOfClass("UITextSizeConstraint") ~= nil,
					descendant:GetFullName() .. " uses TextScaled without UITextSizeConstraint"
				)
			end
		elseif descendant:IsA("ScrollingFrame") then
			check(
				descendant.AutomaticCanvasSize ~= Enum.AutomaticSize.None
					or nonzeroCanvasSize(descendant.CanvasSize),
				descendant:GetFullName() .. " has neither automatic nor explicit scrolling canvas"
			)
		end
	end

	if producerName == "CooperLobby" then
		local actions = screenGui:FindFirstChild("Actions", true)
		check(actions and actions:IsA("GuiObject"), "CooperLobbyUI.Actions is missing")
		if actions then
			for _, child in ipairs(actions:GetChildren()) do
				if child:IsA("TextButton") then
					check(
						child.Size.Y.Offset >= minimumTouchTarget,
						child:GetFullName() .. " is shorter than the shared touch-target minimum"
					)
					check(
						child:FindFirstChild("FocusStroke") ~= nil,
						child:GetFullName() .. " has no visible focus-stroke object"
					)
				end
			end
			local launch = actions:FindFirstChild("Launch")
			local launchStatus = actions:FindFirstChild("LaunchStatus")
			if launch and launch:IsA("TextButton") and launch.Visible and not launch.Active then
				check(
					launchStatus
						and launchStatus:IsA("TextLabel")
						and launchStatus.Text ~= "",
					"Disabled lobby Launch has no plain-language reason"
				)
			end
		end
	elseif producerName == "CooperGame" then
		local terminal = screenGui:FindFirstChild("CooperComputer", true)
		check(terminal ~= nil, "CooperGameHUD.CooperComputer is missing")
		if terminal then
			check(terminal:FindFirstChild("Close", true) ~= nil, "House terminal has no Close control")
			check(terminal:FindFirstChild("Back", true) ~= nil, "House terminal has no Back control")
			check(terminal:FindFirstChild("MedfordBankLink", true) ~= nil, "House terminal bank panel is missing")
		end
		for _, notificationName in ipairs({
			"UpgradeAffordableNotice",
			"BoomboxReadyNotice",
			"SecretBunkerPhaseBanner",
		}) do
			check(
				screenGui:FindFirstChild(notificationName, true) ~= nil,
				"CooperGameHUD notification surface is missing " .. notificationName
			)
		end
	elseif producerName == "CooperBunkerClient" then
		local terminal = screenGui:FindFirstChild("ResearchTerminal", true)
		check(terminal ~= nil, "Bunker research terminal is missing")
		if terminal then
			local close = terminal:FindFirstChild("Close", true)
			check(close and close:IsA("TextButton"), "Bunker terminal has no Exit/Close button")
			if close and close:IsA("TextButton") then
				check(
					close.Text == "Exit" or close.Text == "Close",
					"Bunker terminal Exit/Close button has an unclear label"
				)
			end
			check(terminal:FindFirstChild("Back", true) ~= nil, "Bunker terminal has no Back control")
			local actions = terminal:FindFirstChild("Actions", true)
			if actions then
				for _, action in ipairs(actions:GetChildren()) do
					if action:IsA("TextButton") and not action.Active then
						local detail = action:FindFirstChild("Detail")
						check(
							detail and detail:IsA("TextLabel") and detail.Text ~= "",
							"Disabled bunker action has no explanatory detail"
						)
					end
				end
			end
		end
	elseif producerName == "CooperInteractions" then
		local terminal = screenGui:FindFirstChild("Terminal", true)
		local cube = screenGui:FindFirstChild("PuzzleCube", true)
		local held = screenGui:FindFirstChild("HeldPanel", true)
		check(terminal ~= nil, "Interaction terminal is missing")
		check(cube ~= nil, "Cube UI is missing")
		check(held ~= nil, "Held-item UI is missing")
		if terminal then
			check(terminal:FindFirstChild("Close", true) ~= nil, "Interaction terminal has no Close control")
		end
		if cube then
			check(cube:FindFirstChild("Close", true) ~= nil, "Cube UI has no Close control")
		end
	elseif producerName == "CooperFamilyDialogue" then
		local panel = screenGui:FindFirstChild("DialoguePanel", true)
		check(panel ~= nil, "Dialogue panel is missing")
		if panel then
			check(panel:FindFirstChild("Close", true) ~= nil, "Dialogue modal has no Close control")
		end
	elseif producerName == "CooperSprint" then
		check(screenGui:FindFirstChild("StaminaCard", true) ~= nil, "Sprint status card is missing")
	elseif producerName == "CooperYardRideables" then
		check(screenGui:FindFirstChild("RideHint", true) ~= nil, "Rideable instruction text is missing")
	end
end

if RunService:IsRunning() and RunService:IsClient() then
	for _, producerName in ipairs(expectedProducerNames) do
		local spec = producerSpecs[producerName]
		local runtimeGui = spec and runtimeGuiByName[spec.guiName] or nil
		check(runtimeGui ~= nil, "Expected runtime ScreenGui is missing: " .. (spec and spec.guiName or producerName))
		if runtimeGui then
			auditRuntimeGui(runtimeGui, producerName)
		end
	end

	local selected = GuiService.SelectedObject
	if selected ~= nil then
		check(selected.Parent ~= nil, "GuiService.SelectedObject points to a destroyed object")
		local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
		check(
			playerGui ~= nil and selected:IsDescendantOf(playerGui),
			"GuiService.SelectedObject points outside LocalPlayer.PlayerGui"
		)
		check(isEffectivelyVisible(selected), "GuiService.SelectedObject points into a hidden GUI branch")
		check(selected.Selectable, "GuiService.SelectedObject points to a non-selectable GuiObject")
	end
end

for _, message in ipairs(advisories) do
	print("[UIAccessibilityStaticAudit] NOTE: " .. message)
end

if #failures > 0 then
	error(
		string.format(
			"[UIAccessibilityStaticAudit] FAIL (%d of %d checks; %d source producers, %d runtime GUIs):\n - %s",
			#failures,
			checkCount,
			sourceProducerCount,
			runtimeGuiCount,
			table.concat(failures, "\n - ")
		),
		0
	)
end

print(string.format(
	"[UIAccessibilityStaticAudit] PASS: %d objective checks; inventoried %d ScreenGui-producing sources and %d inspectable runtime GUIs. No claim is made about aesthetics, physical hardware, touch feel, or published behavior.",
	checkCount,
	sourceProducerCount,
	runtimeGuiCount
))
