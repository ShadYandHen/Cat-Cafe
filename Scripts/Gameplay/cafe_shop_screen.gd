extends Control
## Shared scrollable shop. Only profile/session APIs can mutate permanent state.
var session: CafeSession
var cafe_screen: Control
var upgrade_cards: Dictionary = {}
var decoration_cards: Dictionary = {}
var slot_cards: Dictionary = {}
var quote_levels: Dictionary = {}
var _metrics: Array = []

func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name=node_name
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name=node_name
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func setup(model: CafeSession, owner_screen: Control) -> void:
	session=model
	cafe_screen=owner_screen
	$Content/Layout/Tabs/Upgrades.pressed.connect(session.open_shop.bind(false))
	$Content/Layout/Tabs/Decorate.pressed.connect(session.open_shop.bind(true))
	$Content/Layout/Settings.pressed.connect(cafe_screen.get_node("SettingsPanel").open)
	$Content/Layout/Back.pressed.connect(session.back_to_cafe)
	_button($Content/Layout/Scroll/Body,"GoldenPaw",session.open_rewards).text="Golden Paw Lottery\nCollections · Level 50"
	for entry in CafeProfile.cafe_catalog.upgrades:
		var card := VBoxContainer.new()
		card.name=entry.id
		$Content/Layout/Scroll/Body/Upgrades.add_child(card)
		_label(card,"Description").text=entry.name+"\n"+entry.description
		_label(card,"State")
		_button(card,"Review",_review.bind(entry.id)).text="Review next level"
		_button(card,"Buy",_buy_upgrade.bind(entry.id)).theme_type_variation=&"PrimaryButton"
		upgrade_cards[entry.id]=card
	for slot in CafeCatalog.SLOT_IDS:
		var row := VBoxContainer.new()
		row.name=slot
		$Content/Layout/Scroll/Body/Slots.add_child(row)
		_label(row,"Description")
		_button(row,"Clear",_clear_slot.bind(slot)).text="Unequip"
		slot_cards[slot]=row
	for entry in CafeProfile.cafe_catalog.decorations:
		var card := VBoxContainer.new()
		card.name=entry.id
		$Content/Layout/Scroll/Body/Decorations.add_child(card)
		_label(card,"Description").text=entry.name+"\n"+entry.category+" · "+entry.rarity
		_label(card,"State")
		_button(card,"Buy",_buy_decoration.bind(entry.id)).theme_type_variation=&"PrimaryButton"
		_button(card,"Equip",_equip.bind(entry.id)).theme_type_variation=&"MintButton"
		decoration_cards[entry.id]=card
	session.changed.connect(refresh)
	session.clock_changed.connect(refresh)
	on_open()

func on_open() -> void:
	$Content/Layout/Scroll.scroll_vertical=0
	for id in upgrade_cards:
		quote_levels[id]=session.profile.upgrade_level(id)
	refresh()

func _review(id: String) -> void:
	quote_levels[id]=session.profile.upgrade_level(id)
	session.shop_feedback="Next level reviewed; check its price and unlock requirement"
	refresh()

func _buy_upgrade(id: String) -> void:
	session.buy_upgrade(id,quote_levels.get(id,-1))

func _buy_decoration(id: String) -> void:
	session.buy_decoration(id)

func _equip(id: String) -> void:
	session.equip_decoration(CafeProfile.cafe_catalog.decoration(id).slot,id)

func _clear_slot(slot: String) -> void:
	session.equip_decoration(slot,"")

func refresh() -> void:
	if session==null:
		return
	var decorations := session.view==CafeSession.View.DECORATE
	var editable := session.can_edit_cafe()
	$Content/Layout/Heading.text="Decorate" if decorations else "Café Upgrades"
	$Content/Layout/Status.text="Coins %d · Café Level %d\n%s" % [session.coins,session.profile.level,"Edit before opening or after results" if editable else "View only: finish the shift and save its results"]
	if not session.shop_feedback.is_empty():
		$Content/Layout/Status.text+="\n"+session.shop_feedback
	$Content/Layout/Tabs/Upgrades.theme_type_variation=&"Button" if decorations else &"MintButton"
	$Content/Layout/Tabs/Decorate.theme_type_variation=&"MintButton" if decorations else &"Button"
	$Content/Layout/Scroll/Body/Upgrades.visible=not decorations
	$Content/Layout/Scroll/Body/Slots.visible=decorations
	$Content/Layout/Scroll/Body/Decorations.visible=decorations
	for entry in CafeProfile.cafe_catalog.upgrades:
		var card: VBoxContainer=upgrade_cards[entry.id]
		var offer := session.profile.upgrade_offer(entry.id)
		var current := session.profile.upgrade_level(entry.id)
		var quote_matches: bool = quote_levels.get(entry.id,-1)==current
		var bonus := "+%d quality points" % int(entry.value_per_level) if entry.effect=="quality" else "+%d%% %s" % [roundi(entry.value_per_level*100),entry.effect]
		card.get_node("State").text="Level %d/%d · %s per level\n%s" % [current,int(entry.max_level),bonus,offer.reason]
		if offer.has("cost"):
			card.get_node("State").text+="\nNext: %d Coins · Requires Level %d" % [offer.cost,offer.required]
		var buy := card.get_node("Buy") as Button
		buy.text="Buy Level %d · %d Coins" % [current+1,int(offer.get("cost",0))] if current<int(entry.max_level) else "Maximum level"
		if not quote_matches:
			buy.text="Purchased · review next level"
		buy.disabled=not editable or not offer.allowed or not quote_matches
		card.get_node("Review").disabled=not editable or current>=int(entry.max_level) or quote_matches
	var slots := session.profile.equipped_decorations()
	for i in range(CafeCatalog.SLOT_IDS.size()):
		var slot: String=CafeCatalog.SLOT_IDS[i]
		var id: String=slots[slot]
		slot_cards[slot].get_node("Description").text=CafeCatalog.SLOT_NAMES[i]+": "+(CafeProfile.cafe_catalog.decoration(id).name if not id.is_empty() else "Empty")
		slot_cards[slot].get_node("Clear").disabled=not editable or id.is_empty()
	for entry in CafeProfile.cafe_catalog.decorations:
		var card: VBoxContainer=decoration_cards[entry.id]
		var offer := session.profile.decoration_offer(entry.id)
		var owned := session.profile.owns_decoration(entry.id)
		card.get_node("State").text="%d Coins · Requires Level %d\n%s" % [int(entry.price),int(entry.minimum_reputation),"Owned" if owned else offer.reason]
		card.get_node("Buy").text="Owned" if owned else "Buy · %d Coins" % int(entry.price)
		if entry.rarity=="exclusive":
			card.get_node("State").text="Exclusive reward · "+("Owned" if owned else "Golden Paw Lottery or future seasonal release")
			card.get_node("Buy").text="Owned" if owned else "Reward only"
		card.get_node("Buy").disabled=not editable or not offer.allowed
		var equipped: bool = slots[entry.slot]==entry.id
		card.get_node("Equip").text="Displayed" if equipped else "Display: "+CafeCatalog.SLOT_NAMES[CafeCatalog.SLOT_IDS.find(entry.slot)]
		card.get_node("Equip").disabled=not editable or not owned or equipped
	$Content/Layout/Back.text="Back to opening" if session.phase==CafeSession.Phase.PRE_DAY else "Back to results" if session.phase==CafeSession.Phase.RESULTS else "Back to café"

func _process(_delta: float) -> void:
	if cafe_screen==null:
		return
	var bounds: Control=cafe_screen.get_node("Content")
	$Content.position=bounds.position
	$Content.size=bounds.size
	var factor: float=cafe_screen.ui_scale
	var metrics: Array=[factor,bounds.size]
	if metrics==_metrics:
		return
	_metrics=metrics
	for side in ["left","right","top","bottom"]:
		$Content.add_theme_constant_override("margin_"+side,ceili(12/factor))
	$Content/Layout.add_theme_constant_override("separation",ceili(8/factor))
	$Content/Layout/Scroll/Body.add_theme_constant_override("separation",ceili(16/factor))
	var text_size := ceili(maxf(28,16/factor))
	var controls: Array[Node]=find_children("*","Control",true,false)
	for control in controls:
		if control is Label:
			control.add_theme_font_size_override("font_size",text_size)
		elif control is Button:
			control.add_theme_font_size_override("font_size",text_size)
			control.custom_minimum_size.y=ceili(48/factor)
		elif control is VBoxContainer and control!= $Content/Layout:
			control.add_theme_constant_override("separation",ceili(10/factor))
	$Content/Layout/Heading.add_theme_font_size_override("font_size",ceili(maxf(36,22/factor)))
