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
	xrandr_mode, r = string.match(res["stdout"], '\n   ([0-9x]+) ([^*\n]*\*[^*\n]*)')
	
	mp.msg.log("info","output resolution mode is:    " .. xrandr_mode)
	mp.msg.log("info","available output frame rates: " .. r)
	
	xrandr_rates = {}
	local i = 0
	for s in string.gfind(r, "([^ +*]+)") do
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
		for i=0,table.getn(xrandr_rates) do
			r = xrandr_rates[i]
			if (math.abs(r-(m * fps)) < 0.001) then
				return r
			end
		end
		
	end

	for m=1,3 do
		
		-- check for a "less" match (where fps rats of 60.0 and 59.9 are assumed "equal")
		for i=0,table.getn(xrandr_rates) do
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
	for i=0,table.getn(xrandr_rates) do
		r = xrandr_rates[i]
		-- xrandr_log("info","r=" .. r .. " mr=" .. mr)
		if (r > mr) then
			mr = r
		end
	end	
	
	return mr	
end


function xrandr_set_rate()
	
	local cfps = mp.get_property_native("fps")
	if (cfps == nil) then
		xrandr_log("info", "container fps property == nil - will not try to adust output fps rate")
		return
	end
	
	xrandr_log("info", "container fps == " .. cfps .." - will try to adust output fps rate via xrandr")
	
	mp.suspend()
	
	local bfr = xrandr_find_best_fitting_rate(cfps)
	
	xrandr_log("info", "container fps=" .. cfps .. "Hz, best fitting display fps rate=" .. bfr .. "Hz")
	
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

	-- utils.subprocess() documentation says it implies "mp.resume_all()"...
	-- mp.resume()
	
	if (res["error"] ~= nil) then
		xrandr_log("info", "failed to set display fps rate using xrandr, error message: " .. res["error"])
		return
	end

end
mp.observe_property("fps", "native", xrandr_set_rate)



