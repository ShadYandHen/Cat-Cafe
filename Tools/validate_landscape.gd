extends "res://Tools/validate_order_tickets.gd"
## Native landscape regression and safe-area injection; isolated profiles only.
const SIZES:=[Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2340,1080)]
func regions(panel: Control, names: Array) -> void:
	var bounds:=Rect2(main.get_node("Content").position,main.get_node("Content").size)
	var items: Array[Control]=[]
	for name in names:
		var node: Control=panel.get_node(name)
		if not node.is_visible_in_tree():continue
		check(bounds.encloses(node.get_global_rect()),"Safe canvas contains "+str(node.get_path()))
		items.append(node)
		if node is Button:check(node.size.x*main.ui_scale>=44 and node.size.y*main.ui_scale>=44,"Landscape touch target "+name)
	for i in range(items.size()):
		for j in range(i):check(not items[i].get_global_rect().intersects(items[j].get_global_rect()),"Independent landscape regions "+items[i].name+"/"+items[j].name)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			captures=arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(captures)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for dimensions in SIZES:
		root.size=dimensions
		touch=dimensions.x>=2340
		var title=load("res://Scenes/Title.tscn").instantiate()
		root.add_child(title)
		await settle()
		for n in ["Name","Tagline","MochiPlaceholder","MochiName","Play","Settings"]:check(Rect2(Vector2.ZERO,title.size).encloses(title.get_node("Content/Layout/"+n).get_global_rect()),"Landscape title "+n)
		await shot("title")
		title.queue_free()
		await process_frame
		await make_cafe()
		session.cat_effects_enabled=true
		main.simulated_safe_insets=Vector4(60,18,36,12)
		main._update_layout()
		await settle()
		check(main.content.position.x*main.ui_scale>=59.9 and main.content.position.y*main.ui_scale>=17.9,"Left and top cutouts respected")
		check((main.size.x-main.content.position.x-main.content.size.x)*main.ui_scale>=35.9,"Right cutout respected")
		session._arrive()
		session.changed.emit()
		await settle()
		check(ticket(0).visible and ticket(1).visible,"Both landscape customer tickets")
		var cafe=main.get_node("Content/Layout/Cafe")
		check(cafe.size.x>cafe.size.y*1.7,"Café uses landscape room")
		regions(view,["Customer","CustomerRight","CoffeeEquipment","MilkEquipment","TeaEquipment","ColdEquipment"])
		await shot("cafe-two-customers-safe")
		await click(ticket(0))
		check(session.view==CafeSession.View.STATION and session.selected_order_id==1,"Landscape ticket opens matching station")
		regions(view.get_node("CoffeeStation/Content/Layout"),["Workspace","Stations","Description","DrinkWorkspace","Patience","Action","Back","Settings"])
		check(view.get_node("CoffeeStation/Content/Layout/Workspace").global_position.x<view.get_node("CoffeeStation/Content/Layout/DrinkWorkspace").global_position.x,"Ingredients left of cup")
		await shot("preparation-safe")
		for ingredient in session.get_order(1).recipe.ingredients:session.toggle_ingredient(ingredient)
		session.start_brewing()
		session.advance_time(session.preparation_target())
		session.stop_preparation()
		session.finish_coffee()
		await settle()
		check(ticket(0).get_node("Cue").text.contains("Serve"),"Ready ticket is manual Serve")
		await shot("ready-serve")
		var coins:=session.coins
		await click(ticket(0))
		check(session.coins>coins and session.served==1,"Ticket service rewards once")
		for entry in [["team","CatTeamScreen"],["shop","CafeShopScreen"],["rewards","RewardsScreen"],["season","SeasonScreen"]]:
			match entry[0]:
				"team":session.open_team()
				"shop":session.open_shop(false)
				"rewards":session.open_rewards()
				"season":session.open_season()
			await settle()
			var panel=view.get_node(entry[1]+"/Content/Layout")
			regions(panel,["Heading","Status","Settings","Back","Scroll"])
			if panel.has_node("Tabs"):regions(panel,["Tabs","Scroll","Settings","Back"])
			await shot(entry[0]+"-safe")
			await click(panel.get_node("Settings"))
			await settle()
			check(main.get_node("SettingsPanel").visible,"Settings from landscape "+entry[0])
			check(Rect2(main.content.position,main.content.size).encloses(main.get_node("SettingsPanel/Center/Panel").get_global_rect()),"Settings respects cutouts")
			main.get_node("SettingsPanel").close()
			await click(panel.get_node("Back"))
			session.back_to_cafe()
			await settle()
		session.advance_time(400)
		await settle()
		check(session.phase==CafeSession.Phase.RESULTS,"Landscape day completes")
		regions(view.get_node("DayResults/Content/Layout"),["Heading","Patience","Description","Action","Settings","Back","CatTeam","Shop"])
		await shot("results-safe")
		await close_cafe()
		print("PASS landscape ",dimensions," with asymmetric safe insets")
	print("%s: %d landscape assertions" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
