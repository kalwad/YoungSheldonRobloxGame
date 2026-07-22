local TweenService = game:GetService("TweenService")

local screen = workspace
	:WaitForChild("CooperHouseEnvironment")
	:WaitForChild("CooperHouse")
	:WaitForChild("FurnitureAndProps")
	:WaitForChild("WoodCabinetCRTTelevision")
	:WaitForChild("CurvedGlassScreen")

local surface = screen:WaitForChild("CooperTVBroadcast")
local program = surface:WaitForChild("Program")
local safeArea = program:WaitForChild("SafeArea")
local title = safeArea:WaitForChild("ProgramTitle")
local subtitle = safeArea:WaitForChild("ProgramSubtitle")
local liveBug = safeArea:WaitForChild("LiveBug")
local character = safeArea:WaitForChild("ProfessorNeutron")
local ticker = program:WaitForChild("Ticker")
local static = program:WaitForChild("StaticOverlay")

local programs = {
	{
		background = Color3.fromRGB(35, 73, 62),
		title = "PROF. NEUTRON'S SCIENCE HOUR",
		subtitle = [[TONIGHT:
CAN A TRAIN OUTRUN A TORNADO?]],
		ticker = "CHANNEL 8 • SCIENCE • TRAINS • MEDFORD • PLEASE STAND BY",
		live = "LIVE • MEDFORD 1989",
	},
	{
		background = Color3.fromRGB(105, 37, 34),
		title = "MEDFORD EMERGENCY BROADCAST",
		subtitle = [[WHERE IS
GEORGE'S BEVERAGE?]],
		ticker = "PANIC LEVEL: YELLOW • BRISKET STATUS: UNCONFIRMED",
		live = "ALERT • COOPER HOUSE",
	},
	{
		background = Color3.fromRGB(57, 75, 112),
		title = "TEXAS WEATHER CENTER",
		subtitle = [[FORECAST:
100% CHANCE OF BRISKET]],
		ticker = "HOT • HUMID • POSSIBLE COWS • DO NOT ARGUE WITH MEEMAW",
		live = "WEATHER • CHANNEL 8",
	},
	{
		background = Color3.fromRGB(78, 67, 37),
		title = "MEDFORD RAIL REPORT",
		subtitle = [[THE 7:13 IS ON TIME.
OBVIOUSLY.]],
		ticker = "GALVESTON → HOUSTON → MEDFORD • ALL ABOARD",
		live = "RAIL DESK • 07:13",
	},
}

local defaultPosition = character.Position
local index = 1
while true do
	local entry = programs[index]
	program.BackgroundColor3 = entry.background
	title.Text = entry.title
	subtitle.Text = entry.subtitle
	ticker.Text = entry.ticker
	liveBug.Text = entry.live

	static.BackgroundTransparency = 0.93
	for _, line in ipairs(static:GetChildren()) do
		if line:IsA("Frame") then
			line.BackgroundTransparency = math.random(45, 88) / 100
		end
	end

	character.Position = defaultPosition + UDim2.fromOffset(-10, 3)
	character.Rotation = -2
	local tween = TweenService:Create(
		character,
		TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = defaultPosition, Rotation = 1.5}
	)
	tween:Play()

	task.wait(4.7)
	for flash = 1, 3 do
		static.BackgroundTransparency = flash % 2 == 0 and 0.88 or 0.97
		task.wait(0.07)
	end
	static.BackgroundTransparency = 1

	index = index % #programs + 1
end
