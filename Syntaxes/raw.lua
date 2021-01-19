--[=[
	Mock lexical scanner for raw text.
	Exists in this format for the sake of keeping in style with the other lexers.
	
	List of possible tokens:
		- raw
--]=]

local lexer = {}

--- Create a plain token iterator from a string.
-- @tparam string s a string.	

function lexer.scan(s)
	local function lex(first_arg)
		for i=1,1 do
			coroutine.yield("raw",s)
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