extends "res://Tools/analyze_cafe_13b.gd"
## Same Step 13B actor/seeds; old fixture versus verified production Model B.
func run() -> void:
	var output_dir := "/tmp/paw-14-comparison"
	var reference_path := "/workspace/paw-pads-balance-review/step-13b/pacing.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir=arg.trim_prefix("--out=")
		if arg.begins_with("--reference="):
			reference_path=arg.trim_prefix("--reference=")
	if not output_dir.begins_with("/tmp/") or ".." in output_dir:
		push_error("Comparison outputs must stay under /tmp")
		quit(1)
		return
	report_dir=output_dir
	DirAccess.make_dir_recursive_absolute(report_dir)
	var defaults := CafeSession.new()
	var approved: Dictionary=MODELS.B
	ensure(defaults.normal_arrival_interval==Vector2(approved.normal[0],approved.normal[1]) and defaults.rush_arrival_interval==Vector2(approved.rush[0],approved.rush[1]) and defaults.patience_seconds==approved.patience,"Production defaults exactly match approved B fixture")
	ensure(defaults.day_seconds==300 and defaults.rush_start==120 and defaults.rush_end==180,"Production shift structure preserved")
	var baseline := {"normal":[defaults.normal_arrival_interval.x,defaults.normal_arrival_interval.y],"rush":[defaults.rush_arrival_interval.x,defaults.rush_arrival_interval.y],"patience":defaults.patience_seconds}
	defaults.free()
	var original: Array=[]
	if FileAccess.file_exists(reference_path):
		var decoded=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
		if decoded is Array:
			original=decoded
	var reference: Dictionary={}
	for row in original:
		reference["%s:%d:%s:%d" % [row.model,int(row.upgrade),row.skill,int(row.seed)]]=row
	var runs: Array=[]
	var matched := 0
	for model in ["current","B"]:
		selected_model=model
		for upgrade in [0,1,2,3]:
			for efficiency in ["low","average","high"]:
				for seed_value in range(417,457):
					var row := simulate(TEAMS[0],upgrade,efficiency,seed_value)
					runs.append(row)
					var key := "%s:%d:%s:%d" % [model,upgrade,efficiency,seed_value]
					if reference.has(key):
						if JSON.parse_string(JSON.stringify(row))!=reference[key]:
							push_error("Comparison diverged from Step 13B: "+key)
							quit(1)
							return
						matched+=1
			print("Comparison complete ",model," / upgrade ",upgrade)
			await process_frame
	if not original.is_empty() and matched!=runs.size():
		push_error("Comparison reference is incomplete")
		quit(1)
		return
	save_json("comparison.json",{"production":baseline,"runs":runs,"reference_path":reference_path,"reference_available":not original.is_empty(),"reference_matches":matched,"seeds":[417,456],"actor":"Step13B FIFO, same tap/read/notice/error assumptions"})
	print("PASS ",runs.size()," paired before/after shifts; ",matched," exact Step 13B record matches; ",assertions," assertions")
	quit()
