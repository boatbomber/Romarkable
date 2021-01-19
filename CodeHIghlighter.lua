local module = {}

local Lexers = {}

local function sanitize(s)
	return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

for _, Lexer in pairs(script.Syntaxes:GetChildren()) do
	Lexers[Lexer.Name:lower()] = require(Lexer);
end

local TokenColors = {
	-- raw
	["raw"] = Color3.fromRGB(232, 233, 234);
	
	-- lua
	["iden"] = Color3.fromRGB(232, 233, 234);
	["keyword"] = Color3.fromRGB(197, 151, 243);
	["builtin"] = Color3.fromRGB(91, 173, 235);
	["string"] = Color3.fromRGB(180, 241, 142);
	["number"] = Color3.fromRGB(190, 112, 102);
	["comment"] = Color3.fromRGB(103, 106, 108);
	["operator"] = Color3.fromRGB(223, 201, 166);
	
	-- md
	["text"] = Color3.fromRGB(232, 233, 234);
	["header"] = Color3.fromRGB(187, 211, 243);
	["quote"] = Color3.fromRGB(91, 173, 235);
	["list"] = Color3.fromRGB(171, 217, 164);
	["ruler"] = Color3.fromRGB(175, 175, 175);
    ["code"] = Color3.fromRGB(159, 154, 190);
}

function module:Highlight(Label,Syntax)
	local Lexer = Lexers[Syntax:lower()] or Lexers.lua
	
	local RichText,Index = {},0
	for token,src in Lexer.scan(Label.Text) do
		local Color = TokenColors[token] or TokenColors.raw

		Index += 1
		RichText[Index] = string.format("<font color=\"rgb(%d,%d,%d)\">%s</font>", Color.R*255,Color.G*255,Color.B*255,sanitize(src))
	end
	
	Label.RichText = true
	Label.Text = table.concat(RichText)
	
end

return module