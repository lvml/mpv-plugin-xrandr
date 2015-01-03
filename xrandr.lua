-- use xrandr command to set output to best fitting fps rate
--  when playing videos with mpv.

xrandr_verbose = false


utils = require 'mp.utils'

function xrandr_log(level, msg)
	-- if (xrandr_verbose) then
		mp.msg.log(level, msg)
	-- end
end

xrandr_detect_done = false
xrandr_modes = {}
xrandr_connected_outputs = {}
function xrandr_detect_available_rates()
	if (xrandr_detect_done) then
		return
	end
	xrandr_detect_done = true
	
	-- invoke xrandr to find out which fps rates are available on which outputs
	
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
	
	xrandr_log("v","xrandr -q\n" .. res["stdout"])

	local output_idx = 1
	for output in string.gmatch(res["stdout"], '\n([^ ]+) connected') do
		
		table.insert(xrandr_connected_outputs, output)
		
		-- the first line with a "*" after the match contains the mode associated with the mode
		local mls = string.match(res["stdout"], "\n" .. string.gsub(output, "%p", "%%%1") .. " connected.*")
		local r
		local mode
		mode, r = string.match(mls, '\n   ([0-9x]+) ([^*\n]*%*[^*\n]*)')

		mp.msg.log("info", "output " .. output .. " mode=" .. mode .. " refresh rates = " .. r)
		
		xrandr_modes[output] = { mode = mode, rates_s = r, rates = {} }
		local i = 1
		for s in string.gmatch(r, "([^ +*]+)") do
			xrandr_modes[output].rates[i] = 0.0 + s
			i = i+1
		end
		
		output_idx = output_idx + 1
	end
	
end

function xrandr_find_best_fitting_rate(fps, output)
	
	local xrandr_rates = xrandr_modes[output].rates
	
	-- try integer multipliers of 1 to 3, in that order
	for m=1,3 do
		
		-- check for a "perfect" match (where fps rats of 60.0 are not equal 59.9 or such)
		for i=1,#xrandr_rates do
			r = xrandr_rates[i]
			if (math.abs(r-(m * fps)) < 0.001) then
				return r
			end
		end
		
	end

	for m=1,3 do
		
		-- check for a "less" match (where fps rats of 60.0 and 59.9 are assumed "equal")
		for i=1,#xrandr_rates do
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
	for i=1,#xrandr_rates do
		r = xrandr_rates[i]
		-- xrandr_log("v","r=" .. r .. " mr=" .. mr)
		if (r > mr) then
			mr = r
		end
	end	
	
	return mr	
end


xrandr_active_outputs = {}
function xrandr_set_active_outputs()
	local dn = mp.get_property("display-names")
	
	if (dn ~= nil) then
		mp.msg.log("v","display-names=" .. dn)
		xrandr_active_outputs = {}
		for w in (dn .. ","):gmatch("([^,]*),") do 
			table.insert(xrandr_active_outputs, w)
		end
	end
end

xrandr_cfps = nil
function xrandr_set_rate()

	local f = mp.get_property_native("fps")
	if (f == nil or f == xrandr_cfps) then
		-- either no change or no frame rate information
		return
	end
	xrandr_cfps = f

	xrandr_detect_available_rates()
	
	xrandr_set_active_outputs()
	
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
	
	local outs = {}
	if (#xrandr_active_outputs == 0) then
		-- No active outputs - probably because vo (like with vdpau) does
		-- not provide the information which outputs are covered.
		-- As a fall-back, let's assume all connected outputs are relevant.
		mp.msg.log("v","no output is known to be used by mpv, assuming all connected outputs are used.")
		outs = xrandr_connected_outputs
	else
		outs = xrandr_active_outputs
	end
		
	-- iterate over all outputs that are currently used my mpv's output:
	for n, output in ipairs(outs) do

		local bfr = xrandr_find_best_fitting_rate(xrandr_cfps, output)
	
		mp.msg.log("info", "container fps is " .. xrandr_cfps .. "Hz, for output " .. output .. " mode " .. xrandr_modes[output].mode .. " the best fitting display fps rate is " .. bfr .. "Hz")
	
		-- invoke xrandr to find out which fps rates are available on the currently used output
		
		local p = {}
		p["cancellable"] = "false"
		p["args"] = {}
		p["args"][1] = "xrandr"
		p["args"][2] = "--output"
		p["args"][3] = output
		p["args"][4] = "--mode"
		p["args"][5] = xrandr_modes[output].mode
		p["args"][6] = "--rate"
		p["args"][7] = bfr
		
		local res = utils.subprocess(p)
	
		if (res["error"] ~= nil) then
			mp.msg.log("error", "failed to set display fps rate for output " .. output .. " using xrandr, error message: " .. res["error"])
		end
	end
	
	if (vdpau_hack) then
		mp.set_property("vid", old_vid)
		mp.commandv("seek", old_position, "absolute", "keyframes")
	end
end
mp.observe_property("fps", "native", xrandr_set_rate)

