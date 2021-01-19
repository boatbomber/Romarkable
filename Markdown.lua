------------------------------------------------------------------------------------------------------------------------
-- Name:		Markdown.lua
-- Version:		1.0 (1/17/2021)
-- Authors:		Brad Sharp, Zack Ovits
--
-- Repository:	https://github.com/BradSharp/Romarkable
-- License:		MIT (https://github.com/BradSharp/Romarkable/blob/main/LICENSE)
--
-- Copyright (c) 2021 Brad Sharp
------------------------------------------------------------------------------------------------------------------------

local Markdown = {}

------------------------------------------------------------------------------------------------------------------------
-- Text Parser
------------------------------------------------------------------------------------------------------------------------

local InlineType = {
	Text	= 0,
	Ref		= 1,
}

local ModifierType = {
	Bold	= 0,
	Italic	= 1,
	Strike	= 2,
	Code	= 3,
}

local function sanitize(s)
	return string.gsub(string.gsub(string.gsub(string.gsub(string.gsub(s, "&","&amp;"), "<","&lt;"), ">","&gt;"), "\"","&quot;"), "'","&apos;")
end

local function characters(s)
	return string.gmatch(s,".")
end

local function last(t)
	return t[#t]
end

local function getModifiers(stack)
	local modifiers = {}
	for _, modifierType in pairs(stack) do
		modifiers[modifierType] = true
	end
	return modifiers
end

local function parseModifierTokens(md)
	local index = 1
	return function ()
		local text, newIndex = string.match(md,"^([^%*_~`]+)()", index)
		if text then
			index = newIndex
			return false, text
		elseif index <= #md then
			local text, newIndex = string.match(md,"^(%" .. string.sub(md, index, index) .. "+)()", index)
			index = newIndex
			return true, text
		end
	end
end

local function parseText(md)
	
end

local richTextLookup = {
	["**"] = ModifierType.Bold,
	["__"] = ModifierType.Bold,
	["*"] = ModifierType.Italic,
	["_"] = ModifierType.Italic,
	["~"] = ModifierType.Strike,
	["`"] = ModifierType.Code,
}

local function getRichTextModifierType(symbols)
	return richTextLookup[symbols]
end

local function richText(md)
	md = sanitize(md)
	local tags = {
		[ModifierType.Bold]		= {"<b>", "</b>"},
		[ModifierType.Italic]	= {"<i>", "</i>"},
		[ModifierType.Strike]	= {"<s>", "</s>"},
		[ModifierType.Code]		= {"<font face=\"RobotoMono\">", "</font>"},
	}
	local state = {}
	local outputArray,outputIndex = {},0
	for token, text in parseModifierTokens(md) do
		if token then
			local modifierType = getRichTextModifierType(text)
			if not modifierType then
				outputIndex += 1
				outputArray[outputIndex] = text
				continue
			end
			if state[ModifierType.Code] and modifierType ~= ModifierType.Code then
				outputIndex += 1
				outputArray[outputIndex] = text
				continue
			end
			local symbolState = state[modifierType]
			if not symbolState then
				outputIndex += 1
				outputArray[outputIndex] = tags[modifierType][1]
				state[modifierType] = text
			elseif text == symbolState then
				outputIndex += 1
				outputArray[outputIndex] = tags[modifierType][2]
				state[modifierType] = nil
			else
				outputIndex += 1
				outputArray[outputIndex] = text
			end
		else
			outputIndex += 1
			outputArray[outputIndex] = text
		end
	end
	for modifierType in pairs(state) do
		outputIndex += 1
		outputArray[outputIndex] = tags[modifierType][2]
	end
	return table.concat(outputArray)
end

------------------------------------------------------------------------------------------------------------------------
-- Document Parser
------------------------------------------------------------------------------------------------------------------------

local BlockType = {
	None		= 0,
	Paragraph	= 1,
	Heading		= 2,
	Code		= 3,
	List		= 4,
	Ruler		= 5,
	Quote		= 6,
	Image		= 7,
}

local CombinedBlocks = {
	[BlockType.None]		= true,
	[BlockType.Paragraph]	= true,
	[BlockType.Code]		= true,
	[BlockType.List]		= true,
	[BlockType.Quote]		= true,
}

local function cleanup(s)
	return string.gsub(s, "\t", "    ")
end

local function getTextWithIndentation(line)
	local indent, text = string.match(line, "^%s*()(.*)")
	return text, math.floor(indent / 2)
end

-- Iterator: Iterates the string line-by-line
local function lines(s)
	return string.gmatch(s.."\n", "(.-)\n")
end

-- Iterator: Categorize each line and allows iteration
local function blockLines(md)
	local blockType = BlockType.None
	local nextLine = lines(md)
	local function it()
		local line = nextLine()
		if not line then
			return
		end
		-- Code
		if blockType == BlockType.Code then
			if string.match(line, "^```") then
				blockType = BlockType.None
			end
			return BlockType.Code, line
		end
		-- Blank line
		if string.match(line, "^%s*$") then
			return BlockType.None, ""
		end
		-- Ruler
		if string.match(line, "^%-%-%-+") or string.match(line, "^===+") then
			return BlockType.Ruler, ""
		end
		-- Image
		if string.match(line, "^%s*!%[%w-|?[%dx]*,? ?%d*%%?%]%(.-%)") then
			return BlockType.Image, line
		end
		-- Heading
		if string.match(line, "^#") then
			return BlockType.Heading, line
		end
		-- Code
		if string.match(line, "^%s*```") then
			blockType = BlockType.Code
			return blockType, line
		end
		-- Quote
		if string.match(line, "^%s*>") then
			return BlockType.Quote, line
		end
		-- List
		if string.match(line, "^%s*%-%s+") or string.match(line, "^%s*%*%s+") or string.match(line, "^%s*[%u%d]+%.%s+") or string.match(line, "^%s*%+%s+") then
			return BlockType.List, line
		end
		-- Paragraph
		return BlockType.Paragraph, line -- should take into account indentation of first-line
	end
	return it
end

-- Iterator: Joins lines of the same type into a single element
local function textBlocks(md)
	local it = blockLines(md)
	local lastBlockType, lastLine = it()
	return function ()
		-- This function works by performing a lookahead at the next line and then deciding what to do with the
		-- previous line based on that.
		local nextBlockType, nextLine = it()
		if nextBlockType == BlockType.Ruler and lastBlockType == BlockType.Paragraph then
			-- Combine paragraphs followed by rulers into headers
			local text = lastLine
			lastBlockType, lastLine = it()
			return BlockType.Heading, string.rep("#", string.sub(lastLine, 1, 1) == "=" and 2 or 1) .. " " .. text
		end
		local lines = { lastLine }
		while CombinedBlocks[nextBlockType] and nextBlockType == lastBlockType do
			table.insert(lines, nextLine)
			nextBlockType, nextLine = it()
		end
		local blockType, blockText = lastBlockType, table.concat(lines, "\n")
		lastBlockType, lastLine = nextBlockType, nextLine
		return blockType, blockText
	end
end

-- Iterator: Transforms raw blocks into sections with data
local function blocks(md, markup)
	local nextTextBlock = textBlocks(md)
	local function it()
		local blockType, blockText = nextTextBlock()
		if blockType == BlockType.None then
			return it() -- skip this block type
		end
		local block = {}
		if blockType then
			local text, indent = getTextWithIndentation(blockText)
			block.Indent = indent
			if blockType == BlockType.Paragraph then
				block.Text = markup(text)
			elseif blockType == BlockType.Image then
				local Title = string.match(text, "^!%[(%w-)|?[%dx]*,? ?%d*%%?%]")
				local ID = string.match(text,"%((.-)%)$")
				block.Title = Title or "Unknown"
				block.ID = ID or "rbxassetid://6266306999"
				
				local X,Y = string.match(text ,"^%s*!%[%w-|(%d+)x(%d+)%]*")
				local x,y = tonumber(X),tonumber(Y)
				block.Resolution = {X = x and x or 1024, Y = y and y or 1024}
				block.AspectRatio = (x and x or 1)/(y and y or 1)
				
				local Scale = string.match(text, "^%s*!%[%w-|?[%dx]*, (%d+)%%")
				Scale = (tonumber(Scale) or 100)/100
				block.Scale = Scale
			elseif blockType == BlockType.Heading then
				local level, text = string.match(blockText, "^#+()%s*(.*)")
				block.Level, block.Text = level - 1, markup(text)
			elseif blockType == BlockType.Code then
				local syntax, code = string.match(text, "^```(.-)\n(.*)\n```$")
				block.Syntax, block.Code = syntax, syntax == "raw" and code or sanitize(code)
			elseif blockType == BlockType.List then
				local lines = string.split(blockText, "\n")
				for i, line in ipairs(lines) do
					local text, indent = getTextWithIndentation(line)
					local symbol, text = string.match(text, "^(.-)%s+(.*)")
					lines[i] = {
						Level = indent,
						Text = markup(text),
						Symbol = symbol,
					}
				end
				block.Lines = lines
			elseif blockType == BlockType.Quote then
				local lines = string.split(blockText, "\n")
				for i = 1, #lines do
					lines[i] = string.match(lines[i], "^%s*>%s*(.*)")
				end
				local rawText = table.concat(lines, "\n")
				block.RawText, block.Iterator = rawText, blocks(rawText, markup)
			end
		end
		return blockType, block
	end
	return it		
end

local function parseDocument(md, inlineParser)
	return blocks(cleanup(md), inlineParser or richText)
end

------------------------------------------------------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------------------------------------------------------

Markdown.sanitize = sanitize
Markdown.parse = parseDocument
Markdown.parseText = parseText
Markdown.parseTokens = parseModifierTokens
Markdown.BlockType = BlockType
Markdown.InlineType = InlineType
Markdown.ModifierType = ModifierType

return Markdown
