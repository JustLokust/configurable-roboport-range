local conf = require('config')

data:extend{

	{ order = '0010',
		setting_type = 'runtime-global',
		name = 'wisps-can-attack',
		type = 'bool-setting',
		default_value = not conf.peaceful_wisps },
	{ order = '0015',
		setting_type = 'runtime-global',
		name = 'wisp-death-retaliation-radius',
		type = 'double-setting',
		minimum_value = 0,
		default_value = conf.wisp_death_retaliation_radius },
	{ order = '0020',
		setting_type = 'runtime-global',
		name = 'defences-shoot-wisps',
		type = 'bool-setting',
		default_value = not conf.peaceful_defences },
	{ order = '0030',
		setting_type = 'runtime-global',
		name = 'purple-wisp-damage',
		type = 'bool-setting',
		default_value = not conf.peaceful_spores },
	{ order = '0040',
		setting_type = 'runtime-global',
		name = 'wisp-aggression-factor',
		type = 'double-setting',
		minimum_value = 0,
		maximum_value = 1.0,
		default_value = conf.wisp_aggression_factor },
	{ order = '0050',
		setting_type = 'runtime-global',
		name = 'wisp-biter-aggression',
		type = 'bool-setting',
		default_value = conf.wisp_biter_aggression },

	{ order = '0110',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-count',
		type = 'int-setting',
		minimum_value = 0,
		default_value = conf.wisp_max_count },
	{ order = '0120',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-pollution-factor',
		type = 'double-setting',
		minimum_value = -1,
		default_value = conf.wisp_forest_spawn_pollution_factor },

	{ order = '0220',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-purple',
		type = 'double-setting',
		minimum_value = 0,
		maximum_value = 1.0,
		default_value = conf.wisp_forest_spawn_chance_purple },
	{ order = '0230',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-yellow',
		type = 'double-setting',
		minimum_value = 0,
		maximum_value = 1.0,
		default_value = conf.wisp_forest_spawn_chance_yellow },
	{ order = '0240',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-red',
		type = 'double-setting',
		minimum_value = 0,
		maximum_value = 1.0,
		default_value = conf.wisp_forest_spawn_chance_red },
	{ order = '0250',
		setting_type = 'runtime-global',
		name = 'wisp-map-spawn-green',
		type = 'double-setting',
		minimum_value = 0,
		maximum_value = 1.0,
		default_value = conf.wisp_forest_spawn_chance_green },

}
