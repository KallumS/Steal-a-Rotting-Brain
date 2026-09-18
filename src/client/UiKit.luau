--[[
	UiKit
	Tiny helpers so the HUD can be declared inline without a UI library,
	plus the single palette every controller draws from.
]]

local UiKit = {}

UiKit.Palette = {
	Panel = Color3.fromRGB(16, 18, 16),
	PanelStroke = Color3.fromRGB(88, 120, 82),
	Text = Color3.fromRGB(238, 238, 232),
	Dim = Color3.fromRGB(168, 170, 164),
	Accent = Color3.fromRGB(150, 220, 140),
	Danger = Color3.fromRGB(255, 112, 112),
	Gold = Color3.fromRGB(255, 205, 90),
	Purple = Color3.fromRGB(190, 140, 255),
}

-- UiKit.new("Frame", { Size = ... }, { child, child })
function UiKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil

	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end

	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

-- A dark rounded panel with a faint green edge.
function UiKit.panel(props: { [string]: any }, children: { Instance }?): Frame
	local merged = {
		BackgroundColor3 = UiKit.Palette.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}
	for key, value in pairs(props) do
		merged[key] = value
	end

	local frame = UiKit.new("Frame", merged, children)

	UiKit.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = frame })
	UiKit.new("UIStroke", {
		Color = UiKit.Palette.PanelStroke,
		Thickness = 1.5,
		Transparency = 0.45,
		Parent = frame,
	})

	return frame
end

function UiKit.label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UiKit.Palette.Text,
		TextScaled = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	return UiKit.new("TextLabel", merged)
end

return UiKit
