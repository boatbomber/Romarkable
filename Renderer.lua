-- Services
local TextService = game:GetService("TextService")
local MarketplaceService = game:GetService("MarketplaceService")
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

-- Handle DecalIDs vs ImageIDs in images
local ImageCache = {}
local function ImageIDHandler(AssetID, ImageLabel)
	local StrNumbers = string.match(AssetID, "%d+")
	local Numbers = tonumber(StrNumbers)
	
	local ID = ImageCache[StrNumbers]
	if ID then
		-- Correct ID already cached
		ImageLabel.Image = ID
		return
	else
		-- Find correct ID via garbage workarounds :(
		local ProductInfo
		
		local Success, Error = pcall(function()
			ProductInfo = MarketplaceService:GetProductInfo(StrNumbers, Enum.InfoType.Asset)
			
			if ProductInfo.AssetTypeId == 1 then
				-- It's an image ID, use as is
				ID = "rbxassetid://"..StrNumbers
				ImageCache[StrNumbers] = ID
				ImageLabel.Image = ID
				return
					
			elseif ProductInfo.AssetTypeId == 13 then
				-- It's a decal ID, so lets do our best to find the image ID before resorting to the low res decal version
				
				--Try the old -1 trick for a bit
				local creatorID = ProductInfo.Creator.Id
				for i = 0, 50 do
					local nextAsset = MarketplaceService:GetProductInfo(Numbers-i, Enum.InfoType.Asset)

					if nextAsset.AssetTypeId == 1 and nextAsset.Creator.Id == creatorID then --It's an image ID and same creator, so good odds it's the image we need
						ID = "rbxassetid://"..(Numbers-i)
						ImageCache[StrNumbers] = ID
						ImageLabel.Image = ID
						return
					end
				end
				
				-- We didn't find it via the -1 so lets use the low-res thumb
				ID = "https://www.roblox.com/asset-thumbnail/image?assetId=".. StrNumbers .."&width=420&height=420&format=png"
				ImageCache[StrNumbers] = ID
				ImageLabel.Image = ID
				return
				
			end
		end)
		if not Success then
			-- ID find failed, revert to low res or display HTTP error
			if ProductInfo and ProductInfo.AssetTypeId == 13 then
				ID = "https://www.roblox.com/asset-thumbnail/image?assetId=".. StrNumbers .."&width=420&height=420&format=png"
				ImageLabel.Image = ID
				return
			else
				if string.find(Error, "requests") then
					ImageLabel.Image = "rbxassetid://6270259323" -- HTTP error message
					ImageLabel.ScaleType = Enum.ScaleType.Fit
					return
				else
					ImageLabel.Image = "rbxassetid://6266306999" -- Broken image
					ImageLabel.ScaleType = Enum.ScaleType.Fit
					return
				end
			end
		end
		
	end
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
		Image.Size = UDim2.new(0,Size*(block.AspectRatio or 1),0,Size)
		
		local ImageThread = coroutine.create(ImageIDHandler)
		coroutine.resume(ImageThread, block.ID or "rbxassetid://6266306999", Image)
		
		Image.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Size+3)
		return Frame
	end;

	[BlockType.LuaLearningImage] = function(block, ParentFrame)

		local Size = ParentFrame.AbsoluteSize.X*0.7

		local Frame = Instance.new("Frame")
		Frame.BackgroundTransparency = 1
		local Image = Instance.new("ImageLabel")
		Image.BackgroundTransparency = 1
		Image.Size = UDim2.new(0,Size,0,Size/(block.AspectRatio or 1))
		
		local ImageThread = coroutine.create(ImageIDHandler)
		coroutine.resume(ImageThread, block.ID or "rbxassetid://6266306999", Image)
		
		Image.Parent = Frame

		Frame.Size = UDim2.new(1,0,0,Image.Size.Y.Offset)
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

		Label.Text = block.Code or ""
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
		Window.Position = UDim2.new(0,15,0,0)
		Window.Parent = Frame

		-- Temp size for Render to use
		Window.Size = UDim2.new(0,ParentFrame.AbsoluteSize.X-20,0,9999)

		Renderer.Render(Window, block.RawText)

		Window.Size = UDim2.new(1,-20,1,0)
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
