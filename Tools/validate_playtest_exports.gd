extends SceneTree
## Export configuration and native safe-area geometry; no player save is opened.
const LAYOUT := preload("res://Scripts/UI/portrait_layout.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var config := ConfigFile.new()
	check(config.load("res://export_presets.cfg")==OK, "Export presets load")
	for index in [1,2]:
		var section := "preset.%d" % index
		check(config.get_value(section,"export_filter")=="all_resources", "Export all game resources")
		var excluded: String = config.get_value(section,"exclude_filter")
		for path in ["Tools/*","ArtReferences/*","Docs/*","export/*"]:
			check(path in excluded, "Exclude "+path)
		check("Data/Recipes/*.json" in config.get_value(section,"include_filter"), "Include runtime JSON catalogs")
	check(config.get_value("preset.1","platform")=="Windows Desktop", "Windows target")
	check(config.get_value("preset.2","platform")=="Android", "Android target")
	check(config.get_value("preset.2.options","package/unique_name")=="org.shadyandhen.pawpadscafe.playtest", "Distinct playtest app ID")
	for key in ["keystore/release","keystore/release_user","keystore/release_password"]:
		check(config.get_value("preset.2.options",key,"")=="", "No production signing credential: "+key)
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==0, "Android landscape")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc",false), "Mobile texture import enabled")
	var window := Rect2(0,0,720,1280)
	check(LAYOUT.native_safe_insets(window,window)==Vector4.ZERO, "No inset without cutout")
	check(LAYOUT.native_safe_insets(window,Rect2(0,32,720,1200))==Vector4(0,32,0,48), "Top and bottom safe areas")
	check(LAYOUT.native_safe_insets(Rect2(0,32,720,1200),Rect2(0,32,720,1200))==Vector4.ZERO, "No double inset of already fitted window")
	check(LAYOUT.native_safe_insets(window,Rect2())==Vector4.ZERO, "Unavailable safe area falls back")
	check(LAYOUT.native_safe_insets(Rect2(0,0,320,568),Rect2(8,24,304,520))==Vector4(8,24,8,24), "Small portrait edge insets")
	print("%s: %d playtest export assertions" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
