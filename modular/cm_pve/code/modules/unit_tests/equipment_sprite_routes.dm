/datum/unit_test/equipment_sprite_routes
	var/static/list/icon_state_cache = list()

/datum/unit_test/equipment_sprite_routes/Run()
	var/mob/living/carbon/human/test_human = allocate(/mob/living/carbon/human)
	var/list/items = list(
		list(/obj/item/clothing/under/marine, WEAR_BODY),
		list(/obj/item/clothing/under/lasalle, WEAR_BODY),
		list(/obj/item/clothing/under/rank/synthetic/joe/fire, WEAR_BODY),
		list(/obj/item/clothing/under/marine/veteran/pmc/corporate/lasalle_security, WEAR_BODY),
		list(/obj/item/clothing/suit/storage/marine, WEAR_JACKET),
		list(/obj/item/clothing/suit/storage/marine/veteran/lb_merc, WEAR_JACKET),
		list(/obj/item/clothing/suit/storage/marine/veteran/pmc/light/corporate/lasalle_security, WEAR_JACKET),
		list(/obj/item/storage/backpack/marine, WEAR_BACK),
		list(/obj/item/storage/backpack/satchel/white, WEAR_BACK),
		list(/obj/item/storage/backpack/marine/smartpack/a1, WEAR_BACK),
		list(/obj/item/clothing/head/helmet/marine, WEAR_HEAD),
		list(/obj/item/clothing/head/helmet/marine/veteran/lb_merc, WEAR_HEAD),
		list(/obj/item/clothing/head/helmet/marine/veteran/pmc/corporate/seegson, WEAR_HEAD),
		list(/obj/item/clothing/head/helmet/marine/veteran/pmc/corporate/lasalle_security, WEAR_HEAD),
	)
	for(var/list/item_data as anything in items)
		var/obj/item/item = allocate(item_data[1])
		validate_worn_state(item, test_human, item_data[2])

/datum/unit_test/equipment_sprite_routes/proc/validate_worn_state(obj/item/item, mob/living/carbon/human/test_human, slot)
	var/worn_state = item.get_icon_state(test_human, slot)
	if(isnull(worn_state) || !length("[worn_state]"))
		return
	var/worn_icon
	if(item.icon_override)
		worn_icon = item.icon_override
	else
		var/bodytype = test_human.species.get_bodytype(test_human)
		if(item.use_spritesheet(bodytype, slot, worn_state))
			worn_icon = item.sprite_sheets[bodytype]
	if(!worn_icon && item.contained_sprite)
		worn_icon = item.icon
	if(!worn_icon && LAZYISIN(item.item_icons, slot))
		worn_icon = item.item_icons[slot]
	if(!worn_icon)
		worn_icon = GLOB.default_onmob_icons[slot]
	var/icon_key = "[worn_icon]"
	if(isnull(icon_state_cache[icon_key]))
		icon_state_cache[icon_key] = icon_states(worn_icon, 1)
	if(!("[worn_state]" in icon_state_cache[icon_key]))
		Fail("[item.type] resolves slot [slot] to missing state \"[worn_state]\" in '[worn_icon]'", __FILE__, __LINE__)
