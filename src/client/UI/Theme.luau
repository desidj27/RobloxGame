--!strict
-- Shared colours, fonts and sizes for the generated UI.

local Theme = {
	font = Enum.Font.Gotham,
	fontBold = Enum.Font.GothamBold,
	fontBlack = Enum.Font.GothamBlack,

	panel = Color3.fromRGB(24, 26, 34),
	panelLight = Color3.fromRGB(36, 39, 50),
	panelLighter = Color3.fromRGB(48, 52, 66),
	stroke = Color3.fromRGB(70, 76, 96),
	text = Color3.fromRGB(240, 242, 248),
	textMuted = Color3.fromRGB(160, 166, 184),

	accent = Color3.fromRGB(90, 160, 255),
	success = Color3.fromRGB(80, 210, 120),
	danger = Color3.fromRGB(235, 85, 85),
	warning = Color3.fromRGB(255, 190, 70),

	mining = Color3.fromRGB(255, 170, 80),
	fishing = Color3.fromRGB(90, 190, 255),

	radius = UDim.new(0, 10),
	radiusSmall = UDim.new(0, 6),
	padding = 12,
}

return Theme
