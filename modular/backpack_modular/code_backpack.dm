//==========================// IMP BACKPACK \\================================\\
//=======================================================================\\

// Define slots for IMP backpack attachments (if not already defined globally)
#ifndef IMP_SLOT_ETOOL
#define IMP_SLOT_ETOOL   "imp_etool"
#define IMP_SLOT_BEDROLL "imp_bedroll"
#define IMP_SLOT_SADAR   "imp_sadar"
#define IMP_SLOT_POUCH   "imp_pouch"
#endif

/obj/item/storage/backpack/marine/imp
	name = "\improper IMP backpack"
	desc = "A lightweight backpack developed for the Marine 70 program, dubbed the IMP (Individual Mounting Points) backpack. There are various clips around the backpack to attach specialized gear to. Click with an attachable item to attach it. Right-click while in hand to remove attached items."
	icon_state = "imp"
	item_state = "imp"
	has_gamemode_skin = FALSE
	xeno_types = null

	// List of allowed IMP slots
	var/list/valid_imp_slots = list(IMP_SLOT_ETOOL, IMP_SLOT_BEDROLL, IMP_SLOT_SADAR, IMP_SLOT_POUCH)
	// Restricted slots (only one per slot)
	var/list/restricted_imp_slots = list(IMP_SLOT_ETOOL, IMP_SLOT_BEDROLL, IMP_SLOT_SADAR)
	// List of attached items (stored in nullspace)
	var/list/accessories = list()
	// Max pouches
	var/max_pouches = 2

/obj/item/storage/backpack/marine/imp/Destroy()
	for(var/obj/item/I in accessories)
		qdel(I)
	accessories.Cut()
	return ..()

// Helper: determine IMP slot from item type
/obj/item/storage/backpack/marine/imp/proc/get_imp_slot(obj/item/I)
	if(istype(I, /obj/item/tool/shovel/etool))
		return IMP_SLOT_ETOOL
	if(istype(I, /obj/item/roller/bedroll))
		return IMP_SLOT_BEDROLL
	if(istype(I, /obj/item/prop/folded_anti_tank_sadar))
		return IMP_SLOT_SADAR
	if(istype(I, /obj/item/storage/pouch))
		return IMP_SLOT_POUCH
	return null

// Check if an item can be attached
/obj/item/storage/backpack/marine/imp/proc/can_attach_accessory(obj/item/I)
	var/slot = get_imp_slot(I)
	if(!slot)
		return FALSE

	if(!(slot in valid_imp_slots))
		return FALSE

	// Check restricted slots (only one)
	if(slot in restricted_imp_slots)
		for(var/obj/item/AC in accessories)
			if(get_imp_slot(AC) == slot)
				return FALSE

	// Special pouch limit
	if(slot == IMP_SLOT_POUCH)
		var/pouch_count = 0
		for(var/obj/item/AC in accessories)
			if(get_imp_slot(AC) == IMP_SLOT_POUCH)
				pouch_count++
		if(pouch_count >= max_pouches)
			return FALSE

	// Extra checks for folded state
	if(istype(I, /obj/item/tool/shovel/etool))
		var/obj/item/tool/shovel/etool/et = I
		if(!et.folded)
			return FALSE
	if(istype(I, /obj/item/weapon/gun/launcher/rocket/anti_tank/disposable))
		return FALSE  // unfolded SADAR not allowed

	return TRUE

// Attach accessory (moves item directly to nullspace, bypassing the floor)
/obj/item/storage/backpack/marine/imp/proc/attach_accessory(mob/user, obj/item/I, silent = FALSE)
	if(!can_attach_accessory(I))
		return FALSE

	// Move item directly from hand to nullspace, without dropping on ground
	if(!user.drop_inv_item_to_loc(I, null))
		to_chat(user, SPAN_WARNING("You cannot detach [I] from your hand."))
		return FALSE

	accessories += I

	var/slot = get_imp_slot(I)
	var/msg = ""
	switch(slot)
		if(IMP_SLOT_ETOOL)
			msg = "You attach the folded e-tool to the side of [src]."
		if(IMP_SLOT_BEDROLL)
			msg = "You strap the bedroll to the bottom of [src]."
		if(IMP_SLOT_SADAR)
			msg = "You clip the folded SADAR to the front of [src]."
		if(IMP_SLOT_POUCH)
			var/pouch_count = 0
			for(var/obj/item/P in accessories)
				if(get_imp_slot(P) == IMP_SLOT_POUCH)
					pouch_count++
			msg = "You attach the [I] to the waist belt of [src]. ([pouch_count]/[max_pouches] pouches)"

	if(!silent && msg)
		to_chat(user, SPAN_NOTICE(msg))

	update_icon()
	if(length(accessories))
		verbs += /obj/item/storage/backpack/marine/imp/proc/remove_accessory_verb
	return TRUE

// Remove accessory (brings item back from nullspace)
/obj/item/storage/backpack/marine/imp/proc/remove_accessory(mob/user, obj/item/I)
	if(!(I in accessories))
		return FALSE

	accessories -= I
	I.forceMove(user.loc)
	if(user.put_in_hands(I))
		to_chat(user, SPAN_NOTICE("You take the [I.name] from [src]."))
	else
		to_chat(user, SPAN_NOTICE("You drop the [I.name] from [src] on the ground."))
	update_icon()

	if(!length(accessories))
		verbs -= /obj/item/storage/backpack/marine/imp/proc/remove_accessory_verb
	return TRUE

// Radial menu for removal
/obj/item/storage/backpack/marine/imp/proc/pick_accessory_to_remove(mob/user)
	if(!length(accessories))
		return null

	var/list/removables = list()
	var/list/choice_to_item = list()

	for(var/obj/item/I in accessories)
		var/display_name
		var/icon_state_ov
		var/slot = get_imp_slot(I)
		switch(slot)
			if(IMP_SLOT_ETOOL)
				display_name = "E-Tool"
				icon_state_ov = "+imp_shovel"
			if(IMP_SLOT_BEDROLL)
				display_name = "Bedroll"
				icon_state_ov = "+imp_bedroll"
			if(IMP_SLOT_SADAR)
				display_name = "SADAR"
				icon_state_ov = "+imp_sadar"
			if(IMP_SLOT_POUCH)
				var/index = 1
				var/pouch_num = 0
				for(var/obj/item/P in accessories)
					if(get_imp_slot(P) == IMP_SLOT_POUCH)
						pouch_num++
						if(P == I)
							index = pouch_num
							break
				display_name = "Pouch [index] ([I.name])"
				icon_state_ov = (index == 1) ? "+imp_leftpouch" : "+imp_rightpouch"

		if(display_name)
			removables[display_name] = image(icon = 'modular/backpack_modular/backpack_module.dmi', icon_state = icon_state_ov)
			choice_to_item[display_name] = I

	if(!length(removables))
		return null

	var/use_radials = user.client?.prefs?.no_radials_preference ? FALSE : TRUE
	var/choice
	if(use_radials)
		choice = show_radial_menu(user, user, removables, require_near = FALSE)
	else
		choice = tgui_input_list(user, "Select an accessory to remove from [src]", "Remove accessory", removables)

	if(!choice)
		return null

	if(!user.Adjacent(src))
		to_chat(user, SPAN_WARNING("You're too far away!"))
		return null

	return choice_to_item[choice]

// Verb for removal
/obj/item/storage/backpack/marine/imp/proc/remove_accessory_verb()
	set name = "Remove Accessory"
	set category = "Object"
	set src in usr

	if(!usr.can_use_hands() || usr.is_mob_incapacitated())
		return

	if(usr.get_active_hand() != src && usr.l_hand != src && usr.r_hand != src && usr.back != src)
		to_chat(usr, SPAN_WARNING("You must be holding or wearing [src] to remove accessories."))
		return

	var/obj/item/to_remove = pick_accessory_to_remove(usr)
	if(to_remove)
		remove_accessory(usr, to_remove)

// Attackby: attach item, otherwise try to put inside
/obj/item/storage/backpack/marine/imp/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/weapon/gun/launcher/rocket/anti_tank/disposable))
		to_chat(user, SPAN_WARNING("You'll need to fold the [I] before attaching it to the [src]."))
		return TRUE

	if(can_attach_accessory(I))
		attach_accessory(user, I)
		return TRUE

	// For non-attachable items, let parent handle storage insertion
	return ..()

// Attack self (click in hand) - show removal menu if accessories exist
/obj/item/storage/backpack/marine/imp/attack_self(mob/user)
	if(!user.can_use_hands() || user.is_mob_incapacitated())
		return
	if(length(accessories))
		var/obj/item/to_remove = pick_accessory_to_remove(user)
		if(to_remove)
			remove_accessory(user, to_remove)
	else
		return ..()

// Update icon overlays
/obj/item/storage/backpack/marine/imp/update_icon()
	..()
	var/pouch_count = 0
	for(var/obj/item/I in accessories)
		var/slot = get_imp_slot(I)
		switch(slot)
			if(IMP_SLOT_ETOOL)
				overlays += image(icon = 'modular/backpack_modular/backpack_module.dmi', icon_state = "+imp_shovel")
			if(IMP_SLOT_BEDROLL)
				overlays += image(icon = 'modular/backpack_modular/backpack_module.dmi', icon_state = "+imp_bedroll")
			if(IMP_SLOT_SADAR)
				overlays += image(icon = 'modular/backpack_modular/backpack_module.dmi', icon_state = "+imp_sadar")
			if(IMP_SLOT_POUCH)
				pouch_count++
				var/icon_state_ov = (pouch_count == 1) ? "+imp_leftpouch" : "+imp_rightpouch"
				overlays += image(icon = 'modular/backpack_modular/backpack_module.dmi', icon_state = icon_state_ov)

// Examine
/obj/item/storage/backpack/marine/imp/examine(mob/user)
	..()
	if(!length(accessories))
		to_chat(user, SPAN_NOTICE("It has nothing attached."))
		return

	var/msg = "It has attached: "
	var/list/names = list()
	var/pouch_idx = 1
	for(var/obj/item/I in accessories)
		var/slot = get_imp_slot(I)
		switch(slot)
			if(IMP_SLOT_ETOOL)
				names += "a folded e-tool"
			if(IMP_SLOT_BEDROLL)
				names += "a bedroll"
			if(IMP_SLOT_SADAR)
				names += "a folded SADAR"
			if(IMP_SLOT_POUCH)
				names += "[I.name] (pouch [pouch_idx])"
				pouch_idx++
	to_chat(user, SPAN_NOTICE(msg + english_list(names)))
