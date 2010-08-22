--[[
Name	: ircbot.lua -- fast, diverse irc bot in lua
Author	: David Shaw (dshaw@redspin.com)
Date	: August 8, 2010
Desc.	: ircbot.lua uses the luasocket library. This
	  can be installed on Debian-based OS's with
	  sudo apt-get install liblua5.1-socket2.
	
License	: FreeBSD License

Copyright 2010 The ircbot.lua Project. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
   
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
      
THIS SOFTWARE IS PROVIDED BY THE IRCBOT.lua PROJECT ``AS IS'' AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO 
EVENT SHALL THE FREEBSD PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.
      
The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of the ircbot.lua Project. 
]]--

--[[
	TODO !!
	
	- Socket (s) needs to be global (table?) to be accessible
	by all functions, instead of passed as an argument as it is currently.
	
	- File IO for functions (memos, possible http cache?)
	
		\- Loading config from config.txt
]]

require "socket" -- luasocket

-- globals
list = {}
lineregex = "[^\r\n]+"
memo = {}

-- definitions for use later in the script
function deliver(s, content)
	s:send(content .. "\r\n\r\n")
end

function msg(s, channel, content)
	deliver(s, "PRIVMSG " .. channel .. " :" .. content)
end

function sync(lnick)
	for x=1, #list do
		if list[x] == lnick then
			return false
		end
	end
	list[#list + 1] = lnick
	return true	
end

function repspace(main, first, second)
	-- start with 0 --> first instance to replace
	local relapsed = string.sub(main, 1, string.find(main, first) -1 ) 
	
	local temp = string.sub(main, string.find(main, first) + #first)
	relapsed = relapsed .. second .. temp
	
	while string.find(relapsed, first) do
		temp = string.sub(relapsed, string.find(relapsed, first) + #first)
		relapsed = string.sub(relapsed, 1, string.find(relapsed, first) -1 )
		
		relapsed = relapsed .. second .. temp
	end
	
	return relapsed
end

function getpage(url)
	local http = require("socket.http") -- this is included with luasocket
	local page = {}
	local page, status = http.request(url) -- 1 = body, 2 = status?
	if verbose then print(page, status) end
	return page
end

-- process needs to process "line" and call higher bot tasks
function process(s, channel, lnick, line) --!! , nick, host
	for key, val in pairs(memo) do
		if key == lnick then
			msg(s, channel, lnick .. ": " .. val)
			memo[lnick] = nil -- remove the memo
		end
	end
	-- woot
	if string.find(line, "!woot") then
		local page = getpage("http://www.woot.com/")
		for line in string.gmatch(page, "[^\r\n]+") do
			if string.find(line, "<h2 class=\"fn\">") then
				local name = string.sub(line, string.find(line, "\">")+2, string.find(line, "</")-1)
				msg(s, channel, "the woot item of the day is " .. name)
			end
			if string.find(line, "<span class=\"amount\">") then
				local price = string.sub(line, (string.find(line, "\"amount")+9), (string.find(line, "</span")-1))
				msg(s, channel, "this item is selling for: " .. price)
			end
		end
	end
	-- add memo for users
	if string.find(line, "!memo ") then
		local nick = string.sub(line, string.find(line, "!memo ")+6, #line)
		nick = string.sub(nick, 1, string.find(nick, " ")-1)
		local message = string.sub(line, string.find(line, nick)+#nick+1, #line)
		local found = false
		for key, val in pairs(memo) do
			if key == nick then found = true end
		end
		if not found then memo[nick] = "<" .. lnick .. "> " .. message end
	end
	-- automatically detects http
	if string.find(line, "http://") then
		local request = string.sub(line, string.find(line, "http://"), #line)
		if string.find(request, " ") then 
			request = string.sub(request, 1, (string.find(request, " ")-1))
		end
		
		local page = getpage(request)

		for lin in string.gmatch(page, lineregex) do
			if string.find(lin, "<title>") then

				if #lin < string.find(lin, "<title>")+8 then
					msg(s, channel, "[!] no support for \"youtube-style\" urls yet, sorry")
				else
					local title = string.sub(lin, (string.find(lin, "<title>")+7), (string.find(lin, "</title")-1))
					msg(s, channel, title)
				end -- !! TODO: add support for "youtube-stye" <title> scheme (nextline)
			end
		end
	end
	-- respond to action
	if string.find(line, "ACTION") and string.find(line, "subz3ro") then -- !! globalize nick
		--lol
		msg(s, channel, "ima drop kick " .. lnick .. " in about ten seconds")
	end
	
	-- fatwallet search
	if string.find(line, "!fws") then
		local search = " "
		local count = 0
		if #line >= line:find("!fws")+5 then
		search = line:sub(line:find("!fws ")+4, #line)
		end
		local page = getpage("http://feeds.feedburner.com/FatwalletHotDeals.html")
		for line in page:gmatch("[^\r\n]+") do
			local lline = line:lower()
			if line:find('title><') and line:find("CDATA") and lline:find(search:lower()) and count < 5 then
				msg(s, channel, line:sub(line:find("title><")+15, #line-14))
				count = count + 1
			end
		end
	end
	
	-- adds users to the sync table
	if string.find(line, "!sync") then
		if sync(lnick) then
			msg(s, channel, lnick .. ": added you to to the sync table")
		else msg(s, channel, lnick .. ": you are already on the list!") end
	end
	-- grab weather from weather underground
	if string.find(line, "!temp") then
		local zip = string.sub(line, (string.find(line, "!temp ") + 6))
		local query = zip
		if string.find(zip, " ") then query = repspace(zip, ' ', '%20') end
		--msg(s, channel, "getting weather for " .. query)
		local page = getpage("http://www.wunderground.com/cgi-bin/findweather/getForecast?query=" .. query .. "&wuSelect=WEATHER")
		for bline in string.gmatch(page, lineregex) do
			if string.find(bline, "tempf") then
				msg(s, channel, lnick .. ": the current temperature is " .. string.sub(bline, string.find(bline, "value") + 7, #bline -4) .. "F")
				msg(s, channel, lnick .. ": forecast info: http://wolframalpha.com/input/?i=forecast+" .. query)
				return
			end
		end
	end
	if string.find(line, "!host ") then
		local host = string.sub(line, string.find(line, "!host ")+6)
		if string.find(host, " ") then
			host = string.sub(host, 1, string.find(host, " "))
		end
		
		local f = io.popen("host " .. host)
		local ret = f:read("*l")
		msg(s, channel, ret)

	end
	if string.find(line, "!help") then
		local com = {}
		com[#com + 1] = "Lua IRC Bot -- by dshaw"
		com[#com + 1] = "--- Help and Usage ---"
		com[#com + 1] = "[Automatic] -- URL titles are automatically announced to channel"
		com[#com + 1] = "!sync -- join an ongoing \"sync\" session"
		com[#com + 1] = "!start -- start a ready \"sync\" session"
		com[#com + 1] = "!whatis <query> -- returns a Google definition for <query>"
		com[#com + 1] = "!temp <zip code or city name, state>"
		com[#com + 1] = "!fws <query> -- searches FatWallet Hot Deals for <query>"
		com[#com + 1] = "!woot -- returns the woot.com deal of the day and price"
		com[#com + 1] = "!memo <nick> <message> -- relays your <message> to <nick> the next time they speak."
		com[#com + 1] = "!sunset <zip> -- fetches today's sunset time"
		for x=1, #com do
			msg(s, channel, com[x])
		end
	end
	-- starts the countdown and clears the sync table
	if string.find(line, "!start") then
		for x=1, (#list) do
			msg(s, channel, list[x] .. ": the time has come!")
		end
		for y=3, 1, -1 do
			msg(s, channel, "starting in " .. y)
			os.execute("sleep 1")
		end
		
		msg(s, channel, "--- SYNC ---")
		list = {}
	end
	-- google whatis
	if string.find(line, "!whatis") then
		-- find the query
		-- !! function findparam(line, functionname)   VVVVVVVVVVVVVVVVVV
		local query = string.sub(line, (string.find(line, "!whatis") + 8))
		local page = getpage('http://www.google.com/search?q=define%3A' .. query)
		for line in string.gmatch(page, lineregex) do
			if string.find(line, "disc") then
				local answer = string.sub(line, (string.find(line, "disc") + 20) )
				local ret = string.sub(answer, 1, (string.find(answer, "<")-1))
				if ret:find("&quot;") then 
					ret = repspace(ret, "&quot;", '"')
				end
				msg(s, channel, ret)
			end
		end
	end
	if string.find(line, "!sunset") then
		local query = string.sub(line, (string.find(line, "!sunset") + 8))
		local page = getpage('http://www.google.com/search?q=sunset+' .. query)
		for line in string.gmatch(page, lineregex) do
			if string.find(line, '<td class="r">') then
				local answer= string.sub(line, (string.find(line, '<td class="r">') + 26), #line)
				local ret = answer:sub(1, (answer:find('<')-1))
				msg(s, channel, ret)
			end
		end
	end
	-- returns system uptime
	if string.find(line, "!uptime") then
		local f = io.popen("uptime")
		msg(s, channel, lnick .. ":" .. f:read("*l"))
	end
end

-- config
-- !! should take cli args 
local serv = arg[1]
local nick = arg[2]
local channel = "#" .. arg[3]
local verbose = false
local welcomemsg = "**chhckkk** Lua Bot has arrived."

-- connect
print("[+] setting up socket...")
s = socket.tcp()
s:connect(socket.dns.toip(serv), 6667) -- !! add more support later; ssl?

-- initial setup

-- !! function-ize
print("[+] trying nick", nick)
s:send("USER " .. nick .. " " .. " " .. nick .. " " ..  nick .. " " .. ":" .. nick .. "\r\n\r\n")
s:send("NICK " .. nick .. "\r\n\r\n")
print("[+] joining", channel)
s:send("JOIN " .. channel .. "\r\n\r\n")


if welcomemsg then msg(s, channel, welcomemsg) end

-- the guts of the script -- parses out input and processes
while true do
	-- just grab one line ("*l")
	receive = s:receive('*l')
	
	-- gotta grab the ping "sequence".
	if string.find(receive, "PING :") then
		s:send("PONG :" .. string.sub(receive, (string.find(receive, "PING :") + 6)) .. "\r\n\r\n")
		if verbose then print("[+] sent server pong") end
	else
		-- is this a message?
		if string.find(receive, "PRIVMSG") then
			if verbose then msg(s, channel, receive) end
			line = string.sub(receive, (string.find(receive, channel .. " :") + (#channel) + 2))
			lnick = string.sub(receive, (string.find(receive, ":")+1), (string.find(receive, "!")-1))
			-- !! add support for multiple channels (lchannel)
			process(s, channel, lnick, line)
		end		
	end
	-- verbose flag sees everything
	if verbose then print(receive) end
end

-- fin!