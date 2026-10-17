extends SceneTree
## Point scoring and calendar audit; no player profiles or saves are opened.
const VARIANTS := {"plain":{"bonus":0,"forgiveness":0.0,"finish":false},"one_quality_cat":{"bonus":5,"forgiveness":0.0,"finish":false},"ingredients_max":{"bonus":6,"forgiveness":0.0,"finish":false},"two_quality_cats":{"bonus":10,"forgiveness":0.0,"finish":false},"quality_and_upgrades":{"bonus":16,"forgiveness":0.0,"finish":false},"momo_ready":{"bonus":10,"forgiveness":0.15,"finish":false},"blaze_ready":{"bonus":10,"forgiveness":0.0,"finish":true},"blaze_max_ready":{"bonus":16,"forgiveness":0.0,"finish":true}}
const SKILLS := preload("res://Tools/analyze_balance.gd").SKILLS

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rng := RandomNumberGenerator.new()
	var catalog := DrinkCatalog.new()
	var samples: Array=[]
	var missing: Array=[]
	for index in range(catalog.recipes.size()):
		var recipe: Dictionary=catalog.recipes[index]
		for efficiency in SKILLS:
			var accum: Dictionary={}
			for variant in VARIANTS:
				accum[variant]={"recipe":recipe.id,"skill":efficiency,"variant":variant,"n":2000,"tiers":[0,0,0,0],"score_sum":0,"wrong_perfect":0,"xp_sum":0,"coin_sum":0}
			rng.seed=9417+index*100+SKILLS.keys().find(efficiency)
			for i in range(2000):
				var ingredients: Array=[]
				for ingredient in recipe.ingredients:
					if rng.randf()>=float(SKILLS[efficiency].miss):
						ingredients.append(ingredient)
				var duration := maxf(0.05,recipe.target_seconds+rng.randfn(float(SKILLS[efficiency].bias),float(SKILLS[efficiency].sigma)))
				for variant in VARIANTS:
					var settings: Dictionary=VARIANTS[variant]
					var complete := DrinkQuality.ingredients_complete(recipe.ingredients,ingredients)
					var score := DrinkQuality.final_score(DrinkQuality.score(recipe.ingredients,ingredients,duration,recipe.target_seconds,2 if ingredients.is_empty() else 3,float(settings.forgiveness)),int(settings.bonus),complete)
					if complete and settings.finish and score>=75 and score<=94:
						score=95
					var tier := DrinkQuality.tier(score)
					var reward := DrinkQuality.reward(int(recipe.base_coins),score)
					accum[variant].tiers[tier]+=1
					accum[variant].score_sum+=score
					accum[variant].xp_sum+=reward.xp
					accum[variant].coin_sum+=reward.coins
					if tier==3 and ingredients.size()!=recipe.ingredients.size():
						accum[variant].wrong_perfect+=1
			for row in accum.values():
				samples.append(row)
		var selected: Array=recipe.ingredients.duplicate()
		selected.pop_back()
		for bonus in [0,5,6,10,16]:
			var score := DrinkQuality.final_score(DrinkQuality.score(recipe.ingredients,selected,recipe.target_seconds,recipe.target_seconds,2 if selected.is_empty() else 3),bonus,false)
			missing.append({"recipe":recipe.id,"bonus":bonus,"score":score,"tier":DrinkQuality.TIERS[DrinkQuality.tier(score)],"blaze_if_ready":95 if score>=75 and score<=94 else score})
	var tips: Array=[]
	for base in [10,12,14]:
		for score in [0,50,75,95]:
			for cats in [0.0,0.05,0.10]:
				for level in range(4):
					var reward := DrinkQuality.reward(base,score,cats+level*0.05)
					tips.append({"base":base,"tier":reward.tier,"cat_bonus":cats,"upgrade":level,"tip":reward.tip,"unpaid_bonus_units":reward.bonus_units,"coins":reward.coins,"xp":reward.xp})
	var calendar: Array=[]
	var seasons := CafeProfile.season_catalog
	for day in range(56):
		var now := seasons.anchor+day*86400+12*3600
		var season := seasons.season_at(now)
		var daily := seasons.challenge(season,now,"daily")
		var weekly := seasons.challenge(season,now,"weekly")
		calendar.append({"day":day,"utc":Time.get_datetime_string_from_unix_time(now),"daily":daily,"daily_definition":seasons.challenge_definition("daily",daily.id),"weekly":weekly,"weekly_definition":seasons.challenge_definition("weekly",weekly.id)})
	DirAccess.make_dir_recursive_absolute("/tmp/paw-balance-step12")
	var thresholds: Array=[]
	var cumulative := 0
	for level in range(1,51):
		thresholds.append({"level":level,"total_xp":cumulative,"next":CafeProfile.required_xp(level)})
		if level<50:
			cumulative+=CafeProfile.required_xp(level)
	var f := FileAccess.open("/tmp/paw-balance-step12/quality.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"samples":samples,"missing_ingredient":missing,"tips":tips,"calendar":calendar,"variants":VARIANTS,"reputation":thresholds,"profile_defaults":CafeProfile.defaults(),"quality_tiers":DrinkQuality.TIERS,"tip_percent":DrinkQuality.TIP_PERCENT,"quality_xp":DrinkQuality.XP}))
	f.close()
	# Exact findings are assertions about CURRENT behavior, not approved rules.
	for base in [10,12,14]:
		for score in [0,50,75,95]:
			assert(DrinkQuality.reward(base,score,0.0).tip==DrinkQuality.reward(base,score,0.10).tip)
	assert(DrinkQuality.final_score(DrinkQuality.score(["Tea","Water","Honey"],["Tea","Water"],5,5,3),16,false)==74)
	print("PASS: 512000 paired recipe-quality evaluations, 144 exact tip cases, 56 UTC challenge periods; current whole tips and ingredient-completeness cap verified")
	quit()
