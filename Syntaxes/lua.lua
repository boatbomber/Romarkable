--[=[
	Lexical scanner for creating a sequence of tokens from Lua source code.
	This is a heavily modified and Roblox-optimized version of
	the original Penlight Lexer module:
		https://github.com/stevedonovan/Penlight
	Authors:
		stevedonovan <https://github.com/stevedonovan> ----------- Original Penlight lexer author
		ryanjmulder <https://github.com/ryanjmulder> ------------- Penlight lexer contributer
		mpeterv <https://github.com/mpeterv> --------------------- Penlight lexer contributer
		Tieske <https://github.com/Tieske> ----------------------- Penlight lexer contributer
		boatbomber <https://github.com/boatbomber> --------------- Roblox port, added builtin token, added patterns for incomplete syntax, bug fixes, behavior changes, token optimization
		Sleitnick <https://github.com/Sleitnick> ----------------- Roblox optimizations
		howmanysmall <https://github.com/howmanysmall> ----------- Lua + Roblox optimizations
		boatbomber <https://github.com/boatbomber> --------------- Added lexer.navigator() for non-sequential reads
	
	List of possible tokens:
		- iden
		- keyword
		- builtin
		- string
		- number
		- comment
		- operator
	
--]=]

local lexer = {}

local Prefix,Suffix,Cleaner = "^[ \t\n\0\a\b\v\f\r]*", "[ \t\n\0\a\b\v\f\r]*", "[ \t\n\0\a\b\v\f\r]+"
local NUMBER_A = "0x[%da-fA-F]+"
local NUMBER_B = "%d+%.?%d*[eE][%+%-]?%d+"
local NUMBER_C = "%d+[%._]?[%d_eE]*"
local OPERATORS = "[:;<>/~%*%(%)%-=,{}%.#%^%+%%]+"
local BRACKETS = "[%[%]]+" -- needs to be separate pattern from other operators or it'll mess up multiline strings
local IDEN = "[%a_][%w_]*"
local STRING_EMPTY = "(['\"])%1"							--Empty String
local STRING_PLAIN = [=[(['"])[%w%p \t\v\b\f\r\a]-([^%\]%1)]=]	--TODO: Handle escaping escapes
local STRING_INCOMP_A = "(['\"]).-\n"						--Incompleted String with next line
local STRING_INCOMP_B = "(['\"])[^\n]*"					--Incompleted String without next line
local STRING_MULTI = "%[(=*)%[.-%]%1%]"					--Multiline-String
local STRING_MULTI_INCOMP = "%[=*%[.-.*"						--Incompleted Multiline-String
local COMMENT_MULTI = "%-%-%[(=*)%[.-%]%1%]"				--Completed Multiline-Comment
local COMMENT_MULTI_INCOMP = "%-%-%[=*%[.-.*"				--Incompleted Multiline-Comment
local COMMENT_PLAIN = "%-%-.-\n"							--Completed Singleline-Comment
local COMMENT_INCOMP = "%-%-.*"							--Incompleted Singleline-Comment

local TABLE_EMPTY = {}

local lua_keyword = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,
	["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["while"] = true,
	["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
	["self"] = true, ["until"] = true,

	["continue"] = true,

	["plugin"] = true, --Highlights as a keyword instead of a builtin cuz Roblox is weird
}


local lua_builtin = {
	-- Lua Functions
	["assert"] = true;["collectgarbage"] = true;["error"] = true;["getfenv"] = true;
	["getmetatable"] = true;["ipairs"] = true;["loadstring"] = true;["newproxy"] = true;
	["next"] = true;["pairs"] = true;["pcall"] = true;["print"] = true;["rawequal"] = true;
	["rawget"] = true;["rawset"] = true;["select"] = true;["setfenv"] = true;["setmetatable"] = true;
	["tonumber"] = true;["tostring"] = true;["type"] = true;["unpack"] = true;["xpcall"] = true;

	-- Lua Variables
	["_G"] = true;["_VERSION"] = true;

	-- Lua Tables
	["bit32"] = true;["coroutine"] = true;["debug"] = true;
	["math"] = true;["os"] = true;["string"] = true;
	["table"] = true;["utf8"] = true;

	-- Roblox Functions
	["delay"] = true;["elapsedTime"] = true;["gcinfo"] = true;["require"] = true;
	["settings"] = true;["spawn"] = true;["tick"] = true;["time"] = true;["typeof"] = true;
	["UserSettings"] = true;["wait"] = true;["warn"] = true;["ypcall"] = true;

	-- Roblox Variables
	["Enum"] = true;["game"] = true;["shared"] = true;["script"] = true;
	["workspace"] = true;

	-- Roblox Tables
	["Axes"] = true;["BrickColor"] = true;["CellId"] = true;["CFrame"] = true;["Color3"] = true;
	["ColorSequence"] = true;["ColorSequenceKeypoint"] = true;["DateTime"] = true;
	["DockWidgetPluginGuiInfo"] = true;["Faces"] = true;["Instance"] = true;["NumberRange"] = true;
	["NumberSequence"] = true;["NumberSequenceKeypoint"] = true;["PathWaypoint"] = true;
	["PhysicalProperties"] = true;["PluginDrag"] = true;["Random"] = true;["Ray"] = true;["Rect"] = true;
	["Region3"] = true;["Region3int16"] = true;["TweenInfo"] = true;["UDim"] = true;["UDim2"] = true;
	["Vector2"] = true;["Vector2int16"] = true;["Vector3"] = true;["Vector3int16"] = true;
}

local function idump(tok)
	--print("tok unknown:",tok)
	return coroutine.yield("iden", tok)
end

local function odump(tok)
	return coroutine.yield("operator", tok)
end

local function ndump(tok)
	return coroutine.yield("number", tok)
end

local function sdump(tok)
	return coroutine.yield("string", tok)
end

local function cdump(tok)
	return coroutine.yield("comment", tok)
end

local function lua_vdump(tok)
	-- Since we merge spaces into the tok, we need to remove them
	-- in order to check the actual word it contains
	local cleanTok = string.gsub(tok,Cleaner,"")

	if lua_keyword[cleanTok] then
		return coroutine.yield("keyword", tok)
	elseif lua_builtin[cleanTok] then
		return coroutine.yield("builtin", tok)
	else
		return coroutine.yield("iden", tok)
	end
end

local lua_matches = {
	-- Indentifiers
	{Prefix.. IDEN ..Suffix, lua_vdump},

	-- Numbers
	{Prefix.. NUMBER_A ..Suffix, ndump},
	{Prefix.. NUMBER_B ..Suffix, ndump},
	{Prefix.. NUMBER_C ..Suffix, ndump},

	-- Strings
	{Prefix.. STRING_EMPTY ..Suffix, sdump},
	{Prefix.. STRING_PLAIN ..Suffix, sdump},
	{Prefix.. STRING_INCOMP_A ..Suffix, sdump},
	{Prefix.. STRING_INCOMP_B ..Suffix, sdump},
	{Prefix.. STRING_MULTI ..Suffix, sdump},
	{Prefix.. STRING_MULTI_INCOMP ..Suffix, sdump},

	-- Comments
	{Prefix.. COMMENT_MULTI ..Suffix, cdump},			
	{Prefix.. COMMENT_MULTI_INCOMP ..Suffix, cdump},
	{Prefix.. COMMENT_PLAIN ..Suffix, cdump},
	{Prefix.. COMMENT_INCOMP ..Suffix, cdump},

	-- Operators
	{Prefix.. OPERATORS ..Suffix, odump},
	{Prefix.. BRACKETS ..Suffix, odump},

	-- Unknown
	{"^.", idump}
}

--- Create a plain token iterator from a string.
-- @tparam string s a string.	

function lexer.scan(s)
	local startTime = os.clock()
	lexer.finished = false

	local function lex(first_arg)
		local line_nr = 0
		local sz = #s
		local idx = 1

		-- res is the value used to resume the coroutine.
		local function handle_requests(res)
			while res do
				local tp = type(res)
				-- Insert a token list:
				if tp == "table" then
					res = coroutine.yield("", "")
					for _, t in ipairs(res) do
						res = coroutine.yield(t[1], t[2])
					end
				elseif tp == "string" then -- Or search up to some special pattern:
					local i1, i2 = string.find(s, res, idx)
					if i1 then
						idx = i2 + 1
						res = coroutine.yield("", string.sub(s, i1, i2))
					else
						res = coroutine.yield("", "")
						idx = sz + 1
					end
				else
					res = coroutine.yield(line_nr, idx)
				end
			end
		end

		handle_requests(first_arg)
		line_nr = 1

		while true do
			if idx > sz then
				while true do
					handle_requests(coroutine.yield())
				end
			end
			for _, m in ipairs(lua_matches) do
				local findres = {}
				local i1, i2 = string.find(s, m[1], idx)
				findres[1], findres[2] = i1, i2
				if i1 then
					local tok = string.sub(s, i1, i2)
					idx = i2 + 1
					lexer.finished = idx > sz
					--if lexer.finished then
					--	print(string.format("Lex took %.2f ms", (os.clock()-startTime)*1000 ))
					--end

					local res = m[2](tok, findres)

					if string.find(tok, "\n") then
						-- Update line number:
						local _, newlines = string.gsub(tok, "\n", TABLE_EMPTY)
						line_nr = line_nr + newlines
					end

					handle_requests(res)
					break
				end
			end
		end
	end
	return coroutine.wrap(lex)
end

function lexer.navigator()
	
	local nav = {
		Source = "";
		TokenCache = table.create(50);
		
		_RealIndex = 0;
		_UserIndex = 0;
		_ScanThread = nil;
	}
	
	function nav:Destroy()
		self.Source = nil
		self._RealIndex = nil;
		self._UserIndex = nil;
		self.TokenCache = nil;
		self._ScanThread = nil;
	end
	
	function nav:SetSource(SourceString)
		self.Source = SourceString
		
		self._RealIndex = 0;
		self._UserIndex = 0;
		table.clear(self.TokenCache)
		
		self._ScanThread = coroutine.create(function()
			for Token,Src in lexer.scan(self.Source) do
				self._RealIndex += 1
				self.TokenCache[self._RealIndex] = {Token; Src;}
				coroutine.yield(Token,Src)
			end
		end)
	end

	function nav.Next()
		nav._UserIndex += 1
		
		if nav._RealIndex >= nav._UserIndex then
			-- Already scanned, return cached
			return table.unpack(nav.TokenCache[nav._UserIndex])
		else
			if coroutine.status(nav._ScanThread) == 'dead' then
				-- Scan thread dead
				return
			else
				local success, token, src = coroutine.resume(nav._ScanThread)
				if success and token then
					-- Scanned new data
					return token,src
				else
					-- Lex completed
					return
				end
			end
		end
		
	end
	
	function nav.Peek(PeekAmount)
		local GoalIndex = nav._UserIndex + PeekAmount
		
		if nav._RealIndex >= GoalIndex then
			-- Already scanned, return cached
			if GoalIndex > 0 then
				return table.unpack(nav.TokenCache[GoalIndex])
			else
				-- Invalid peek
				return
			end
		else
			if coroutine.status(nav._ScanThread) == 'dead' then
				-- Scan thread dead
				return
			else
				
				local IterationsAway = GoalIndex - nav._RealIndex
				
				local success, token, src = nil,nil,nil
				
				for i=1, IterationsAway do
					success, token, src = coroutine.resume(nav._ScanThread)
					if not (success or token) then
						-- Lex completed
						break
					end
				end
				
				return token,src
			end
		end
		
	end
	
	return nav
end

return lexer