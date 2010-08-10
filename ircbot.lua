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
      
THIS SOFTWARE IS PROVIDED BY THE FREEBSD PROJECT ``AS IS'' AND ANY EXPRESS
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

require "socket" -- luasocket

-- globals
list = {}


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

-- process needs to process "line" and call higher bot tasks
function process(s, channel, lnick, line) --!! , nick, host
	-- adds users to the sync table
	if string.find(line, "!sync") then
		if sync(lnick) then
			msg(s, channel, lnick .. ": added you to to the sync table")
		else msg(s, channel, lnick .. ": you are already on the list!") end
	end
	-- starts the countdown and clears the sync table
	if string.find(line, "!start") then
		for x=1, (#list) do
			msg(s, channel, list[x] .. ": the time has come!")
		end
		for y=3, 1, -1 do
			msg(s, channel, "starting in " .. y)
			os.execute("sleep 1")
			list = {}
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
s:connect(socket.dns.toip(serv), 6667) -- !! add more support later

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