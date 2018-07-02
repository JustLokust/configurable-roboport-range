local zones = {}

local conf = require('config')
local utils = require('libs/utils')

local InitDone
local ChunkList, ChunkMap -- always up-to-date, existing chunks never removed
local ChunkSpreadQueue, ForestSet -- see control.lua for info on how sets are managed
local ChartLabels

local SpawnChanceCache


local cs = 32 -- chunk size, to name all "32" where it's that
local forest_radius = cs * 3 / 2 -- radius in which to look for forests, centered on chunk

local function area_chunk_xy(area)
	local left_top
	if area[1] then left_top = area[1] else left_top = area.left_top end
	return math.floor(left_top.x / cs), math.floor(left_top.y / cs)
end
local function pos_chunk_xy(pos)
	return math.floor(pos.x / cs), math.floor(pos.y / cs)
end

local function chunk_key(cx, cy)
	-- Returns 52-bit int key with chunk y in higher 26 bits, x in lower
	-- Not sure why math seem to break down when going for full 64-bit ints
	return bit32.band(cx, 67108863) -- cx & (2**26-1)
		+ bit32.band(cy, 67108863) * 67108864 end

local function replace_chunk(surface, cx, cy)
	local k = chunk_key(cx, cy)
	if not ChunkMap[k] then ChunkList[#ChunkList+1] = k end
	ChunkMap[k] = {cx=cx, cy=cy, surface=surface}
end


-- How wisps spawn on the map:
--
--  - Find and track all chunks via ChunkList/ChunkMap.
--    Done via refresh_chunks + reset_chunk in on_chunk_generated.
--
--  - Scan ChunkList & scan_spread for pollution values, add to ChunkSpreadQueue.
--    ChunkSpreadQueue is a queue of polluted areas where
--     wisps are most likely to appear, if there are any trees left.
--    Periodic update_wisp_spread task.
--
--  - Go through (check and remove) chunks in ChunkSpreadQueue & scan_trees,
--     scanning for tree count around these chunks' center.
--    As forests eat pollution, and their exact chunks might not show up there,
--     scanned areas are extended to cover some area around chunks as well.
--    Periodic update_forests_in_spread task.
--
--  - Weighted random from ForestSet by pollution-level in get_wisp_trees_anywhere.

function zones.update_wisp_spread(step, steps)
	local tick, out, k, chunk = game.tick, ChunkSpreadQueue
	local tick_max_spread = tick - conf.chunk_rescan_spread_interval
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval
	local count = 0
	for n = step, #ChunkList, steps do
		k, count = ChunkList[n], count + 1; chunk = ChunkMap[k]
		if chunk.spread
				or (chunk.scan_spread or 0) > tick_max_spread
			then goto skip end

		local pollution = chunk.surface.get_pollution{chunk.cx * cs, chunk.cy * cs}
		if pollution <= 0 then goto skip end
		chunk.pollution = pollution
		chunk.scan_spread = tick + utils.pick_jitter(conf.chunk_rescan_jitter)

		if not (
				chunk.spread or chunk.forest
				or (chunk.scan_trees or 0) > tick_max_trees ) then
			local m = out.n + 1
			chunk.spread, out.n, out[m] = true, m, k
		end
	::skip:: end
	return count -- get_pollution count, probably lite
end

function zones.update_forests_in_spread(step, steps)
	local tick, set, out = game.tick, ChunkSpreadQueue, ForestSet
	local tick_min_spread = tick - conf.chunk_rescan_spread_interval
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval
	local n, count, k, chunk, area, trees = step, 0
	if step > set.n and set.n > 0 then step = set.n end -- process at least one
	while n <= set.n do
		k, count = set[n], count + 1; chunk = ChunkMap[k]

		if not chunk then goto drop -- should not happen normally
		elseif (chunk.scan_spread or 0) < tick_min_spread
			then chunk.spread = nil; goto drop -- old spread data
		elseif (chunk.scan_trees or 0) > tick_max_trees then goto drop end

		area = utils.get_area(forest_radius, chunk.cx*cs + cs/2, chunk.cy*cs + cs/2)
		trees = chunk.surface.find_entities_filtered{type='tree', area=area}
		chunk.scan_trees = tick + utils.pick_jitter(conf.chunk_rescan_jitter)

		if #trees >= conf.wisp_forest_min_density then
			local m = out.n + 1
			chunk.forest, out.n, out[m] = true, m, {area=area, chunk_key=k}
			SpawnChanceCache = nil
		end

		::drop:: set[n], set.n, set[set.n] = set[set.n], set.n - 1
		n = n + steps - 1 -- 1 was dropped
	end
	return count -- find_entities_filtered count
end


local function get_forest_spawn_chances(pollution_factor)
	if SpawnChanceCache then return table.unpack(SpawnChanceCache) end
	local set, chances, chance_sum, p_max, chunk, p, n = ForestSet, {}, 0, 0
	if not pollution_factor
		then pollution_factor = conf.wisp_forest_spawn_pollution_factor end
	for n = 1, set.n do
		chunk = ChunkMap[set[n].chunk_key]
		p = chunk and chunk.pollution or 0
		chances[n] = p
		if p > p_max then p_max = p end
	end
	if p_max > 0 then
		for n = 1, #chances do
			p = 1 + pollution_factor * chances[n] / p_max
			chances[n], chance_sum = p, chance_sum + p
		end
	end
	SpawnChanceCache = {chances, chance_sum}
	return chances, chance_sum
end

function zones.get_wisp_trees_anywhere(count, pollution_factor)
	-- Return up to N random trees from same
	--  pollution-weighted-random forest_radius area for spawning wisps around.
	local set, wisp_trees, n, chunk, trees = ForestSet, {}
	if set.n == 0 then return wisp_trees end
	while set.n > 0 do
		n = utils.pick_weight(get_forest_spawn_chances(pollution_factor))
		chunk = ChunkMap[set[n].chunk_key]
		trees = chunk.surface.find_entities_filtered{type='tree', area=set[n].area}
		if #trees >= conf.wisp_forest_min_density then break end
		trees, chunk.forest, set[n], set.n, set[set.n] = nil, false, set[set.n], set.n - 1
		SpawnChanceCache = nil
	end
	if trees then for n = 1, count do
		table.insert(wisp_trees, trees[math.random(#trees)])
	end end
	return wisp_trees
end

function zones.get_wisp_trees_near_pos(surface, pos, radius)
	-- Return random trees around player in wisp_near_player_radius.
	-- Number of returned trees is math.floor(#trees-in-area * conf.wisp_near_player_percent).
	local wisp_trees = {}
	local trees = surface.find_entities_filtered{type='tree', area=utils.get_area(radius, pos)}
	for n = 1, math.floor(#trees * conf.wisp_near_player_percent)
		do wisp_trees[#wisp_trees+1] = trees[math.random(#trees)] end
	return wisp_trees
end

function zones.find_industrial_pos(surface, pos, radius)
	-- Find center of the most polluted chunk in the vicinity of position.
	-- Done by checking chunks in straight/diagonal + player directions,
	--  while pollution value keeps increasing and until radius is reached,
	--  picking max of the resulting chunks.
	local directions, cx, cy, p = {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
	for _, p in pairs(game.connected_players) do
		if not p.valid then goto skip end
		cx, cy = p.position.x - pos.x, p.position.y - pos.y
		p = math.max(math.abs(cx), math.abs(cy))
		table.insert(directions, {cx/p, cy/p})
	::skip:: end

	cx, cy, p = pos_chunk_xy(pos)
	pos, p = {}, surface.get_pollution{cx * cs, cy * cs}
	for n, dd in pairs(directions) do pos[n] = {cx, cy, p} end

	local p0 = true
	while p0 and radius >= 0 do
		radius, p0 = radius - 1
		for n, dd in pairs(directions) do
			cx, cy, p0 = table.unpack(pos[n])
			cx, cy = cx + dd[1], cy + dd[2]
			p = {cx * cs, cy * cs}
			p = surface.is_chunk_generated{cx, cy} and surface.get_pollution(p) or 0
			if p >= p0 then pos[n] = {cx, cy, p} else directions[n] = nil end
		end
	end

	p = {[3]=0}
	for _, dd in pairs(pos) do if dd[3] >= p[3] then p = dd end end
	cx, cy, p = table.unpack(p)
	return {x=(cx + 0.5) * cs, y=(cy + 0.5) * cs}
end


function zones.reset_chunk_area(surface, area)
	-- Adds or resets all stored info (scan ticks, pollution, etc)
	--  for chunk, identified by left-top corner of the area (assumed to be chunk area).
	replace_chunk(surface, area_chunk_xy(area))
end

function zones.refresh_chunks(surface)
	-- Forces re-scan of all existing chunks and adds any newly-revealed ones.
	-- Should only be called on game/mod updates,
	--  in case these might change chunks or how they are handled.
	local chunks_found, chunks_diff, k, c = {}, 0

	for chunk in surface.get_chunks() do
		k = chunk_key(chunk.x, chunk.y)
		c = ChunkMap[k]
		if c then c.scan_spread, c.scan_trees = nil else
			chunks_diff = chunks_diff + 1
			replace_chunk(surface, chunk.x, chunk.y)
		end
		chunks_found[k] = true
	end
	if chunks_diff > 0
		then utils.log(' - Detected ChunkMap additions: %d', chunks_diff) end

	chunks_diff = 0
	for k,_ in pairs(ChunkMap) do if not chunks_found[k]
		then chunks_diff, ChunkMap[k] = chunks_diff + 1, nil end end
	if chunks_diff > 0 then
		utils.log(' - Detected ChunkMap removals (mod bug?): %d', chunks_diff)
		for n = 1, #ChunkList do ChunkList[n] = nil end
		for k,_ in pairs(ChunkMap) do ChunkList[#ChunkList+1] = k end
	end
end

function zones.init(zs)
	if InitDone then return end
	for _, k in ipairs{'chunk_list', 'chunk_map'}
		do if not zs[k] then zs[k] = {} end end
	for _, k in ipairs{'chunk_spread_queue', 'forest_set', 'chart_labels'}
		do if not zs[k] then zs[k] = {n=0} end end
	ChunkList, ChunkMap = zs.chunk_list, zs.chunk_map
	ChunkSpreadQueue, ForestSet = zs.chunk_spread_queue, zs.forest_set
	ChartLabels = zs.chart_labels
	utils.log(
		' - Zone stats: chunks=%d spread-queue=%d forests=%d labels=%d',
		#ChunkList, ChunkSpreadQueue.n, ForestSet.n, ChartLabels.n )
	InitDone = true
end


------------------------------------------------------------
-- Various debug info routines
------------------------------------------------------------

function zones.full_update()
	-- Only for manual use from console, can take
	--  a second or few of real time if nothing was pre-scanned
	local n
	utils.log('zones: running full update')
	n = zones.update_wisp_spread(1, 1)
	utils.log('zones:  - updated spread chunks: %d', n)
	n = zones.update_forests_in_spread(1, 1)
	utils.log('zones:  - scanned chunks for forests: %d', n)
	utils.log(
		'zones:  - done, spread-queue=%d forests=%d',
		ChunkSpreadQueue.n, ForestSet.n )
end

function zones.print_stats(print_func)
	local fmt_bign = function(v) return utils.fmt_n_comma(v or '') end
	local function percentiles(t, perc)
		local fmt, fmt_vals = {}, {}
		for n = 1, #perc do
			table.insert(fmt, ('p%02d=%%s'):format(perc[n]))
			table.insert(fmt_vals, fmt_bign(t[math.floor((perc[n]/100) * #t)]))
		end
		return fmt, fmt_vals
	end

	local function pollution_table_stats(key, chunks)
		local p_table, p_sum, chunk = {}, 0
		for n = 1, #chunks do
			chunk = ChunkMap[chunks[n]]
			if not (chunk.pollution and chunk.pollution > 0) then goto skip end
			table.insert(p_table, chunk.pollution)
			p_sum = p_sum + chunk.pollution
		::skip:: end
		table.sort(p_table)
		local p_mean = p_sum / #p_table
		print_func(
			('zones:  - %s pollution chunks=%s min=%s max=%s mean=%s sum=%s')
			:format( key, table.unpack(utils.map( fmt_bign,
				{#p_table, p_table[1], p_table[#p_table], p_mean, p_sum} )) ) )
		local fmt, fmt_vals = percentiles(p_table, {10, 25, 50, 75, 90, 95, 99})
		print_func(('zones:  - %s pollution %s'):format(
			key, table.concat(fmt, ' ') ):format(table.unpack(fmt_vals)))
	end

	print_func('zones: stats')
	pollution_table_stats('spread', ChunkList)
	local forest_chunks = {}
	for n = 1, ForestSet.n
		do table.insert(forest_chunks, ForestSet[n].chunk_key) end
	pollution_table_stats('forest', forest_chunks)
end

function zones.forest_labels_add(surface, force, threshold)
	-- Adds map ("chart") labels for each forest on the map
	zones.forest_labels_remove(force)
	local set, chances, chance_sum = ChartLabels, get_forest_spawn_chances()
	for n = 1, ForestSet.n do
		label = ForestSet[n].area
		label = {(label[1][1] + label[2][1])/2, (label[1][2] + label[2][2])/2}
		n = chances[n] / chance_sum
		if n < threshold then n = nil end
		label = {force_name=force.name, label=force.add_chart_tag(
			surface, { position=label,
				icon={type='item', name='raw-wood'},
				text=n and ('%.2f%%'):format(100 * n) } )}
		set[set.n+1], set.n = label, set.n+1
	end
end
function zones.forest_labels_remove(force)
	local set, n = ChartLabels, 1
	while n <= set.n do
		if force.name ~= set[n].force_name then goto skip end
		if set[n].label.valid then set[n].label.destroy() end
		n, set[n], set.n, set[set.n] = n-1, set[set.n], set.n-1
	::skip:: n = n + 1 end
end

return zones
