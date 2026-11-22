// Persistent ship mission hub, GM placement tools, player stash, and trader.
// Stash entries use stable item type paths and small primitive state records;
// mission and placement state are stored in the server-side campaign savefile.

#define GM_HUB_MAX_MISSIONS 12


/datum/hub_campaign_state
	/// IDs of missions queued by the GM for the next campaign sequence.
	var/list/mission_queue = list()
	var/list/mission_briefs = list()
	var/list/mission_details = list()
	/// Mission currently active in the shared ship campaign.
	var/current_hub_mission = null
	/// GM-defined trader offers: stable item type path text mapped to price.
	var/list/hub_trader_offers = list()
	var/list/hub_trader_catalog = list("Quartermaster" = list("buy" = list(), "sell" = list()))

GLOBAL_DATUM_INIT(hub_campaign_state, /datum/hub_campaign_state, new)

/datum/hub_campaign_state/New()
	. = ..()
	var/savefile/S = new /savefile("data/mission_hub_gm.sav")
	var/list/saved_queue
	var/list/saved_briefs
	var/list/saved_offers
	var/list/saved_catalog
	var/list/saved_details
	S["mission_queue"] >> saved_queue
	S["mission_briefs"] >> saved_briefs
	S["hub_trader_offers"] >> saved_offers
	S["hub_trader_catalog"] >> saved_catalog
	S["mission_details"] >> saved_details
	if(islist(saved_queue))
		mission_queue = saved_queue.Copy()
	if(islist(saved_briefs))
		mission_briefs = saved_briefs.Copy()
	if(islist(saved_offers))
		hub_trader_offers = saved_offers.Copy()
	if(islist(saved_catalog))
		hub_trader_catalog = saved_catalog.Copy()
	if(islist(saved_details))
		mission_details = saved_details.Copy()
	S["current_hub_mission"] >> current_hub_mission
	// Migrate the original shared offer table into the Quartermaster catalog.
	var/list/legacy_offers = list()
	for(var/offer_key in hub_trader_offers)
		if(ispath(offer_key, /obj/item))
			legacy_offers[offer_key] = hub_trader_offers[offer_key]
	if(length(legacy_offers))
		hub_trader_offers = list("Quartermaster" = legacy_offers)
		hub_trader_catalog["Quartermaster"] = list("buy" = legacy_offers.Copy(), "sell" = list())
		save()
	else if(!islist(saved_catalog))
		var/list/previous_quartermaster_offers = hub_trader_offers["Quartermaster"]
		if(islist(previous_quartermaster_offers))
			hub_trader_catalog["Quartermaster"] = list("buy" = previous_quartermaster_offers.Copy(), "sell" = list())
			save()
	if(!islist(hub_trader_catalog["Quartermaster"]))
		hub_trader_catalog["Quartermaster"] = list("buy" = list(), "sell" = list())

/datum/hub_campaign_state/proc/save()
	var/savefile/S = new /savefile("data/mission_hub_gm.sav")
	S["mission_queue"] << mission_queue
	S["mission_briefs"] << mission_briefs
	S["hub_trader_offers"] << hub_trader_offers
	S["hub_trader_catalog"] << hub_trader_catalog
	S["mission_details"] << mission_details
	S["current_hub_mission"] << current_hub_mission

/datum/hub_campaign_state/proc/get_group_stash()
	var/savefile/S = new /savefile("data/mission_hub_group_stash.sav")
	var/list/items
	S["items"] >> items
	return islist(items) ? items : list()

/datum/hub_campaign_state/proc/save_group_stash(list/items)
	var/savefile/S = new /savefile("data/mission_hub_group_stash.sav")
	S["items"] << items

/datum/hub_campaign_state/proc/serialize_group_item(obj/item/item, depth = 0)
	if(!item || depth > 10)
		return null
	var/list/record = list("type" = "[item.type]")
	var/list/state = list()
	var/list/unsafe_vars = list("type", "parent_type", "loc", "contents", "vars", "verbs", "vis_contents", "overlays", "underlays", "components", "datum_components", "reagents", "atom_storage", "hud_list", "actions", "fingerprints", "fingerprintslast", "client", "key", "ckey")
	for(var/variable in item.vars)
		if(variable in unsafe_vars)
			continue
		var/value = item.vars[variable]
		if((isnum(value) || istext(value) || ispath(value)) && value != initial(item.vars[variable]))
			state[variable] = value
	if(length(state))
		record["state"] = state
	if(istype(item, /obj/item/spacecash))
		var/obj/item/spacecash/cash = item
		record["worth"] = cash.worth
	var/list/contents = list()
	for(var/obj/item/contained_item in item.contents)
		var/list/child_record = serialize_group_item(contained_item, depth + 1)
		if(child_record)
			contents += list(child_record)
	if(length(contents))
		record["contents"] = contents
	return record

/datum/hub_campaign_state/proc/restore_group_item(list/record, atom/location)
	var/item_path = text2path(record?["type"])
	if(!ispath(item_path, /obj/item))
		return null
	var/obj/item/restored = new item_path(location)
	var/list/state = record["state"]
	if(islist(state))
		for(var/variable in state)
			if(!(variable in restored.vars) || variable in list("type", "parent_type", "loc", "contents", "vars", "verbs", "reagents", "atom_storage"))
				continue
			var/value = state[variable]
			if(isnum(value) || istext(value) || ispath(value))
				restored.vars[variable] = value
	if(istype(restored, /obj/item/spacecash) && isnum(record["worth"]))
		var/obj/item/spacecash/cash = restored
		cash.worth = record["worth"]
		cash.update_value()
		cash.update_icon()
	var/list/contents = record["contents"]
	if(islist(contents))
		for(var/list/child_record as anything in contents)
			restore_group_item(child_record, restored)
	return restored

/datum/hub_campaign_state/proc/get_group_stash_summary()
	var/list/summary = list()
	var/list/counts = list()
	for(var/list/stored as anything in get_group_stash())
		var/item_type = stored["type"]
		if(!counts[item_type])
			counts[item_type] = list("type" = item_type, "count" = 0, "total_worth" = 0)
		counts[item_type]["count"]++
		if(isnum(stored["worth"]))
			counts[item_type]["total_worth"] += stored["worth"]
	for(var/item_type in counts)
		var/list/entry = counts[item_type]
		var/item_path = text2path(item_type)
		if(ispath(item_path, /obj/item))
			summary += list(list("type" = item_type, "name" = initial(item_path:name), "count" = entry["count"], "total_worth" = entry["total_worth"]))
	return summary

/datum/game_master/proc/set_hub_trader_offer(mob/user, trader_role, item_path, price, direction = "buy")
	if(!can_manage_hub(user) || trader_role != "Quartermaster" || !ispath(item_path, /obj/item) || ispath(item_path, /obj/item/spacecash))
		return FALSE
	if(!(direction in list("buy", "sell")) || !isnum(price) || price < 0 || price > 1000000)
		return FALSE
	var/list/catalog = GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"]
	if(!islist(catalog))
		catalog = list("buy" = list(), "sell" = list())
	else
		catalog = catalog.Copy()
	var/list/role_offers = catalog[direction]
	if(!islist(role_offers))
		role_offers = list()
	else
		role_offers = role_offers.Copy()
	if(price == 0)
		role_offers -= item_path
	else
		role_offers[item_path] = round(price)
	catalog[direction] = role_offers
	GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"] = catalog
	GLOB.hub_campaign_state.hub_trader_offers["Quartermaster"] = catalog["buy"]
	GLOB.hub_campaign_state.save()
	var/direction_label = direction == "buy" ? "продажа игрокам" : "покупка у игроков"
	message_admins("[key_name_admin(user)] изменил цену квартирмейстера ([direction_label]) для [item_path]: [round(price)].")
	return TRUE

/mob/living/carbon/human/hub_trader
	name = "торговец"
	real_name = "Торговец"
	var/trader_role = "Quartermaster"

/mob/living/carbon/human/hub_trader/Initialize(mapload)
	. = ..()
	equip_to_slot_or_del(new /obj/item/clothing/under/liaison_suit/black(src), WEAR_BODY)
	equip_to_slot_or_del(new /obj/item/clothing/suit/storage/bomber/alt(src), WEAR_JACKET)
	equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(src), WEAR_FEET)
	equip_to_slot_or_del(new /obj/item/clothing/gloves/black(src), WEAR_HANDS)
	randomize_hub_identity()

/mob/living/carbon/human/hub_trader/proc/randomize_hub_identity()
	gender = pick(MALE, FEMALE)
	var/datum/preferences/random_preferences = new
	random_preferences.randomize_appearance(src)
	change_real_name(src, random_name(gender))
	update_body()
	update_hair()
	qdel(random_preferences)

/mob/living/carbon/human/hub_trader/quartermaster
	trader_role = "Quartermaster"

/datum/game_master/proc/get_hub_trader_type(profile)
	if(profile == "Quartermaster")
		return /mob/living/carbon/human/hub_trader/quartermaster
	return null

/mob/living/carbon/human/hub_trader/attack_hand(mob/user)
	if(!ishuman(user) || !user.Adjacent(src))
		return ..()
	user.set_interaction(src)
	var/list/greetings = list("Ну, удачной охоты", "Алоха!", "Хабар принес?", "Время — деньги, друг!", "В такие времена не стоит сорить деньгами... Но всё же посмотри, что у меня есть!", "Если не убьёшься там, заходи ещё!", "Слушай, повезло тебе сегодня, дорогой, только сейчас куплю задорого, продам задёшево!", "Я тебе один умный вещь скажу, только ты не обижайся. Слушай, деньги — не главное.")
	say(pick(greetings))
	tgui_interact(user)
	return TRUE

/mob/living/carbon/human/hub_trader/attackby(obj/item/W, mob/living/user)
	var/datum/game_master/gm = user?.client?.game_master_menu
	if(!gm || !gm.can_manage_hub(user) || W.loc != user)
		return ..()
	var/direction = tgui_alert(user, "[W.name]: выберите вкладку для этого товара", "Настройка торговца", list("Купить (торговец продаёт)", "Продать (торговец покупает)", "Отмена"))
	if(direction == "Отмена" || isnull(direction) || QDELETED(W) || !user.Adjacent(src))
		return TRUE
	var/catalog_direction = direction == "Купить (торговец продаёт)" ? "buy" : "sell"
	var/price = tgui_input_number(user, "Цена наличными. Введите 0, чтобы убрать предмет из выбранной вкладки.", "[direction]: [W.name]", 100, 1000000, 0)
	if(isnull(price) || QDELETED(W) || !user.Adjacent(src))
		return TRUE
	gm.set_hub_trader_offer(user, trader_role, W.type, price, catalog_direction)
	SStgui.update_uis(src)
	return TRUE

/mob/living/carbon/human/hub_trader/ui_state(mob/user)
	return GLOB.physical_state

/mob/living/carbon/human/hub_trader/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MissionHubTrader", "[trader_role] — [real_name]")
		ui.open()

/mob/living/carbon/human/hub_trader/ui_data(mob/user)
	var/list/data = list("offers" = list(), "sellables" = list(), "sell_prices" = list(), "can_manage" = (user?.client && check_client_rights(user.client, R_ADMIN, FALSE)), "trader_role" = trader_role)
	var/list/catalog = GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"]
	var/list/buy_offers = catalog?["buy"]
	var/list/sell_offers = catalog?["sell"]
	if(!islist(buy_offers))
		buy_offers = list()
	if(!islist(sell_offers))
		sell_offers = list()
	for(var/item_path in buy_offers)
		data["offers"] += list(list("name" = initial(item_path:name), "price" = buy_offers[item_path], "path" = "[item_path]"))
	for(var/item_path in sell_offers)
		data["sell_prices"] += list(list("name" = initial(item_path:name), "price" = sell_offers[item_path], "path" = "[item_path]"))
	if(ishuman(user))
		for(var/obj/item/sell_item in user.contents)
			if(istype(sell_item, /obj/item/spacecash) || isnull(sell_offers[sell_item.type]))
				continue
			data["sellables"] += list(list("name" = sell_item.name, "price" = sell_offers[sell_item.type], "ref" = REF(sell_item)))
	return data

/mob/living/carbon/human/hub_trader/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!user.Adjacent(src))
		return TRUE
	if(action == "buy")
		var/item_path = text2path(params["path"])
		if(!ispath(item_path, /obj/item) || ispath(item_path, /obj/item/spacecash))
			return TRUE
		var/list/catalog = GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"]
		var/list/role_offers = catalog?["buy"]
		var/price = role_offers?[item_path]
		if(!isnum(price) || !hub_take_cash(user, price))
			to_chat(user, SPAN_WARNING("Не хватает наличных."))
			return TRUE
		var/obj/item/purchased = new item_path(get_turf(src))
		user.put_in_hands(purchased)
		return TRUE
	if(action == "sell")
		var/obj/item/sold_item = locate(params["ref"])
		if(!istype(sold_item) || sold_item.loc != user || istype(sold_item, /obj/item/spacecash))
			return TRUE
		var/list/catalog = GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"]
		var/list/role_offers = catalog?["sell"]
		var/sale_price = role_offers?[sold_item.type]
		if(!isnum(sale_price))
			return TRUE
		qdel(sold_item)
		var/obj/item/spacecash/bundle/payment = new(get_turf(src))
		payment.worth = sale_price
		payment.update_icon()
		user.put_in_hands(payment)
		return TRUE
	if(action == "remove_offer")
		var/item_path = text2path(params["path"])
		var/direction = params["direction"]
		if(!user?.client || !check_client_rights(user.client, R_ADMIN, FALSE) || !ispath(item_path, /obj/item) || !(direction in list("buy", "sell")))
			return TRUE
		var/list/catalog = GLOB.hub_campaign_state.hub_trader_catalog["Quartermaster"]
		var/list/role_offers = catalog?[direction]
		if(islist(role_offers))
			role_offers -= item_path
			catalog[direction] = role_offers
			GLOB.hub_campaign_state.hub_trader_offers["Quartermaster"] = catalog["buy"]
		GLOB.hub_campaign_state.save()
		SStgui.update_uis(src)
		return TRUE
	return FALSE

/proc/hub_take_cash(mob/living/carbon/human/user, amount)
	if(!user || amount <= 0)
		return FALSE
	var/list/cash_items = list()
	var/total = 0
	for(var/obj/item/spacecash/cash in user.contents)
		if(cash.counterfeit)
			continue
		cash_items += cash
		total += cash.worth
	if(total < amount)
		return FALSE
	var/remaining = total - amount
	for(var/obj/item/spacecash/cash in cash_items)
		if(remaining >= cash.worth)
			remaining -= cash.worth
			continue
		qdel(cash)
	if(remaining > 0)
		var/obj/item/spacecash/bundle/change = new(user.loc)
		change.worth = remaining
		change.update_icon()
		user.put_in_hands(change)
	return TRUE

/obj/structure/closet/hub_persistent_stash
	name = "общий склад группы"
	desc = "Общий склад снаряжения и наличных для всех операций."

/obj/structure/closet/hub_persistent_stash/attackby(obj/item/item, mob/user)
	if(!ishuman(user) || !istype(item, /obj/item))
		return ..()
	if(!user.Adjacent(src) || item.loc != user)
		return
	var/list/items = GLOB.hub_campaign_state.get_group_stash()
	if(length(items) >= 100)
		to_chat(user, SPAN_WARNING("Склад группы заполнен."))
		return
	if(istype(item, /obj/item/spacecash))
		var/obj/item/spacecash/cash = item
		if(cash.counterfeit)
			to_chat(user, SPAN_WARNING("Поддельные деньги нельзя положить на склад."))
			return
	var/list/stored_item = GLOB.hub_campaign_state.serialize_group_item(item)
	if(!stored_item)
		return
	items += list(stored_item)
	if(!user.drop_inv_item_to_loc(item, src))
		return
	GLOB.hub_campaign_state.save_group_stash(items)
	qdel(item)
	to_chat(user, SPAN_NOTICE("Предмет добавлен на склад группы."))

/obj/structure/closet/hub_persistent_stash/attack_hand(mob/user)
	if(!ishuman(user))
		return ..()
	var/list/items = GLOB.hub_campaign_state.get_group_stash()
	if(!islist(items) || !length(items))
		to_chat(user, SPAN_NOTICE("Склад группы пуст."))
		return
	var/list/item_options = list()
	var/item_option_index = 0
	for(var/list/stored_item as anything in items)
		item_option_index++
		var/item_type_text = stored_item["type"]
		var/item_path_option = text2path(item_type_text)
		if(!ispath(item_path_option, /obj/item))
			continue
		var/item_label = initial(item_path_option:name)
		if(istype(item_path_option, /obj/item/spacecash))
			item_label = "$[stored_item["worth"]] [item_label]"
		item_options["[item_option_index]. [item_label]"] = stored_item
	var/selection = tgui_input_list(user, "Выберите предмет или наличные со склада группы", name, item_options)
	var/list/selected_item = item_options[selection]
	if(!selected_item || !user.Adjacent(src) || !(selected_item in items))
		return
	var/selected_index = items.Find(selected_item)
	if(!selected_index)
		return
	var/obj/item/retrieved = GLOB.hub_campaign_state.restore_group_item(selected_item, get_turf(src))
	if(!retrieved)
		return
	items.Cut(selected_index, selected_index + 1)
	GLOB.hub_campaign_state.save_group_stash(items)
	user.put_in_hands(retrieved)

/datum/game_master/proc/can_manage_hub(mob/user)
	return user?.client && check_client_rights(user.client, R_ADMIN, FALSE)

/datum/game_master/proc/issue_group_stash_item(mob/user, item_type)
	if(!can_manage_hub(user) || !istext(item_type))
		return FALSE
	var/item_path = text2path(item_type)
	if(!ispath(item_path, /obj/item))
		return FALSE
	var/obj/structure/closet/hub_persistent_stash/group_locker
	for(var/obj/structure/closet/hub_persistent_stash/locker in world)
		group_locker = locker
		break
	if(!group_locker)
		return FALSE
	var/list/items = GLOB.hub_campaign_state.get_group_stash()
	var/list/recipients = list()
	var/area/group_area = get_area(group_locker)
	for(var/mob/living/carbon/human/recipient in GLOB.player_list)
		if(recipient.stat == DEAD || get_area(recipient) != group_area)
			continue
		recipients += recipient
	if(!length(recipients))
		to_chat(user, SPAN_WARNING("В зоне склада нет живых участников группы."))
		return FALSE
	var/list/issued = list()
	for(var/i in 1 to length(items))
		var/list/entry = items[i]
		if(entry["type"] == item_type)
			issued += i
			if(length(issued) >= length(recipients))
				break
	if(length(issued) < length(recipients))
		to_chat(user, SPAN_WARNING("На складе недостаточно копий для всех присутствующих."))
		return FALSE
	for(var/r in 1 to length(recipients))
		var/item_index = issued[length(issued) - r + 1]
		var/list/entry = items[item_index]
		var/obj/item/gift = GLOB.hub_campaign_state.restore_group_item(entry, get_turf(recipients[r]))
		if(!gift)
			continue
		recipients[r].put_in_hands(gift)
		items.Cut(item_index, item_index + 1)
	GLOB.hub_campaign_state.save_group_stash(items)
	message_admins("[key_name_admin(user)] выдал участникам группы [length(recipients)] предметов: [initial(item_path:name)].")
	return TRUE

/datum/game_master/proc/queue_hub_mission(mob/user)
	if(!can_manage_hub(user))
		return FALSE
	if(length(GLOB.hub_campaign_state.mission_queue) >= GM_HUB_MAX_MISSIONS)
		return FALSE
	var/operation_name = tgui_input_text(user, "Название операции", "Новая операция", "", 64)
	if(isnull(operation_name) || !length(trim(operation_name)))
		return FALSE
	operation_name = trim(operation_name)
	if(operation_name in GLOB.hub_campaign_state.mission_queue)
		return FALSE
	var/reward = tgui_input_number(user, "Стоимость за работу (награда группе)", "Оплата за задание", 0, 1000000, 0)
	if(isnull(reward))
		return FALSE
	var/objective = tgui_input_text(user, "Что нужно достать", "Цель операции", multiline = TRUE, max_length = 512)
	if(isnull(objective))
		return FALSE
	var/extra_text = tgui_input_text(user, "Дополнительный текст", "Информация для игроков", multiline = TRUE, max_length = 512)
	if(isnull(extra_text))
		return FALSE
	GLOB.hub_campaign_state.mission_queue += operation_name
	GLOB.hub_campaign_state.mission_details[operation_name] = list("reward" = round(reward), "objective" = trim(objective), "extra_text" = trim(extra_text))
	GLOB.hub_campaign_state.save()
	message_admins("[key_name_admin(user)] добавил операцию «[operation_name]» в список.")
	return TRUE

/datum/game_master/proc/remove_hub_mission(mob/user, mission_id)
	if(!can_manage_hub(user) || !(mission_id in GLOB.hub_campaign_state.mission_queue))
		return FALSE
	GLOB.hub_campaign_state.mission_queue -= mission_id
	GLOB.hub_campaign_state.mission_briefs -= mission_id
	GLOB.hub_campaign_state.mission_details -= mission_id
	GLOB.hub_campaign_state.save()
	message_admins("[key_name_admin(user)] удалил операцию «[mission_id]» из списка.")
	return TRUE

/datum/hub_campaign_state/proc/select_hub_mission(mob/user, mission_id)
	if(!ishuman(user) || !(mission_id in mission_queue))
		return FALSE
	current_hub_mission = mission_id
	mission_queue -= mission_id
	var/list/details = mission_details[mission_id]
	var/objective_text = islist(details) ? details["objective"] : mission_briefs[mission_id]
	var/extra_text = islist(details) ? details["extra_text"] : ""
	var/reward = islist(details) ? details["reward"] : 0
	save()
	to_chat(world, SPAN_NOTICE("<b>ВЫБРАНА ОПЕРАЦИЯ: [mission_id]</b><br><b>Что нужно достать:</b> [objective_text]<br><b>Дополнительно:</b> [extra_text]<br><b>Оплата за выполнение:</b> $[reward]. Выдачей занимается ГМ."))
	return TRUE

/datum/hub_campaign_state/proc/get_mission_options(mob/user)
	var/list/options = list()
	for(var/mission_id in mission_queue)
		var/list/details = mission_details[mission_id]
		options += list(list(
			"id" = mission_id,
			"name" = mission_id,
			"reward" = islist(details) ? details["reward"] : 0,
			"objective" = islist(details) ? details["objective"] : mission_briefs[mission_id],
			"extra_text" = islist(details) ? details["extra_text"] : ""
		))
	return options

/obj/structure/machinery/computer/hub_mission_console
	name = "консоль выбора операции"
	desc = "Любой игрок может выбрать следующую операцию. За выполненную работу ГМ выдаёт оплату вручную."
	icon_state = "computer_generic"
	use_power = USE_POWER_NONE

/obj/structure/machinery/computer/hub_mission_console/ui_state(mob/user)
	return GLOB.not_incapacitated_and_adjacent_state

/obj/structure/machinery/computer/hub_mission_console/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MissionSelectionConsole", name)
		ui.open()

/obj/structure/machinery/computer/hub_mission_console/ui_data(mob/user)
	var/current_details = GLOB.hub_campaign_state.mission_details[GLOB.hub_campaign_state.current_hub_mission]
	return list(
		"current_mission" = GLOB.hub_campaign_state.current_hub_mission,
		"current_objective" = islist(current_details) ? current_details["objective"] : null,
		"current_extra_text" = islist(current_details) ? current_details["extra_text"] : null,
		"current_reward" = islist(current_details) ? current_details["reward"] : null,
		"can_select" = ishuman(user),
		"missions" = GLOB.hub_campaign_state.get_mission_options(user)
	)

/obj/structure/machinery/computer/hub_mission_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(action != "select_mission" || !ishuman(user) || !user.Adjacent(src))
		return
	if(GLOB.hub_campaign_state.select_hub_mission(user, params["mission_id"]))
		. = TRUE
		SStgui.update_uis(src)

/obj/structure/machinery/computer/hub_mission_console/attack_hand(mob/user)
	if(..())
		return
	tgui_interact(user)
	return TRUE

#undef GM_HUB_MAX_MISSIONS
