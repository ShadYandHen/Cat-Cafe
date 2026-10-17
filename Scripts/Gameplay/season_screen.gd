extends Control
## Read-only projections and manual claims; permanent state lives in CafeProfile.
var session: CafeSession
var cafe_screen: Control
var inbox_tab := false
var feedback := ""
var pass_body: VBoxContainer
var inbox_body: VBoxContainer
var daily: Label
var weekly: Label
var pass_cards: Dictionary={}
var inbox_cards: Dictionary={}
var inbox_hint: Label
var _metrics: Array=[]
var _last_second := -1

func label(parent: Node, text: String) -> Label:
	var node := Label.new()
	node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text=text
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func setup(model: CafeSession, owner_screen: Control) -> void:
	session=model
	cafe_screen=owner_screen
	$Content/Layout/Tabs/Pass.pressed.connect(show_tab.bind(false))
	$Content/Layout/Tabs/Inbox.pressed.connect(show_tab.bind(true))
	$Content/Layout/Settings.pressed.connect(cafe_screen.get_node("SettingsPanel").open)
	$Content/Layout/Back.pressed.connect(session.back_to_cafe)
	pass_body=VBoxContainer.new()
	$Content/Layout/Scroll/Body.add_child(pass_body)
	label(pass_body, "") # Filled from the authoritative catalog in refresh().
	daily=label(pass_body,"")
	weekly=label(pass_body,"")
	for reward in CafeProfile.season_catalog.data.milestones:
		var card := VBoxContainer.new()
		pass_body.add_child(card)
		var description := label(card,"")
		var claim := button(card,"Claim",claim_tier.bind(int(reward.tier)))
		claim.theme_type_variation=&"PrimaryButton"
		pass_cards[int(reward.tier)]={"description":description,"claim":claim}
	inbox_body=VBoxContainer.new()
	$Content/Layout/Scroll/Body.add_child(inbox_body)
	inbox_hint=label(inbox_body,"Earned rewards never expire. Claims are manual.")
	session.changed.connect(refresh)
	refresh()

func on_open() -> void:
	feedback=""
	refresh()

func show_tab(inbox: bool) -> void:
	inbox_tab=inbox
	$Content/Layout/Scroll.scroll_vertical=0
	refresh()

func reward_name(kind: String, payload: Dictionary) -> String:
	if kind=="coins":
		return "%d Coins" % int(payload.coins)
	var entry := CafeProfile.reward_catalog.cosmetic(payload.item_id) if kind=="cosmetic" else CafeProfile.cafe_catalog.decoration(payload.item_id)
	return entry.get("name",payload.item_id)

func claim_tier(tier: int) -> void:
	var state := session.profile.seasonal_state()
	if not state.current.is_empty():
		claim("%s:tier:%d" % [state.current.id,tier])

func claim(id: String) -> void:
	if not session.can_edit_cafe():
		feedback="View only: finish the shift before claiming"
	else:
		feedback="Reward claimed and saved" if session.profile.claim_inbox(id) else session.profile.last_error
		session.profile.last_error=""
	refresh()

static func remaining(seconds: int) -> String:
	seconds=maxi(0,seconds)
	return "%dd %dh %dm" % [int(seconds/86400),int(seconds%86400/3600),int(seconds%3600/60)]

func challenge_text(state: Dictionary, cadence: String, now: int) -> String:
	var challenge: Dictionary=state.current[cadence]
	var definition := CafeProfile.season_catalog.challenge_definition(cadence,challenge.id)
	return "%s · %s\n%d/%d · %s · %d Seasonal XP" % [cadence.capitalize(),definition.label,challenge.progress,int(definition.target),"Completed" if challenge.completed else remaining(int(challenge.end)-now),int(CafeProfile.season_catalog.data[cadence+"_xp"])]

func refresh() -> void:
	if session==null:
		return
	var state := session.profile.seasonal_state()
	$Content/Layout/Heading.text="Reward Inbox" if inbox_tab else "Season Pass"
	if state.current.is_empty():
		$Content/Layout/Status.text="Season calendar unavailable; check save diagnostics"
		pass_body.hide()
		inbox_body.hide()
		return
	var current: Dictionary=state.current
	var now := session.profile.seasonal_now()
	var tier := mini(50,int(current.xp/500))
	$Content/Layout/Status.text="%s · %s left\nTier %d/50 · %d/500 XP" % [current.id.replace("paw-season-","Season "),remaining(int(current.end)-now),tier,500 if tier==50 else int(current.xp)%500]
	if not session.can_edit_cafe():
		$Content/Layout/Status.text+=" · View only"
	if not feedback.is_empty():
		$Content/Layout/Status.text+="\n"+feedback
	pass_body.visible=not inbox_tab
	inbox_body.visible=inbox_tab
	$Content/Layout/Tabs/Pass.theme_type_variation=&"Button" if inbox_tab else &"MintButton"
	$Content/Layout/Tabs/Inbox.theme_type_variation=&"MintButton" if inbox_tab else &"Button"
	pass_body.get_child(0).text="Free pass · %d Seasonal XP total\n%d XP per tier · %d XP per café day\nSeparate from Café Reputation." % [int(current.xp), int(CafeProfile.season_catalog.data.xp_per_tier), int(CafeProfile.season_catalog.data.day_xp)]
	daily.text=challenge_text(state,"daily",now)
	weekly.text=challenge_text(state,"weekly",now)
	for reward in CafeProfile.season_catalog.data.milestones:
		var value := int(reward.tier)
		var earned: bool=value in current.earned
		var claimed: bool=value in current.claimed
		var payload := {"coins":int(reward.amount),"item_id":reward.item_id}
		pass_cards[value].description.text="Tier %d · %s%s\n%s" % [value,reward_name(reward.type,payload)," · Exclusive" if reward.exclusive else "","Claimed" if claimed else "Earned" if earned else "Locked · %d XP required" % (value*500)]
		pass_cards[value].claim.text="Claimed" if claimed else "Claim Tier %d" % value
		pass_cards[value].claim.disabled=not session.can_edit_cafe() or not earned or claimed
	var pending := 0
	for entry in state.inbox:
		if not entry.claimed:
			pending+=1
		if not inbox_cards.has(entry.id):
			var card := VBoxContainer.new()
			inbox_body.add_child(card)
			var description := label(card,"")
			var claim_button := button(card,"Claim reward",claim.bind(entry.id))
			inbox_cards[entry.id]={"description":description,"claim":claim_button}
			_metrics=[]
		var claim_state := "Claimed" if entry.claimed else "Pending · never expires"
		if entry.claimed and entry.outcome.duplicate_fallback:
			claim_state+=" · Duplicate → 500 Coins"
		inbox_cards[entry.id].description.text="%s · Tier %d\n%s\n%s" % [entry.season,int(entry.tier),reward_name(entry.type,entry.payload),claim_state]
		inbox_cards[entry.id].claim.text="Claimed" if entry.claimed else "Claim reward"
		inbox_cards[entry.id].claim.disabled=not session.can_edit_cafe() or entry.claimed
	inbox_hint.text="%d pending reward(s) · never expire\nClaimed entries remain as receipts." % pending
	$Content/Layout/Back.text="Back"

func _process(_delta: float) -> void:
	if cafe_screen==null:
		return
	if visible and _last_second!=session.profile.seasonal_now():
		_last_second=session.profile.seasonal_now()
		# Wall-clock periods advance even while Settings covers this screen.
		session.profile.sync_season()
		refresh()
	var bounds: Control=cafe_screen.get_node("Content")
	$Content.position=bounds.position
	$Content.size=bounds.size
	var factor: float=cafe_screen.ui_scale
	var metrics: Array=[factor,bounds.size,inbox_cards.size()]
	if metrics==_metrics:
		return
	_metrics=metrics
	for side in ["left","right","top","bottom"]:
		$Content.add_theme_constant_override("margin_"+side,ceili(12/factor))
	for control in find_children("*","Control",true,false):
		if control is Label or control is Button:
			control.add_theme_font_size_override("font_size",ceili(maxf(28,16/factor)))
		if control is Button:
			control.custom_minimum_size.y=ceili(48/factor)
		if control is VBoxContainer:
			control.add_theme_constant_override("separation",ceili(10/factor))
	$Content/Layout/Heading.add_theme_font_size_override("font_size",ceili(maxf(36,22/factor)))
