-- Services
local TextService = game:GetService("TextService")
-- Dependancies
local Markdown = require(script.Markdown)
	local BlockType = Markdown.BlockType
local CodeHighlighter = require(script.CodeHighlighter)

-- Module
local Renderer = {}

-- This is a temporary method until TextService:GetTextSize supports RichText
local SizingGui = Instance.new("ScreenGui")
SizingGui.Enabled = false
SizingGui.Name = "RichText_Sizing"
local SizingLabel = Instance.new("TextLabel")
SizingLabel.TextWrapped = true
SizingLabel.RichText = true
SizingLabel.Parent = SizingGui
SizingGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local function GetRichTextSize(Text,TextSize,Font,AbsoluteSize)
	SizingLabel.Text = Text
	SizingLabel.TextSize = TextSize
	SizingLabel.Font = Font
	SizingLabel.Size = UDim2.new(0,AbsoluteSize.X,0,AbsoluteSize.Y)
	
	return SizingLabel.TextBounds
end

-- Block render handlers
Renderer.BlockToGui = {
	
	[BlockType.Paragraph] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
			local Label = Instance.new("TextLabel")
			Label.RichText = true
			Label.Font = Enum.Font.SourceSans
			Label.TextColor3 = Color3.new(0.99,0.99,0.99)
			Label.BackgroundTransparency = 1
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Top
			Label.TextWrapped = true

			Label.Text = block.Text
			Label.TextSize = 18

			local Size = GetRichTextSize(Label.Text, Label.TextSize, Label.Font, Vector2.new(ParentFrame.AbsoluteSize.X-15,9999))
			Label.Size = UDim2.new(1,-10,0,Size.Y+2)
			Label.Position = UDim2.new(0,10,0,0)
			Label.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Size.Y+2)
		return Frame
	end;
	
	[BlockType.Heading] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
			local Label = Instance.new("TextLabel")
			Label.RichText = true
			Label.Font = Enum.Font.SourceSans
			Label.TextColor3 = Color3.new(0.99,0.99,0.99)
			Label.BackgroundTransparency = 1
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Top
			Label.TextWrapped = true

			Label.Text = block.Text
			Label.TextSize = 60 - (math.clamp(block.Level,1,5) * 10)

			local Size = GetRichTextSize(Label.Text, Label.TextSize, Label.Font, Vector2.new(ParentFrame.AbsoluteSize.X-10,9999))
			Label.Size = UDim2.new(1,-12,0,Size.Y+2)
			Label.Position = UDim2.new(0,12,0,0)
			Label.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Size.Y+3)
		return Frame
	end;
	
	[BlockType.Image] = function(block, ParentFrame)
		
		local GivenWidth = (block.Resolution.X*block.Scale)
		
		local Size = ParentFrame.AbsoluteSize.X>GivenWidth and GivenWidth or ParentFrame.AbsoluteSize.X*0.9
		
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
			local Image = Instance.new("ImageLabel")
			Image.BackgroundTransparency = 1
			Image.Image = block.ID or "rbxassetid://6266306999"
			Image.Size = UDim2.new(0,Size*(block.AspectRatio or 1),0,Size)
			Image.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Size+3)
		return Frame
	end;
	
	[BlockType.Code] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
		Frame.BorderSizePixel = 0
			local Label = Instance.new("TextLabel")
			Label.RichText = true
			Label.Font = Enum.Font.Code
			Label.TextColor3 = Color3.new(0.99,0.99,0.99)
			Label.BackgroundTransparency = 1
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextWrapped = true

			Label.Text = block.Code
			Label.TextSize = 18

			local Size = GetRichTextSize(Label.Text, Label.TextSize, Label.Font, Vector2.new(ParentFrame.AbsoluteSize.X-13,9999))
			Label.Size = UDim2.new(1,-12,0,Size.Y+2)
			Label.Position = UDim2.new(0,10,0,0)
			
			CodeHighlighter:Highlight(Label, block.Syntax)
			
			Label.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Size.Y+6)
		return Frame
	end;
	
	[BlockType.List] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
		
		local Window = Instance.new("Frame")
		Window.BackgroundTransparency = 1
		Window.Size = UDim2.new(1,-20,1,0)
		Window.Position = UDim2.new(0,12,0,0)
		
		local Layout = Instance.new("UIListLayout")
		Layout.FillDirection = Enum.FillDirection.Vertical
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
		Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		Layout.VerticalAlignment = Enum.VerticalAlignment.Top
		Layout.Padding = UDim.new(0,3)
		Layout.Parent = Window

		for i,line in ipairs(block.Lines) do
			local Label = Instance.new("TextLabel")
			Label.RichText = true
			Label.Font = Enum.Font.SourceSans
			Label.TextColor3 = Color3.new(0.99,0.99,0.99)
			Label.BackgroundTransparency = 1
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Top
			Label.TextWrapped = true
			Label.LayoutOrder = i

			Label.Text = string.rep("  ", line.Level)..(line.Symbol:match("%w+[%.%)]") or "•").." "..line.Text
			Label.TextSize = 18

			local Size = GetRichTextSize(Label.Text, Label.TextSize, Label.Font, Vector2.new(ParentFrame.AbsoluteSize.X-22,9999))
			Label.Size = UDim2.new(1,-10,0,Size.Y+2)
			Label.Position = UDim2.new(0,10,0,0)
			Label.Parent = Window
		end
		
		Window.Parent = Frame
			
		Frame.Size = UDim2.new(1,0,0,Layout.AbsoluteContentSize.Y+2)
		return Frame
	end;
	
	[BlockType.Quote] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
		
			local Line = Instance.new("Frame")
			Line.BackgroundColor3 = Color3.fromRGB(30,30,30)
			Line.BorderSizePixel = 0
			Line.Size = UDim2.new(0,3,1,-4)
			Line.Position = UDim2.new(0,12,0,2)
			Line.Parent = Frame
			local Window = Instance.new("Frame")
			Window.BackgroundTransparency = 1
			Window.Size = UDim2.new(1,-20,1,0)
			Window.Position = UDim2.new(0,15,0,0)
			Window.Parent = Frame
			
			Renderer.Render(Window, block.RawText)

		Frame.Size = UDim2.new(1,0,0,Window.UIListLayout.AbsoluteContentSize.Y+2)
		return Frame
	end;
	
	[BlockType.Ruler] = function(block, ParentFrame)
		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
			local Line = Instance.new("Frame")
			Line.BackgroundColor3 = Color3.new(0.9,0.9,0.9)
			Line.BorderSizePixel = 0
			Line.Size = UDim2.new(1,-10,0,2)
			Line.Position = UDim2.new(0,5,0,0)
			Line.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,4)
		return Frame
	end;
}

-- Function to render MD into a given frame
function Renderer.Render(ParentFrame, Source)
	
	-- Prepare the GUI
	
	ParentFrame:ClearAllChildren()

	local Layout = Instance.new("UIListLayout")
		Layout.FillDirection = Enum.FillDirection.Vertical
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
		Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		Layout.VerticalAlignment = Enum.VerticalAlignment.Top
		Layout.Padding = UDim.new(0,3)
		Layout.Parent = ParentFrame
		
	-- Parse the MD and draw the blocks
	
	local BlockIndex = 0
	for blockType, block in Markdown.parse(Source) do
		BlockIndex += 1
		
		local success, gui = pcall(Renderer.BlockToGui[blockType] or Renderer.BlockToGui[BlockType.Paragraph], block,ParentFrame)
		if success then
			gui.Name = BlockIndex
			gui.LayoutOrder = BlockIndex
			gui.Parent = ParentFrame
		else
			warn(gui)
		end
	end
	
	-- Size the parent scrolling if applicable
	
	if ParentFrame:IsA("ScrollingFrame") then
		ParentFrame.CanvasSize = UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y)
	end
end

return Renderer
