-- use xrandr command to set output to best fitting fps rate
--  when playing videos with mpv.

xrandr_verbose = true


utils = require 'mp.utils'

function xrandr_log(level, msg)
	if (xrandr_verbose) then
		mp.msg.log(level, msg)
	end
end

xrandr_detect_done = false
xrandr_connected = ""
xrandr_mode = ""
xrandr_rates = {}
function xrandr_detect_available_rates()
	if (xrandr_detect_done) then
		return
	end
	xrandr_detect_done = true
	
	-- invoke xrandr to find out which fps rates are available on the currently used output
	
	local p = {}
	p["cancellable"] = "false"
	p["args"] = {}
	p["args"][1] = "xrandr"
	p["args"][2] = "-q"
	local res = utils.subprocess(p)
	
	if (res["error"] ~= nil) then
		xrandr_log("info", "failed to execute 'xrand -q', error message: " .. res["error"])
		return
	end
	
	xrandr_log("info","xrandr -q\n" .. res["stdout"])

	xrandr_connected = string.match(res["stdout"], '\n([^ ]+) connected')
	mp.msg.log("info","output connected:             " .. xrandr_connected)
	
	local r
	xrandr_mode, r = string.match(res["stdout"], '\n   ([0-9x]+) ([^*\n]*%*[^*\n]*)')
	
	mp.msg.log("info","output resolution mode is:    " .. xrandr_mode)
	mp.msg.log("info","available output frame rates: " .. r)
	
	xrandr_rates = {}
	local i = 0
	for s in string.gmatch(r, "([^ +*]+)") do
		-- xrandr_log("info","rate=" .. s)
		xrandr_rates[i] = 0.0 + s
		i = i+1
	end
end

function xrandr_find_best_fitting_rate(fps)
	xrandr_detect_available_rates()
	
	-- try integer multipliers of 1 to 3, in that order
	for m=1,3 do
		
		-- check for a "perfect" match (where fps rats of 60.0 are not equal 59.9 or such)
		for i=0,#xrandr_rates do
			r = xrandr_rates[i]
			if (math.abs(r-(m * fps)) < 0.001) then
				return r
			end
		end
		
	end

	for m=1,3 do
		
		-- check for a "less" match (where fps rats of 60.0 and 59.9 are assumed "equal")
		for i=0,#xrandr_rates do
			r = xrandr_rates[i]
			if (math.abs(r-(m * fps)) < 0.2) then
				if (m == 1) then
					-- pass the original rate to xrandr later, because
					-- e.g. a 23.976 Hz mode might be displayed as "24.0",
					-- but still xrandr may set the better matching mode
					-- if the exact number is passed
					return fps
				else
					return r
				end
				
			end
		end
		
	end
	
	-- if no known frame rate is any "good", use the highest available frame rate,
	-- as this will probably cause the least "jitter"

	local mr = 0.0
	for i=0,#xrandr_rates do
		r = xrandr_rates[i]
		-- xrandr_log("info","r=" .. r .. " mr=" .. mr)
		if (r > mr) then
			mr = r
		end
	end	
	
	return mr	
end


xrandr_cfps = nil
function xrandr_set_rate()

	local f = mp.get_property_native("fps")
	if (f == nil or f == xrandr_cfps) then
		-- either no change or no frame rate information
		return
	end
	xrandr_cfps = f
	
	local vdpau_hack = false
	local old_vid = nil
	local old_position = nil
	
	if (mp.get_property("options/vo") == "vdpau") then
		-- enable wild hack: need to close and re-open video for vdpau,
		-- because vdpau barfs if xrandr is run while it is in use
		
		vdpau_hack = true
		old_position = mp.get_property("time-pos")
		old_vid = mp.get_property("vid")
		mp.set_property("vid", "no")
	end
		
	xrandr_log("info", "container fps == " .. xrandr_cfps .." - will try to adust output fps rate via xrandr")
		
	local bfr = xrandr_find_best_fitting_rate(xrandr_cfps)
	
	mp.msg.log("info", "container fps=" .. xrandr_cfps .. "Hz, best fitting display fps rate=" .. bfr .. "Hz")
	
	-- invoke xrandr to find out which fps rates are available on the currently used output
	
	local p = {}
	p["args"] = {}
	p["args"]["cancellable"] = "false"
	p["args"][1] = "xrandr"
	p["args"][2] = "--output"
	p["args"][3] = xrandr_connected
	p["args"][4] = "--mode"
	p["args"][5] = xrandr_mode
	p["args"][6] = "--rate"
	p["args"][7] = bfr

	local res = utils.subprocess(p)

	if (res["error"] ~= nil) then
		xrandr_log("info", "failed to set display fps rate using xrandr, error message: " .. res["error"])
		return
	end
	
	if (vdpau_hack) then
		mp.set_property("vid", old_vid)
		mp.commandv("seek", old_position, "absolute", "keyframes")
	end
end

mp.observe_property("fps", "native", xrandr_set_rate)



