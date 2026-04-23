_addon.name = 'closetCleaner'
_addon.version = '0.8'
_addon.author = 'Brimstone, Gol-Exe'
_addon.commands = {'cc','closetCleaner'}

if windower.file_exists(windower.addon_path..'data/bootstrap.lua') then
    debugging = {windower_debug = true,command_registry = false,general=false,logging=false}
else
    debugging = {}
end

__raw = {lower = string.lower, upper = string.upper, debug=windower.debug,text={create=windower.text.create,
    delete=windower.text.delete,registry = {}},prim={create=windower.prim.create,delete=windower.prim.delete,registry={}}}


language = 'english'
file = require 'files'
require 'strings'
require 'tables'
require 'logger'
-- Restore the normal error function (logger changes it)
error = _raw.error

require 'lists'
require 'sets'


windower.text.create = function (str)
    if __raw.text.registry[str] then
        msg.addon_msg(123,'Text object cannot be created because it already exists.')
    else
        __raw.text.registry[str] = true
        __raw.text.create(str)
    end
end

windower.text.delete = function (str)
    if __raw.text.registry[str] then
        local library = false
        if windower.text.saved_texts then
            for i,v in pairs(windower.text.saved_texts) do
                if v._name == str then
                    __raw.text.registry[str] = nil
                    windower.text.saved_texts[i]:destroy()
                    library = true
                    break
                end
            end
        end
        if not library then
            -- Text was not created through the library, so delete it normally
            __raw.text.registry[str] = nil
            __raw.text.delete(str)
        end
    else
        __raw.text.delete(str)
    end
end

windower.prim.create = function (str)
    if __raw.prim.registry[str] then
        msg.addon_msg(123,'Primitive cannot be created because it already exists.')
    else
        __raw.prim.registry[str] = true
        __raw.prim.create(str)
    end
end

windower.prim.delete = function (str)
    if __raw.prim.registry[str] then
        __raw.prim.registry[str] = nil
        __raw.prim.delete(str)
    else
        __raw.prim.delete(str)
    end
end

texts = require 'texts'
require 'pack'
bit = require 'bit'
socket = require 'socket'
mime = require 'mime'
res = require 'resources'
extdata = require 'extdata'
require 'helper_functions'
require 'actions'
packets = require 'packets'
gearswap = {}
user_env = {}
-- Resources Checks
if res.items and res.bags and res.slots and res.statuses and res.jobs and res.elements and res.skills and res.buffs and res.spells and res.job_abilities and res.weapon_skills and res.monster_abilities and res.action_messages and res.skills and res.monstrosity and res.weather and res.moon_phases and res.races then
else
    error('Missing resources!')
end

require 'packet_parsing'
require 'statics'
require 'equip_processing'
require 'targets'
require 'user_functions'
require 'refresh'
require 'export'
require 'validate'
require 'flow'
require 'triggers'

-- initialize_packet_parsing()
gearswap_disabled = false

windower.register_event('load',function()
    windower.debug('load')
    refresh_globals()
    
    if world.logged_in then
        refresh_user_env()
        if debugging.general then windower.send_command('@unload spellcast;') end
    end
end)

windower.register_event('unload',function ()
    windower.debug('unload')
    user_pcall('file_unload')
    if logging then logfile:close() end
end)

function table_invert(t)
	local s={}
	for k,v in pairs(t) do	
		s[v]=k
	end
	return s
end

windower.register_event('addon command',function (...)
    windower.debug('addon command')
    local splitup = {...}
    if not splitup[1] then return end -- handles //cu
    
    for i,v in pairs(splitup) do splitup[i] = windower.from_shift_jis(windower.convert_auto_trans(v)) end

    local cmd = table.remove(splitup,1):lower()
	
	-- create file
	if not windower.dir_exists(windower.addon_path..'report') then
        windower.create_dir(windower.addon_path..'report')
    end
	local path = windower.addon_path..'report/'..player.name
    -- path = path..os.date(' %H %M %S%p  %y-%d-%m')
	-- if (not overwrite_existing) and windower.file_exists(path..'.lua') then
		-- path = path..' '..os.clock()
	-- end
	
	if not itemsByName then
		itemsBylongName = T{}
		itemsByName = T{}
		for k,v in pairs(res.items) do
			itemsBylongName[v.enl:lower()] = k
			itemsByName[v.en:lower()] = k
		end
		collectgarbage('collect')
	end
	inventoryGear = T{}
	gsGear = T{}
    
	-- require 'ccConfig'
    if cmd == 'report' then
		require 'ccConfig'
        run_report(path)
    elseif strip(cmd) == 'help' then
        print('closetCleaner: Valid commands are:')
        print(' report  : Generates full usage report closetCleaner/report/<playername>_report.txt.')
    else
		print('checkusage: Command not found')
    end
end)

function export_inv(path)
	if ccDebug then
		reportName = path..'_inventory.txt'
		finv = io.open(reportName,'w+')
		finv:write('closetCleaner Inventory Report:\n')
		finv:write('=====================\n\n')
	end
		
	local item_list = T{}
	checkbag = true 
	for n = 0, #res.bags do
		if not skipBags:contains(res.bags[n].english) then
			for i,v in ipairs(get_item_list(items[res.bags[n].english:gsub(' ', ''):lower()])) do
				if v.name ~= empty then
					local slot = xmlify(tostring(v.slot))
					local name = xmlify(tostring(v.name)):gsub('NUM1','1')
					
					local inv_id = itemsByName[name:lower()] or itemsBylongName[name:lower()]
					if inv_id == nil then
						print("Item: "..name.." not found in resources!")
					end
					if ccDebug then
						finv:write("Name: "..name.." Slot: "..slot.." Bag: "..res.bags[n].english.."\n")
					end
					if inv_id ~= nil then
						if inventoryGear[inv_id] == nil then 
							inventoryGear[inv_id] = res.bags[n].english
						else
							inventoryGear[inv_id] = inventoryGear[inv_id]..", "..res.bags[n].english
						end
					end
				end
			end
		end
	end
	if ccDebug then
		finv:close()
		print("File created: "..reportName)
	end
end

-- Built once per extract_sets(): basename (lowercase, no .lua) -> full path (first root wins).
local libs_include_index = nil

local function normalize_path_slashes(p)
	if type(p) ~= 'string' then
		return ''
	end
	return (p:gsub('\\', '/'):gsub('/+', '/'))
end

local function normalize_addon_path()
	local ap = normalize_path_slashes(windower.addon_path)
	if ap:sub(-1) ~= '/' then
		ap = ap .. '/'
	end
	return ap
end

-- Prepend so Sel/Mote job files can require() modules shipped under GearSwap or closetCleaner libs (e.g. Snaps-RngHelper.lua).
local function cc_gearswap_require_path_prefix()
	local parts = {}
	local function add_libs_subdir(base)
		base = normalize_path_slashes(base)
		if base == '' then
			return
		end
		if base:sub(-1) ~= '/' then
			base = base .. '/'
		end
		parts[#parts + 1] = base .. '?.lua'
	end
	if type(gspath) == 'string' and gspath ~= '' then
		add_libs_subdir(gspath .. 'libs-dev')
		add_libs_subdir(gspath .. 'libs')
	end
	add_libs_subdir(normalize_addon_path() .. 'libs')
	return table.concat(parts, ';') .. ';'
end

-- GearSwap libs roots, same spirit as gearswap.pathsearch (libs-dev overrides libs).
local function closetCleaner_libs_roots()
	local roots = {}
	if type(gspath) == 'string' and gspath ~= '' then
		roots[#roots + 1] = gspath .. 'libs-dev/'
		roots[#roots + 1] = gspath .. 'libs/'
	end
	roots[#roots + 1] = normalize_addon_path() .. 'libs/'
	return roots
end

local function lib_token(s)
	return (s or ''):lower():gsub('%.lua$', '')
end

local function lib_names_match(requested, filename)
	return lib_token(requested) == lib_token(filename)
end

-- Max .lua files per libs folder; avoids huge allocations if a path points at the wrong directory.
local libs_scan_max_files = 400

-- List *.lua basenames in a directory (prefer lfs; avoid io.popen — heavy and unstable in some clients).
local function list_lua_files_in_dir(dir)
	if not dir or dir == '' or not windower.dir_exists(dir) then
		return {}
	end
	local t = {}
	local ok_lfs, lfs = pcall(require, 'lfs')
	if ok_lfs and lfs and lfs.dir then
		for fn in lfs.dir(dir) do
			if fn ~= '.' and fn ~= '..' and type(fn) == 'string' and fn:lower():match('%.lua$') then
				t[#t + 1] = fn
				if #t > libs_scan_max_files then
					windower.add_to_chat(8, 'closetCleaner: libs folder "' .. dir .. '" has too many .lua files; ignoring scan (max ' .. libs_scan_max_files .. ')')
					return {}
				end
			end
		end
		return t
	end
	local norm = dir:gsub('/', '\\')
	if norm:sub(-1) == '\\' then
		norm = norm:sub(1, -2)
	end
	local fh = io.popen(string.format('cmd /c dir /b "%s\\*.lua" 2>nul', norm))
	if fh then
		for line in fh:lines() do
			line = line:gsub('\r', '')
			if line ~= '' then
				t[#t + 1] = line
				if #t > libs_scan_max_files then
					windower.add_to_chat(8, 'closetCleaner: libs folder "' .. dir .. '" has too many .lua files; ignoring scan (max ' .. libs_scan_max_files .. ')')
					fh:close()
					return {}
				end
			end
		end
		fh:close()
	end
	return t
end

local function closetCleaner_build_libs_include_index()
	libs_include_index = {}
	for _, root in ipairs(closetCleaner_libs_roots()) do
		local names = list_lua_files_in_dir(root)
		for _, name in ipairs(names) do
			local tok = lib_token(name)
			if tok ~= '' and libs_include_index[tok] == nil then
				libs_include_index[tok] = root .. name
			end
		end
	end
end

-- Runs chunk if path exists; returns ok, chunk_return_values (same as loadfile/dofile contract).
local function try_dofile(path)
	if path and windower.file_exists(path) then
		return true, dofile(path)
	end
	return false
end

-- Resolve include name against libs roots: exact path, then index lookup (built once per extract_sets).
local function include_from_libs_roots(f)
	for _, root in ipairs(closetCleaner_libs_roots()) do
		local ok, ret = try_dofile(root .. f)
		if ok then
			return ret
		end
		ok, ret = try_dofile(root .. f .. '.lua')
		if ok then
			return ret
		end
	end
	if libs_include_index == nil then
		closetCleaner_build_libs_include_index()
	end
	local path = libs_include_index[lib_token(f)]
	if path and windower.file_exists(path) then
		return dofile(path)
	end
	return nil
end

-- Stub matches GearSwap: return value from included chunk (e.g. Snaps-Rnghelper_Config.lua returns config).
function include(f)
	local org_key = type(f) == 'string' and f:lower():gsub('%.lua$', '') or ''
	if org_key == 'organizer-lib' then
		return
	end
	local ok, ret
	ok, ret = try_dofile(f)
	if ok then
		return ret
	end
	if type(gspath) == 'string' and gspath ~= '' then
		ok, ret = try_dofile(gspath .. f)
		if ok then
			return ret
		end
	end
	mf = gearswap.pathsearch({f})
	if mf and windower.file_exists(mf) then
		return dofile(mf)
	end
	return include_from_libs_roots(f)
end

-- Ensure common GearSwap/Mote/Sel subtables exist so init_gear_sets can assign nested keys
-- without "attempt to index field '…' (a nil value)". Informed by reference luas under data/.
function ensure_gear_sets_baseline(s)
	if type(s) ~= 'table' then
		return
	end
	if s.precast == nil then s.precast = {} end
	if s.precast.FC == nil then s.precast.FC = {} end
	if s.precast.JA == nil then s.precast.JA = {} end
	if s.precast.WS == nil then s.precast.WS = {} end
	if s.precast.RA == nil then s.precast.RA = {} end
	if s.midcast == nil then s.midcast = {} end
	if s.midcast.RA == nil then s.midcast.RA = {} end
	if s.midcast.Pet == nil then s.midcast.Pet = {} end
	if s.idle == nil then s.idle = {} end
	if s.resting == nil then s.resting = {} end
	if s.engaged == nil then s.engaged = {} end
	if s.defense == nil then s.defense = {} end
	if s.buff == nil then s.buff = {} end
	-- Very common: set_combine(sets.buff.Doom, …) as first line of init_gear_sets.
	if s.buff.Doom == nil then s.buff.Doom = {} end
	if s.weapons == nil then s.weapons = {} end
	-- Sel-Include apply_passive uses sets.passive[...].
	if s.passive == nil then s.passive = {} end
	-- Mote-TreasureHunter / Sel jobs: set_combine(sets.TreasureHunter, …).
	if s.TreasureHunter == nil then s.TreasureHunter = {} end
	-- Sel crafting mode indexes sets.crafting[…].
	if s.crafting == nil then s.crafting = {} end
	-- SMN perpetuation sets (data/*/*_Smn_Gear.lua).
	if s.perp == nil then s.perp = {} end
	-- GEO/BLM style elemental wrapper tables.
	if s.element == nil then s.element = {} end
	-- Rare; some custom luas define aftercast sets.
	if s.aftercast == nil then s.aftercast = {} end
end

-- After Sel init, sets.passive is often {} with no per-mode entries; missing keys make set_combine(nil) fail.
local function ensure_sets_passive_merge_safe(s)
	if type(s) ~= 'table' or type(s.passive) ~= 'table' then
		return
	end
	if getmetatable(s.passive) ~= nil then
		return
	end
	setmetatable(s.passive, {
		__index = function()
			return {}
		end,
	})
end

-- Load one job Lua, populating the global `sets` table in-place.
-- Returns true on success so the caller can read `sets` directly (no deep copy).
function extract_sets(file)
	libs_include_index = nil
	if type(sets) ~= 'table' then
		sets = {}
	end
	ensure_gear_sets_baseline(sets)
	local load_ok, load_err = pcall(dofile, file)
	if not load_ok then
		windower.add_to_chat(8, 'closetCleaner: could not load '..tostring(file)..': '..tostring(load_err))
		return false
	end
	if type(sets) ~= 'table' then
		sets = {}
	end
	ensure_gear_sets_baseline(sets)
	local function run_gear_init()
		if get_sets ~= nil then
			get_sets()
		elseif init_gear_sets ~= nil then
			init_gear_sets()
		else
			windower.add_to_chat(8, 'closetCleaner: no init_gear_sets() or get_sets() in '..tostring(file))
		end
	end
	local init_ok, init_err = pcall(run_gear_init)
	if not init_ok then
		windower.add_to_chat(8, 'closetCleaner: gear init failed; retrying after baseline repair: '..tostring(init_err))
		ensure_gear_sets_baseline(sets)
		init_ok, init_err = pcall(run_gear_init)
		if not init_ok then
			windower.add_to_chat(8, 'closetCleaner: gear init failed again; keeping partial sets: '..tostring(init_err))
		end
	end
	ensure_sets_passive_merge_safe(sets)
	return true
end

function export_sets(path)
	local saved_package_path = package.path
	if ccDebug then
		reportName = path..'_sets.txt'
		fsets = io.open(reportName,'w+')
		fsets:write('closetCleaner sets Report:\n')
		fsets:write('=====================\n\n')
	end
		
	write_sets = T{}
	job_used = T{}
	job_logged = T()
	info = {}
	gear = {}
	gearswap.res = res
	
	fpath = string.lower(normalize_path_slashes(windower.addon_path))
	gspath = normalize_path_slashes(fpath:gsub('closetcleaner/', '') .. 'gearswap/')
	if gspath ~= '' and gspath:sub(-1) ~= '/' then
		gspath = gspath .. '/'
	end
	package.path = cc_gearswap_require_path_prefix() .. saved_package_path
	dpath = gspath .. 'data/'
	-- Resolve job file: data root first, then data/<character>/ for same names, then generic Job.lua at root.
	local function resolve_job_lua_path(job)
		local sub = dpath .. player.name .. '/'
		local candidates = {
			string.lower(dpath .. player.name .. '_' .. job .. '_gear.lua'),
			string.lower(dpath .. player.name .. '_' .. job .. '.lua'),
			-- Character folder: e.g. data/Smokey/Smokey_GEO_Gear.lua (then lowercase _gear fallback)
			string.lower(sub .. player.name .. '_' .. job .. '_Gear.lua'),
			string.lower(sub .. player.name .. '_' .. job .. '_gear.lua'),
			string.lower(sub .. player.name .. '_' .. job .. '.lua'),
			string.lower(dpath .. job .. '_gear.lua'),
			string.lower(dpath .. job .. '.lua'),
		}
		for _, p in ipairs(candidates) do
			if windower.file_exists(p) then
				return p
			end
		end
		return nil
	end
	-- Snapshot package.loaded so we can evict modules loaded by each job file.
	local base_loaded = {}
	for k in pairs(package.loaded) do base_loaded[k] = true end

	-- Stub coroutine.schedule so include files (e.g. Mirdain-Include) don't
	-- schedule delayed callbacks that fire after we nil out `sets`.
	local saved_coroutine_schedule = coroutine.schedule
	coroutine.schedule = function() end

	for i,v in ipairs(ccjobs) do
		sets = {}
		local loadpath = resolve_job_lua_path(v)
		if not loadpath then
			print('lua file for '..v..' not found!')
		end
		if loadpath then
			local ok, result = pcall(extract_sets, loadpath)
			if ok and result then
				list_sets(sets, fsets, true, v)
			elseif not ok then
				windower.add_to_chat(123, 'closetCleaner: failed to load '..v..' ('..loadpath..'): '..tostring(result))
			end
		end
		-- Release the sets graph and common globals job files define.
		sets = nil
		get_sets = nil
		init_gear_sets = nil
		job_setup = nil
		user_setup = nil
		-- Evict modules that this job file pulled in to free their tables.
		for k in pairs(package.loaded) do
			if not base_loaded[k] then
				package.loaded[k] = nil
			end
		end
		collectgarbage('collect')
	end
	
	coroutine.schedule = saved_coroutine_schedule

	libs_include_index = nil
	flush_write_sets_to_gsgear(fsets)
	if ccDebug then
		fsets:close()
		print("File created: "..reportName)
	end
	package.path = saved_package_path
end

-- If accumulate is true, merge into existing write_sets (export one job at a time to save memory).
-- default_job: ccjobs abbrev for this snapshot (avoids nil if tree omits a recognized job key).
function list_sets(t, f, accumulate, default_job)
	if not accumulate then
		write_sets = T{}
	end
	local visited = {}
	local job_abbr = S{'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN'}
	local gear_slots = S{'name', 'main', 'sub', 'range', 'ammo', 'head', 'neck', 'left_ear', 'right_ear', 'body', 'hands', 'left_ring', 'right_ring', 'back', 'waist', 'legs', 'feet', 'ear1', 'ear2', 'ring1', 'ring2', 'lear', 'rear', 'lring', 'rring'}
	local function sub_print_r(node, cur_job)
		if type(node) ~= 'table' then
			return
		end
		if visited[node] then
			return
		end
		visited[node] = true
		for pos, val in pairs(node) do
			local j = cur_job
			if job_abbr:contains(pos) then
				j = pos
			end
			if type(val) == 'table' then
				sub_print_r(val, j)
			elseif type(val) == 'string' then
				if val ~= '' and val ~= 'empty' then
					if gear_slots:contains(pos) then
						local resolved = itemsByName[val:lower()] or itemsBylongName[val:lower()]
						if resolved == nil then
							print("Item: '" .. val .. "' not found in resources! " .. tostring(pos))
						else
							itemid = resolved
							local jk = j or default_job or '?'
							if write_sets[itemid] == nil then
								write_sets[itemid] = 1
								if job_used[itemid] == nil then
									job_used[itemid] = jk
									job_logged[itemid .. jk] = 1
								else
									job_used[itemid] = job_used[itemid] .. ',' .. jk
									job_logged[itemid .. jk] = 1
								end
							else
								write_sets[itemid] = write_sets[itemid] + 1
								if job_logged[itemid .. jk] == nil then
									job_used[itemid] = job_used[itemid] .. ',' .. jk
									job_logged[itemid .. jk] = 1
								end
							end
						end
					end
				end
			else
				print('Error: Val needs to be table or string')
			end
		end
	end
	sub_print_r(t, default_job)
	if accumulate then
		return
	end
	if ccDebug then
		data = T{"Name", " | ", "Count", " | ", "Jobs", " | ", "Long Name"}
		form = T{"%22s", "%3s", "%10s", "%3s", "%88s", "%3s", "%60s"}
		print_row(f, data, form)
		print_break(f, form)
		f:write('\n')
		for k,v in pairs(write_sets) do
			data = T{res.items[k].en, " | ", tostring(v), " | ", job_used[k], " | ", res.items[k].enl}
			print_row(f, data, form)
			gsGear[k] = v
		end
		f:write()
	else
		for k,v in pairs(write_sets) do
			gsGear[k] = v
		end
	end
end

-- After incremental list_sets(..., true) calls, write debug file and fill gsGear.
function flush_write_sets_to_gsgear(f)
	if ccDebug then
		data = T{"Name", " | ", "Count", " | ", "Jobs", " | ", "Long Name"}
		form = T{"%22s", "%3s", "%10s", "%3s", "%88s", "%3s", "%60s"}
		print_row(f, data, form)
		print_break(f, form)
		f:write('\n')
		for k,v in pairs(write_sets) do
			data = T{res.items[k].en, " | ", tostring(v), " | ", job_used[k], " | ", res.items[k].enl}
			print_row(f, data, form)
			gsGear[k] = v
		end
		f:write()
	else
		for k,v in pairs(write_sets) do
			gsGear[k] = v
		end
	end
end

-- pass in file handle and a table of formats and table of data
function print_row(f, data, form)
	for k,v in pairs(data) do
		f:write(string.format(form[k], v))
	end
	f:write('\n')
end

-- pass in file handle and a table of formats and table of data
function print_break(f, form)
	for k,v in pairs(form) do
		number = string.match(v,"%d+")
		for i=1,number do
			f:write('-')
		end
		-- f:write(' ') -- can add characters to end here like spaces but subtract from number in the for loop above
	end
	f:write('\n')
end

function run_report(path)
	mainReportName = path..'_report.txt'
	local f = io.open(mainReportName,'w+')
	f:write('closetCleaner Report:\n')
	f:write('=====================\n\n')
	export_inv(path)
	export_sets(path)
	for k,v in pairs(inventoryGear) do
		if gsGear[k] == nil then
			gsGear[k] = 0
		end
	end
	data = T{"Name", " | ", "Count", " | ", "Location", " | ", "Jobs Used", " | ", "Long Name"}
	form = T{"%25s", "%3s", "%10s", "%3s", "%20s", "%3s", "%-88s", "%3s", "%60s"}
	print_row(f, data, form)
	print_break(f, form)
	if ccDebug then
		ignoredReportName = path..'_ignored.txt'
		f2 = io.open(ignoredReportName,'w+')
		f2:write('closetCleaner ignored Report:\n')
		f2:write('=====================\n\n')
		print_row(f2, data, form)
		print_break(f2, form)
	end
	for k,v in spairs(gsGear, function(t,a,b) return t[b] > t[a] end) do
		if ccmaxuse == nil or v <= ccmaxuse then
			printthis = 1
			if not job_used[k] then
				job_used[k] = " "
			end
			for i,s in ipairs(ccignore) do
				if string.match(res.items[k].en, s) or string.match(res.items[k].en, s) then
					printthis = nil
					if inventoryGear[k] == nil then
						data = T{res.items[k].en, " | ", tostring(v), " | ", "NOT FOUND", " | ", job_used[k], " | ", res.items[k].enl}
					else
						data = T{res.items[k].en, " | ", tostring(v), " | ", inventoryGear[k], " | ", job_used[k], " | ", res.items[k].enl}
					end
					if ccDebug then
						print_row(f2, data, form)
					end
					break
				end 
			end
			if printthis then
				if inventoryGear[k] == nil then
					data = T{res.items[k].en, " | ", tostring(v), " | ", "NOT FOUND", " | ", job_used[k], " | ", res.items[k].enl}
				else
					data = T{res.items[k].en, " | ", tostring(v), " | ", inventoryGear[k], " | ", job_used[k], " | ", res.items[k].enl}
				end
				print_row(f, data, form)
			end
		end
	end
	if ccDebug then
		f2:close()
		print("File created: "..ignoredReportName)
	end
	f:close()
	print("File created: "..mainReportName)
end

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function gearswap.pathsearch(files_list)

    -- base directory search order:
    -- windower
    -- %appdata%/Windower/GearSwap
    
    -- sub directory search order:
    -- libs-dev (only in windower addon path)
    -- libs (only in windower addon path)
    -- data/player.name
    -- data/common
    -- data
    
    local gearswap_data = gspath .. 'data/'
    local gearswap_appdata = (os.getenv('APPDATA') or '') .. '/Windower/GearSwap/'

    local search_path = {
        [1] = gspath .. 'libs-dev/',
        [2] = gspath .. 'libs/',
        [3] = gearswap_data .. player.name .. '/',
        [4] = gearswap_data .. 'common/',
        [5] = gearswap_data,
        [6] = gearswap_appdata .. player.name .. '/',
        [7] = gearswap_appdata .. 'common/',
        [8] = gearswap_appdata,
        [9] = windower.windower_path .. 'addons/libs/'
    }
    
    local user_path
    local normal_path

    for _,basepath in ipairs(search_path) do
        if windower.dir_exists(basepath) then
            for i,v in ipairs(files_list) do
                if v ~= '' then
                    if include_user_path then
                        user_path = basepath .. include_user_path .. '/' .. v
                    end
                    normal_path = basepath .. v
                    
                    if user_path and windower.file_exists(user_path) then
                        return user_path,basepath,v
                    elseif normal_path and windower.file_exists(normal_path) then
                        return normal_path,basepath,v
                    end
                end
            end
        end
    end
    
    return false
end

-- this function looks recursively through tables for a piece of gear  (currently unused)
function has_gear(tab, val)
	for index, value in pairs(tab) do
		if (type(value)=="table") then
			depth = depth + 1
			if has_gear(value, val, f) then
				return true
			end
		elseif value == val then
			return true
		end
	end
	return false
end


--dummy functions
function send_command(c)
	windower.send_command(c)
end

-- GearSwap hook for addon commands; not used when parsing sets for reports.
function register_unhandled_command(func)
end

function windower.register_event(c)
	return
end

function windower.raw_register_event(c)
	return
end