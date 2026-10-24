#define SENTRY_TOP_LEFT "top_left"
#define SENTRY_TOP_RIGHT "top_right"
#define SENTRY_BOTTOM_LEFT "bottom_left"
#define SENTRY_BOTTOM_RIGHT "bottom_right"

/area/sky
	name = "Sky"
	icon_state = "lv-626"
	flags_area = AREA_UNWEEDABLE

/area/sky/level4
	name = "Upper Sky"

/obj/effect/decal/cleanable/dirt/alt_dirt
	icon_state = "stain"

/obj/effect/decal/cleanable/dirt/alt_dirt/stain
	icon_state = "stain_alt"

/obj/effect/decal/cleanable/dirt/alt_dirt/goo
	icon_state = "goo"

/obj/effect/decal/cleanable/dirt/alt_dirt/goo/goo_alt
	icon_state = "goo_alt"

/obj/effect/decal/large_stain
	name = "large stain"
	desc = FALSE
	icon = 'icons/obj/structures/props/64x64_bodybag_pile.dmi'
	icon_state = "large_stain"
	layer = TURF_LAYER
	plane = FLOOR_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/landmark/corpsespawner/colonist/random
	name = "Colonist Random"
	equip_path = /datum/equipment_preset/corpse/colonist/random

/obj/effect/landmark/corpsespawner/colonist/random/burst
	name = "Burst Colonist Random"
	equip_path = /datum/equipment_preset/corpse/colonist/random/burst

/datum/equipment_preset/corpse/colonist/random
	name = "Corpse - Colonist Random"

/datum/equipment_preset/corpse/colonist/random/load_gear(mob/living/carbon/human/new_human)
	var/random_surv_type = pick(SSmapping.configs[GROUND_MAP].survivor_types)
	var/datum/equipment_preset/survivor/surv_equipment = new random_surv_type
	surv_equipment.load_gear(new_human)

/datum/equipment_preset/corpse/colonist/random/burst
	name = "Corpse - Burst Colonist Random"
	xenovictim = TRUE

/obj/effect/landmark/structure_spawner/setup/distress/xeno_door_reinforced
	name = "Distress Xeno reinforced door spawner"
	icon_state = "door_r"
	path_to_spawn = /obj/structure/mineral_door/resin/thick

/obj/effect/landmark/structure_spawner/setup/distress/xeno_sticky
	name = "Distress Xeno sticky spawner"
	icon = 'icons/mob/xenos/effects.dmi'
	icon_state = "sticky"
	path_to_spawn = /obj/effect/alien/resin/sticky

/obj/effect/landmark/structure_spawner/setup/distress/xeno_wall_reinforced
	name = "Distress Xeno reinforced wall spawner"
	icon_state = "wall_r"
	path_to_spawn = /turf/closed/wall/resin/thick
	is_turf = TRUE

GLOBAL_LIST_INIT_TYPED(sentry_spawns, /list/obj/effect/sentry_landmark, list())

/obj/effect/sentry_landmark
	icon = 'icons/landmarks.dmi'
	icon_state = "map_sentry"
	var/abstract_type = /obj/effect/sentry_landmark
	var/landing_zone
	var/position

/obj/effect/sentry_landmark/Initialize(mapload, ...)
	. = ..()
	if(type == abstract_type)
		return INITIALIZE_HINT_QDEL
	LAZYADDASSOCLIST(GLOB.sentry_spawns[landing_zone], position, get_turf(src))
	return INITIALIZE_HINT_QDEL

/obj/effect/sentry_landmark/lz_1
	abstract_type = /obj/effect/sentry_landmark/lz_1
	landing_zone = /obj/docking_port/stationary/marine_dropship/lz1

/obj/effect/sentry_landmark/lz_1/top_left
	position = SENTRY_TOP_LEFT

/obj/effect/sentry_landmark/lz_1/top_right
	position = SENTRY_TOP_RIGHT

/obj/effect/sentry_landmark/lz_1/bottom_left
	position = SENTRY_BOTTOM_LEFT

/obj/effect/sentry_landmark/lz_1/bottom_right
	position = SENTRY_BOTTOM_RIGHT

/obj/effect/sentry_landmark/lz_2
	abstract_type = /obj/effect/sentry_landmark/lz_2
	landing_zone = /obj/docking_port/stationary/marine_dropship/lz2

/obj/effect/sentry_landmark/lz_2/top_left
	position = SENTRY_TOP_LEFT

/obj/effect/sentry_landmark/lz_2/top_right
	position = SENTRY_TOP_RIGHT

/obj/effect/sentry_landmark/lz_2/bottom_left
	position = SENTRY_BOTTOM_LEFT

/obj/effect/sentry_landmark/lz_2/bottom_right
	position = SENTRY_BOTTOM_RIGHT

/obj/effect/timed_event
	icon = 'icons/landmarks.dmi'
	icon_state = "o_red"
	var/static/list/notification_areas = list()
	var/time

/obj/effect/timed_event/Initialize(mapload, ...)
	. = ..()
	icon = null
	if(isnull(time))
		return INITIALIZE_HINT_QDEL
	SSticker.OnRoundstart(CALLBACK(src, PROC_REF(handle_round_start)))

/obj/effect/timed_event/proc/handle_round_start()
	var/actual_time = time MINUTES
	addtimer(generate_callback(), actual_time)
	if(notification_areas[type]?["[actual_time]"])
		LAZYORASSOCLIST(notification_areas[type], "[actual_time]", get_area(src))
		qdel(src)
	else
		addtimer(CALLBACK(src, PROC_REF(announce_event), actual_time), actual_time)
		LAZYORASSOCLIST(notification_areas[type], "[actual_time]", get_area(src))

/obj/effect/timed_event/proc/generate_callback()
	return

/obj/effect/timed_event/proc/announce_event(time_to_grab)
	return

/obj/effect/timed_event/scrapeaway
	icon_state = "o_blue"

/obj/effect/timed_event/scrapeaway/generate_callback()
	return CALLBACK(get_turf(src), TYPE_PROC_REF(/turf, ScrapeAway))

/obj/effect/timed_event/scrapeaway/announce_event(time_to_grab)
	var/announcement_areas = english_list(notification_areas[type]["[time_to_grab]"])
	var/marine_announcement_text = SSmapping.configs[GROUND_MAP].environment_traits[ZTRAIT_IN_SPACE] ? "Structural collapse detected in [announcement_areas]. Be advised that new routes may be accessible." : "Geological shifts detected in [announcement_areas]. Be advised that new routes may be accessible."
	marine_announcement(marine_announcement_text, "Priority Announcement")
	var/xeno_announcement_text = SSmapping.configs[GROUND_MAP].environment_traits[ZTRAIT_IN_SPACE] ? "The shattered metal of this place has collapsed, providing new routes in [announcement_areas]." : "The ground of this world trembles, and new routes are accessible in [announcement_areas]."
	xeno_announcement(SPAN_XENOANNOUNCE(xeno_announcement_text), "everything", XENO_GENERAL_ANNOUNCE)
	qdel(src)

/obj/item/bedsheet/bedroll/blue
	icon_state = "bedroll_sheet"
	color = "#8cb9e2"

/obj/item/bedsheet/bedroll/pink
	icon_state = "bedroll_sheet"
	color = "#eaa8b2"

/obj/item/clock
	name = "digital clock"
	desc = "A battery powered clock, able to keep time within about 5 seconds... it was never that accurate."
	icon = 'icons/obj/items/devices.dmi'
	icon_state = "digital_clock"
	force = 3
	throwforce = 2
	throw_range = 4
	w_class = SIZE_SMALL

/obj/item/clock/get_examine_text(mob/user)
	. = ..()
	. += SPAN_NOTICE("The [name] reads: [GLOB.current_date_string] - [worldtime2text()]")

/obj/item/clothing/glasses/regular/hippie
	name = "Rounded Prescription Glasses"
	desc = "Rounded glasses, makes you look smart and potentially reputable."
	icon_state = "hippie_glasses"
	item_state = "hippie_glasses"
	flags_equip_slot = SLOT_EYES|SLOT_FACE

/obj/item/roller/bedroll/comfy
	name = "folded comfy bedroll"
	desc = "Folded and innocent-looking, but known for causing excessive napping."
	icon_state = "bedroll_comfy"
	rollertype = /obj/structure/bed/bedroll/comfy

/obj/structure/bed/bedroll/comfy
	name = "unfolded comfy bedroll"
	desc = "A bedroll known for causing excessive napping."
	icon_state = "bedroll_comfy_o"
	foldabletype = /obj/item/roller/bedroll/comfy

/obj/item/roller/bedroll/comfy/blue
	color = "#8cb9e2"
	rollertype = /obj/structure/bed/bedroll/comfy/blue

/obj/structure/bed/bedroll/comfy/blue
	color = "#8cb9e2"
	foldabletype = /obj/item/roller/bedroll/comfy/blue

/obj/item/roller/bedroll/comfy/pink
	color = "#eaa8b2"
	rollertype = /obj/structure/bed/bedroll/comfy/pink

/obj/structure/bed/bedroll/comfy/pink
	color = "#eaa8b2"
	foldabletype = /obj/item/roller/bedroll/comfy/pink

/obj/structure/blocker/forcefield/all
	types = list(/mob/living/carbon/human, /mob/living/carbon/xenomorph, /obj/item/weapon)
	icon_state = "purple_line"

/obj/structure/closet/crate/trashcart/alt
	name = "trash cart"
	desc = "A heavy, metal trashcart with wheels."
	icon_state = "closed_trashcart_alt"
	icon_opened = "open_trashcart_alt"
	icon_closed = "closed_trashcart_alt"

/obj/structure/flora/bush/ausbushes/var3/ppflowers
	icon_state = "ppflowers_1"
	icon_tag = "ppflowers"
	layer = BELOW_MOB_LAYER

/obj/structure/flora/bush/ausbushes/ywflowers
	icon_state = "ywflowers_1"
	icon_tag = "ywflowers"
	layer = BELOW_MOB_LAYER

/obj/structure/flora/jungle/thickbush/large_jungle_bush
	name = "bush"
	desc = "A large jungle bush, it'll take something sharp and a lot of determination to clear away."
	icon = 'icons/obj/structures/props/natural/vegetation/colorable_junge_bush.dmi'
	icon_state = "bush1"
	density = FALSE
	layer = ABOVE_XENO_LAYER
	fire_flag = FLORA_BURN_NO_SPREAD
	health = 100

/obj/structure/flora/jungle/thickbush/large_jungle_bush/attack_alien(mob/living/carbon/xenomorph/current_xenomorph)
	if(unslashable)
		return XENO_NO_DELAY_ACTION
	current_xenomorph.animation_attack_on(src)
	playsound(src, 'sound/effects/vegetation_hit.ogg', 25, 1)
	current_xenomorph.visible_message(SPAN_DANGER("[current_xenomorph] slashes at [src]!"), SPAN_DANGER("You slash at [src]!"), null, 5, CHAT_TYPE_XENO_COMBAT)
	update_health(rand(current_xenomorph.melee_damage_lower, current_xenomorph.melee_damage_upper))
	return XENO_ATTACK_ACTION

/obj/structure/machinery/computer/arcade/blue_stripe
	icon_state = "arcade_bluestripe"

/obj/structure/machinery/computer/arcade/green_stripe
	icon_state = "arcade_greenstripe"

/obj/structure/machinery/door/poddoor/hybrisa/secure_red_door/open
	density = FALSE

/obj/structure/shuttle/part/dropship_clf/transparent/left_engine
	icon_state = "leftengine_1"

/obj/structure/shuttle/part/dropship_clf/transparent/right_engine
	icon_state = "rightengine_1"

/obj/structure/sign/calendar/ua
	icon_state = "calendar_ua"
	desc = "Classic office decoration and a place to stare at maniacally, has a vertically placed UA flag and some army symbolics."

/turf/open/floor/almayer/black2/east
	dir = EAST

/turf/open/floor/almayer/black2/north
	dir = NORTH

/turf/open/floor/almayer/black2/northeast
	dir = NORTHEAST

/turf/open/floor/almayer/black2/northwest
	dir = NORTHWEST

/turf/open/floor/almayer/black2/west
	dir = WEST

/turf/open/floor/almayer/blackfull2
	icon_state = "blackfull2"

/turf/open/floor/strata/blue4/east
	dir = EAST

/turf/open/floor/strata/gray_multi_tiles
