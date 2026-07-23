--!strict
-- Shared, versioned UI tokens for the Cooper lobby and compatible house UI.
-- Install as ReplicatedStorage.CooperUITheme in both experience places.

local Theme = {}

Theme.VERSION = 1
Theme.ID = "Cooper1980sRecRoom.v1"

-- These are the approved Milestone 1 lobby colors. Keeping every rendered
-- lobby color here prevents a stale private palette from drifting away from
-- the house-compatible theme contract.
Theme.Colors = table.freeze({
	Scrim = Color3.fromRGB(25, 18, 13),
	ScrimGradientWarm = Color3.fromRGB(42, 29, 18),
	ScrimGradientCool = Color3.fromRGB(15, 20, 16),
	Shadow = Color3.fromRGB(0, 0, 0),
	Cabinet = Color3.fromRGB(104, 55, 31),
	CabinetDark = Color3.fromRGB(61, 35, 25),
	CabinetGradientLight = Color3.fromRGB(129, 72, 39),
	CabinetGradientDeep = Color3.fromRGB(76, 43, 29),
	Screen = Color3.fromRGB(27, 37, 30),
	ScreenRaised = Color3.fromRGB(42, 54, 40),
	ScreenSoft = Color3.fromRGB(53, 62, 45),
	ScreenGradientLight = Color3.fromRGB(35, 48, 38),
	ScreenGradientDark = Color3.fromRGB(20, 28, 24),
	Outline = Color3.fromRGB(181, 153, 91),
	Cream = Color3.fromRGB(255, 244, 207),
	Muted = Color3.fromRGB(220, 213, 181),
	Mustard = Color3.fromRGB(238, 179, 54),
	MustardText = Color3.fromRGB(48, 31, 10),
	Avocado = Color3.fromRGB(174, 207, 90),
	Teal = Color3.fromRGB(133, 208, 197),
	TealText = Color3.fromRGB(16, 35, 31),
	Rust = Color3.fromRGB(255, 151, 112),
	Disabled = Color3.fromRGB(75, 76, 62),
})

Theme.Fonts = table.freeze({
	Body = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Strong = Enum.Font.GothamBold,
	Mono = Enum.Font.RobotoMono,
})

Theme.Metrics = table.freeze({
	SpacingUnit = 8,
	MinimumTouchTarget = 56,
	ActionHeight = 60,
})

Theme.Accessibility = table.freeze({
	BodyTextContrastMinimum = 4.5,
	LargeTextContrastMinimum = 3,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ClipToDeviceSafeArea = true,
})

return table.freeze(Theme)
