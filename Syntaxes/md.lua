--[=[
	Lexical scanner for creating a sequence of tokens from Markdown text input.
	This is an extremely modified fork of the Penlight Lua lexer.
	Heavy WIP and does not capture everything, but it's good enough to highlight a codeblock for now.
	
	List of possible tokens:
		- header
		- text
		- quote
		- code
		- list
		- ruler
--]=]

local lexer = {}

local Prefix,Suffix,Cleaner = "^[ \t\n\0\a\b\v\f\r]*", "[ \t\n\0\a\b\v\f\r]*", "[ \t\n\0\a\b\v\f\r]+"
local HEADER_A = "#+ .-\n"
local HEADER_B = "%.-\n%-%-%-\n"
local QUOTE = "> .-\n\n"
local CODE = "```%w-\n.-```"
local BULLETLIST = "%* .-\n"
local NUMBERLIST = "%d[%.)] .-\n"
local RULER = "%-%-%-%-%-*\n?"
local TEXT = "[%w \t]+"

local function hdump(src)
	return coroutine.yield("header", src)
end
local function tdump(src)
	return coroutine.yield("text", src)
end
local function qdump(src)
	return coroutine.yield("quote", src)
end
local function cdump(src)
	return coroutine.yield("code", src)
end
local function ldump(src)
	return coroutine.yield("list", src)
end
local function rdump(src)
	return coroutine.yield("ruler", src)
end


local md_matches = {
	{Prefix.. HEADER_A ..Suffix, hdump},
	{Prefix.. HEADER_B ..Suffix, hdump},
	{Prefix.. QUOTE ..Suffix, qdump},
	{Prefix.. CODE ..Suffix, cdump},
	{Prefix.. BULLETLIST ..Suffix, ldump},
	{Prefix.. NUMBERLIST ..Suffix, ldump},
	{Prefix.. RULER ..Suffix, rdump},
	{Prefix.. TEXT ..Suffix, tdump},

	-- Unknown
	{"^.", tdump}
}

--- Create a plain token iterator from a string.
-- @tparam string s a string.	

function lexer.scan(s)
	local startTime = os.clock()
	lexer.finished = false

	local function lex(first_arg)
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
					res = coroutine.yield(idx)
				end
			end
		end

		handle_requests(first_arg)

		while true do
			if idx > sz then
				while true do
					handle_requests(coroutine.yield())
				end
			end
			for _, m in ipairs(md_matches) do
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