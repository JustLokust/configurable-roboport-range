data:extend({
	{
		type = 'item',
		name = 'alien-flora-sample',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/alien-flora-sample.png',
		icon_size = 32,
		flags = {'goes-to-main-inventory'},
		subgroup = 'raw-material',
		order = 'g[alien-flora-sample]',
		stack_size = 500,
		default_request_amount = 10
	},
	{
		type = 'item',
		name = 'wisp-yellow',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-yellow-capsule.png',
		icon_size = 32,
		flags = {'goes-to-quickbar'},
		subgroup = 'capsule',
		order = 'z[combatrobot]',
		place_result = 'wisp-yellow',
		stack_size = 100
	},
	{
		type = 'item',
		name = 'wisp-purple',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png',
		icon_size = 32,
		flags = {'goes-to-quickbar'},
		subgroup = 'capsule',
		order = 'z[combatrobot]',
		place_result = 'wisp-purple',
		stack_size = 100
	},
	{
		type = 'item',
		name = 'wisp-attached',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-purple-capsule.png',
		icon_size = 32,
		flags = {'goes-to-quickbar'},
		subgroup = 'capsule',
		order = 'z[combatrobot]',
		place_result = 'wisp-attached',
		stack_size = 100
	},
	{
		type = 'item',
		name = 'wisp-red',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-red-capsule.png',
		icon_size = 32,
		flags = {'goes-to-quickbar'},
		order = 'z[combatrobot]',
		subgroup = 'capsule',
		place_result = 'wisp-red',
		stack_size = 100
	},
	{
		type = 'item',
		name = 'UV-lamp',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/uv-lamp.png',
		icon_size = 32,
		flags = {'goes-to-quickbar'},
		subgroup = 'circuit-network',
		order = 'a[light]-a[uv-lamp]',
		place_result = 'UV-lamp',
		stack_size = 50
	},
	{
		type = 'item',
		name = 'wisp-detector',
		icon = '__Will-o-the-Wisps_updated__/graphics/icons/wisp-detector.png',
		icon_size = 32,
		flags = { 'goes-to-quickbar' },
		subgroup = 'circuit-network',
		place_result='wisp-detector',
		order = 'b[combinators]-c[wisp-detector]',
		stack_size= 50
	},

})