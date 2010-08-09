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

require "socket"

-- definitions for use later in the script
function deliver(s, content)
	s:send(content .. "\r\n\r\n")
end

function msg(s, channel, content)
	deliver(s, "PRIVMSG " .. channel .. " :" .. content)
end

-- process needs to process "line" and call higher bot tasks
-- !! should take more than line, eg, nick, host (memos)
function process(s, channel, line) --!! , nick, host
	if string.find(line, "!test") then
		msg(s, channel, "WHOA BUDDY WHAT IS THIS DEBUG FANTASY LAND?")
	end
	if string.find(line, "!uptime") then
		local f = io.popen("uptime")
		msg(s, channel, f:read("*l"))
	end
end

-- config
-- !! should take cli args 
local serv = "madjack.2600.net"
local nick = "b0t[lua]"
local channel = "#botest"
local verbose = false

-- connect
print("[+] setting up socket...")
s = socket.tcp()
s:connect(socket.dns.toip(serv), 6667) -- !! add more support later

-- initial setup
print("[+] trying", nick)
s:send("USER " .. nick .. " " .. " " .. nick .. " " ..  nick .. " " .. ":" .. nick .. "\r\n\r\n")
s:send("NICK " .. nick .. "\r\n\r\n")
print("[+] joining", channel)
s:send("JOIN " .. channel .. "\r\n\r\n")

-- !! default message perhaps?
msg(s, channel, "Hello, humans. I am here to serve you.")

-- the guts of the script -- parses out input and processes
while true do
	receive = s:receive('*l')
	-- gotta grab the ping "sequence".
	if string.find(receive, "PING :") then
		s:send("PONG :" .. string.sub(receive, (string.find(receive, "PING :") + 6)) .. "\r\n\r\n")
		-- !! should make this verbose?
		print(" [+] sent server pong")
	else
		-- is this a message?
		if string.find(receive, "PRIVMSG") then
			if verbose then msg(s, channel, receive) end
			line = string.sub(receive, (string.find(receive, channel .. " :") + (#channel) + 2))
			lnick = string.sub(receive, (string.find(receive, ":")+1), (string.find(receive, "!")-1))
			-- !! add support for multiple channels (lchannel)
			process(s, channel, line)
		end		
	end
	
	-- verbose flag sees everything
	if verbose then print(receive) end
end

-- fin!