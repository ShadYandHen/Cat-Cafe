extends Control
## Presentation only. Profile transactions own every ticket, item and Coin.
var session: CafeSession
var cafe_screen: Control
var collection_tab := false
var feedback := ""
var quote_sequence := 1
var results: Array = []
var cards: Dictionary = {}
var roll_one: Button
var roll_ten: Button
var review: Button
var resolve: Button
var summary: Label
var outcome_text: Label
var history_text: Label
var cycle_text: Label
var badge_text: Label
var lottery_body: VBoxContainer
var collection_body: VBoxContainer
var _metrics: Array=[]

func label(parent: Node, text: String) -> Label:
	var node := Label.new()
	node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text=text
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func setup(model: CafeSession, owner_screen: Control) -> void:
	session=model
	cafe_screen=owner_screen
	$Content/Layout/Tabs/Lottery.pressed.connect(show_tab.bind(false))
	$Content/Layout/Tabs/Collections.pressed.connect(show_tab.bind(true))
	$Content/Layout/Settings.pressed.connect(cafe_screen.get_node("SettingsPanel").open)
	$Content/Layout/Back.pressed.connect(session.back_to_cafe)
	lottery_body=VBoxContainer.new()
	$Content/Layout/Scroll/Body.add_child(lottery_body)
	label(lottery_body,"50%: 500 Coins · 24%: regular cosmetic\n24%: regular decoration · 2%: exclusive\nTen independent rolls. No rarity guarantee.")
	resolve=button(lottery_body,"Resolve pending Level 50 rewards",resolve_pending)
	roll_one=button(lottery_body,"Roll 1 · 1 ticket",roll.bind(1))
	roll_one.theme_type_variation=&"PrimaryButton"
	roll_ten=button(lottery_body,"Roll 10 · 10 tickets",roll.bind(10))
	roll_ten.theme_type_variation=&"PrimaryButton"
	review=button(lottery_body,"Review tickets for another roll",review_roll)
	outcome_text=label(lottery_body,"")
	history_text=label(lottery_body,"")
	cycle_text=label(lottery_body,"")
	collection_body=VBoxContainer.new()
	$Content/Layout/Scroll/Body.add_child(collection_body)
	summary=label(collection_body,"")
	badge_text=label(collection_body,"")
	button(collection_body,"Unequip café badge",equip.bind(""))
	for entry in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		var card := VBoxContainer.new()
		collection_body.add_child(card)
		label(card,entry.name+" · "+entry.rarity)
		var state := label(card,"")
		var equip_button := button(card,"Equip",equip_item.bind(entry.id))
		cards[entry.id]={"state":state,"button":equip_button}
	session.changed.connect(refresh)
	on_open()

func on_open() -> void:
	quote_sequence=int(session.profile.snapshot().next_roll_sequence)
	feedback=""
	refresh()

func show_tab(collections: bool) -> void:
	collection_tab=collections
	$Content/Layout/Scroll.scroll_vertical=0
	refresh()

func review_roll() -> void:
	quote_sequence=int(session.profile.snapshot().next_roll_sequence)
	feedback="Tickets reviewed; choose Roll 1 or Roll 10"
	refresh()

func roll(count: int) -> void:
	var p := session.profile
	if not session.can_edit_cafe():
		feedback="View only during shifts"
	elif p.roll_lottery(count,quote_sequence):
		results=p.last_roll_results.duplicate(true)
		feedback="%d reward(s) saved. Review before rolling again." % count
		call_deferred("show_results")
	else:
		feedback=p.last_error
	p.last_error=""
	refresh()

func show_results() -> void:
	await get_tree().process_frame
	$Content/Layout/Scroll.scroll_vertical=int(outcome_text.position.y)

func resolve_pending() -> void:
	if not session.can_edit_cafe():
		feedback="View only during shifts"
	else:
		feedback="Pending rewards saved" if session.profile.resolve_level50_rewards() else session.profile.last_error
		session.profile.last_error=""
	refresh()

func equip(id: String) -> void:
	if not session.can_edit_cafe():
		feedback="View only during shifts"
	else:
		feedback="Café badge saved" if session.profile.equip_cosmetic(id) else session.profile.last_error
		session.profile.last_error=""
	refresh()

func equip_item(id: String) -> void:
	if not CafeProfile.reward_catalog.cosmetic(id).is_empty():
		equip(id)
	elif session.can_edit_cafe():
		var entry := CafeProfile.cafe_catalog.decoration(id)
		feedback="Decoration display saved" if session.profile.equip_decoration(entry.slot,id) else session.profile.last_error
		session.profile.last_error=""
		refresh()

func describe(reward: Dictionary) -> String:
	var item := ""
	if not reward.item_id.is_empty():
		var entry := CafeProfile.reward_catalog.cosmetic(reward.item_id)
		if entry.is_empty():
			entry=CafeProfile.cafe_catalog.decoration(reward.item_id)
		item=entry.get("name",reward.item_id)
	var text := "%d Coins" % int(reward.coins) if reward.coins>0 else item
	if reward.duplicate_fallback:
		text+=" (duplicate: "+item+")"
	elif not reward.fallback.is_empty():
		text+=" (collection exhausted)"
	return "#%d · %s" % [int(reward.sequence),text]

func refresh() -> void:
	if session==null:
		return
	var p := session.profile
	var data := p.snapshot()
	var editable := session.can_edit_cafe()
	$Content/Layout/Heading.text="Collections" if collection_tab else "Golden Paw Lottery"
	$Content/Layout/Status.text="Level %d · Tickets %d · Coins %d\n%s" % [p.level,p.tickets,p.coins,"Unlocked" if p.level>=50 else "Lottery unlocks at Café Level 50"]
	if not editable:
		$Content/Layout/Status.text+=" · View only"
	if not feedback.is_empty():
		$Content/Layout/Status.text+="\n"+feedback
	lottery_body.visible=not collection_tab
	collection_body.visible=collection_tab
	$Content/Layout/Tabs/Lottery.theme_type_variation=&"Button" if collection_tab else &"MintButton"
	$Content/Layout/Tabs/Collections.theme_type_variation=&"MintButton" if collection_tab else &"Button"
	var stale: bool=quote_sequence!=int(data.next_roll_sequence)
	roll_one.disabled=not editable or p.level<50 or p.tickets<1 or stale
	roll_ten.disabled=not editable or p.level<50 or p.tickets<10 or stale
	review.disabled=not editable or not stale
	resolve.visible=p.pending_tickets>0
	resolve.disabled=not editable
	outcome_text.text="Latest results (already awarded)"
	for reward in results:
		outcome_text.text+="\n"+describe(reward)
	history_text.text="Recent history · last %d rolls" % data.lottery_history.size()
	for i in range(data.lottery_history.size()-1,-1,-1):
		history_text.text+="\n"+describe(data.lottery_history[i])
	cycle_text.text="Level 50 cycle rewards · already awarded\nEach cycle: one ticket + a separate reward"
	for i in range(maxi(0,data.cycle_rewards.size()-5),data.cycle_rewards.size()):
		var reward: Dictionary=data.cycle_rewards[i].duplicate(true)
		reward.sequence=reward.cycle_id
		cycle_text.text+="\nCycle "+describe(reward).trim_prefix("#")
	var counts := p.collections()
	summary.text="Collections · eligible released items"
	for group in RewardCatalog.GROUPS:
		var row: Dictionary=counts[group]
		summary.text+="\n%s: %d/%d (%.0f%%)" % [group.replace("_"," ").capitalize(),row.owned,row.total,row.percent]
	var badge: String=data.equipped_cosmetics.cafe_badge
	badge_text.text="Equipped café badge: "+("None" if badge.is_empty() else CafeProfile.reward_catalog.cosmetic(badge).name)
	badge_text.modulate=Color.WHITE if badge.is_empty() else Color(CafeProfile.reward_catalog.cosmetic(badge).color)
	collection_body.get_child(2).disabled=not editable or badge.is_empty()
	for entry in CafeProfile.reward_catalog.all_items(CafeProfile.cafe_catalog.decorations):
		var cosmetic := not CafeProfile.reward_catalog.cosmetic(entry.id).is_empty()
		var owned := p.owns_cosmetic(entry.id) if cosmetic else p.owns_decoration(entry.id)
		var eligible := RewardCatalog.eligible(entry,data.released_seasons)
		cards[entry.id].state.text=("Owned" if owned else "Not owned") + (" · Seasonal preview: not released" if not eligible else "")
		var equipped: bool=badge==entry.id if cosmetic else data.equipped_decorations[entry.slot]==entry.id
		cards[entry.id].button.text="Equipped" if equipped else "Equip café badge" if cosmetic else "Display in café"
		cards[entry.id].button.disabled=not editable or not owned or equipped
	$Content/Layout/Back.text="Back to opening" if session.phase==CafeSession.Phase.PRE_DAY else "Back to results" if session.phase==CafeSession.Phase.RESULTS else "Back to café"

func _process(_delta: float) -> void:
	if cafe_screen==null:
		return
	var bounds: Control=cafe_screen.get_node("Content")
	$Content.position=bounds.position
	$Content.size=bounds.size
	var factor: float=cafe_screen.ui_scale
	# Include dynamic feedback to reapply sizing after any rebuilt label wraps.
	var metrics: Array=[factor,bounds.size]
	if metrics==_metrics:
		return
	_metrics=metrics
	for side in ["left","right","top","bottom"]:
		$Content.add_theme_constant_override("margin_"+side,ceili(12/factor))
	$Content/Layout.add_theme_constant_override("separation",ceili(8/factor))
	for control in find_children("*","Control",true,false):
		if control is Label or control is Button:
			control.add_theme_font_size_override("font_size",ceili(maxf(28,16/factor)))
		if control is Button:
			control.custom_minimum_size.y=ceili(48/factor)
		if control is VBoxContainer:
			control.add_theme_constant_override("separation",ceili(12/factor))
	$Content/Layout/Heading.add_theme_font_size_override("font_size",ceili(maxf(36,22/factor)))
