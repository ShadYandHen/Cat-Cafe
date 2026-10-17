"""Audit-only postprocessing; stdlib, /tmp outputs, never imports/writes game state."""
import argparse, collections, csv, datetime as dt, json, math, pathlib, random, statistics as st

def percentile(values, p):
    x=sorted(values); position=(len(x)-1)*p; lo=int(position); hi=math.ceil(position)
    return x[lo]*(hi-position)+x[hi]*(position-lo) if hi!=lo else x[lo]

def summarize(rows):
    result={'n':len(rows)}
    for key in ['arrived','offered','skipped','served','lost','coins','xp','wait_mean','patience_mean','prep_mean','idle','duration','rush_busy_fraction','rush_arrivals','rush_served','occupancy_mean','activations']:
        values=[r[key] for r in rows]
        result[key]={'mean':st.mean(values),'p10':percentile(values,.1),'p50':percentile(values,.5),'p90':percentile(values,.9),'min':min(values),'max':max(values)}
    quality=[sum(r['quality_counts'][i] for r in rows) for i in range(4)]
    result['quality_percent']=[100*n/max(1,sum(quality)) for n in quality]
    result['max_guests']=max(r['max_guests'] for r in rows)
    result['max_accepted_orders']=max(r['max_accepted_orders'] for r in rows)
    return result

def main():
    args=argparse.ArgumentParser(); args.add_argument('--input',default='/tmp/paw-balance-step12'); options=args.parse_args()
    root=pathlib.Path(options.input).resolve()
    if not root.is_relative_to('/tmp'): raise SystemExit('Use isolated /tmp analysis directory')
    source=json.loads((root/'simulations.json').read_text()); quality=json.loads((root/'quality.json').read_text())
    rates=json.loads((pathlib.Path(__file__).resolve().parents[1]/'Data/Seasons/pass.json').read_text())
    baseline=source['baseline']; groups=collections.defaultdict(dict)
    for row in source['runs']:
        team=(row['team'][0],*sorted(row['team'][1:])); key=(team,row['upgrade'],row['skill'])
        groups[key][row['seed']]=row  # remove overlapping reference/scanning trials, not distinct outcomes
    aggregate={key:summarize(list(rows.values())) for key,rows in groups.items()}
    with (root/'pacing.csv').open('w',newline='') as f:
        writer=csv.writer(f); writer.writerow(['active','supports','upgrade','skill','n','served_mean','served_p10','served_p90','lost_mean','coins_mean','xp_mean','idle_seconds','rush_busy_percent','activation_mean','perfect_percent'])
        for (team,up,skill),g in sorted(aggregate.items()):
            writer.writerow([team[0],'+'.join(team[1:]),up,skill,g['n'],g['served']['mean'],g['served']['p10'],g['served']['p90'],g['lost']['mean'],g['coins']['mean'],g['xp']['mean'],g['idle']['mean'],g['rush_busy_fraction']['mean']*100,g['activations']['mean'],g['quality_percent'][3]])
    refs=[]
    for team in baseline['reference_teams']:
        team=tuple([team[0],*sorted(team[1:])])
        for up in [0,2,3]:
            for skill in baseline['skills']:
                refs.append({'team':team,'upgrade':up,'skill':skill,**aggregate[team,up,skill]})
    ranks={}
    for up in [0,3]:
        for skill in ['average','low']:
            rows=[{'team':team,**summarize([r for seed,r in records.items() if 417<=seed<=426])} for (team,u,s),records in groups.items() if u==up and s==skill]
            ranks[f'{up}_{skill}']=sorted(rows,key=lambda r:(-r['coins']['mean'],-r['xp']['mean']))
    default=tuple(['mochi',*sorted(['fade','max'])]); progression=[]
    for up in [0,2,3]:
        for skill in ['ideal','high','average','low']:
            g=aggregate[default,up,skill]; rate=g['xp']['mean']
            progression.append({'upgrade':up,'skill':skill,'xp_day':rate,'coins_day':g['coins']['mean'],'levels':{str(r['level']):math.ceil(r['total_xp']/rate) for r in quality['reputation'] if r['level'] in [5,10,20,30,40,50]},'cycle_days':1000/rate})
    # Explicit arithmetic planning profiles (eight full weekly rewards).
    profiles=[('Casual',24,16,4),('Regular',56,56,8),('Engaged',112,56,8),('Dedicated',224,56,8)]
    seasonal=[]
    alternatives=[('Current',rates['day_xp'],rates['daily_xp'],rates['weekly_xp'],rates['xp_per_tier']),('Higher day XP',375,50,200,500),('Lower tier XP',50,50,200,140),('Weekly-heavy',50,50,2500,500),('Hybrid',250,100,300,300)]
    for name,days,dailies,weeklies in profiles:
        for variant,dayxp,dailyxp,weeklyxp,tierxp in alternatives:
            earned=days*dayxp+dailies*dailyxp+weeklies*weeklyxp
            tier=min(50,earned//tierxp)
            seasonal.append({'profile':name,'model':variant,'days':days,'daily':dailies,'weekly':weeklies,'xp':earned,'tier':tier,'milestones':[t for t in range(5,51,5) if t<=tier]})
    # Actual first-season schedule, including clipped partial weeks. No simulated real-player claims.
    calendar_runs=[]
    profile_conditions=[('Casual',3,0,'average'),('Regular',7,0,'average'),('Engaged',14,2,'average'),('Dedicated',28,3,'high')]
    for name,weekly_shifts,upgrade,skill in profile_conditions:
        trials=[]
        cached=list(groups[default,upgrade,skill].values())
        for seed in range(20):
            prng=random.Random(417+seed); weekly_metrics=collections.defaultdict(collections.Counter); week_defs={}; xp=0; daily_wins=0; total_shifts=0
            for period in quality['calendar']:
                weekday=dt.datetime.fromisoformat(period['utc']).weekday()
                count=(1 if weekday in [0,2,5] else 0) if weekly_shifts==3 else weekly_shifts//7
                if not count: continue
                daily_metrics=collections.Counter()
                for _ in range(count):
                    row=prng.choice(cached); tiers=row['quality_counts']
                    daily_metrics.update(served=row['served'],good=sum(tiers[1:]),excellent=sum(tiers[2:]),coins=row['coins'],days=1)
                    xp+=rates['day_xp']; total_shifts+=1
                definition=period['daily_definition']
                if daily_metrics[definition['metric']]>=definition['target']: xp+=rates['daily_xp']; daily_wins+=1
                week_id=period['weekly']['period']; weekly_metrics[week_id].update(daily_metrics); week_defs[week_id]=period['weekly_definition']
            weekly_wins=sum(metrics[week_defs[k]['metric']]>=week_defs[k]['target'] for k,metrics in weekly_metrics.items())
            xp+=rates['weekly_xp']*weekly_wins
            trials.append({'xp':xp,'tier':min(50,xp//500),'daily':daily_wins,'weekly':weekly_wins,'shifts':total_shifts})
        calendar_runs.append({'profile':name,'skill':skill,'upgrade':upgrade,'trials':trials,'xp_mean':st.mean(t['xp'] for t in trials),'xp_p10':percentile([t['xp'] for t in trials],.1),'xp_p90':percentile([t['xp'] for t in trials],.9),'tier_min':min(t['tier'] for t in trials),'tier_max':max(t['tier'] for t in trials),'daily_mean':st.mean(t['daily'] for t in trials),'weekly_mean':st.mean(t['weekly'] for t in trials)})
    # Coin affordability: each purchase chain alone, starting with actual default Coins.
    affordability=[]; rate=aggregate[default,0,'average']['coins']['mean']; xp_rate=aggregate[default,0,'average']['xp']['mean']
    thresholds={r['level']:r['total_xp'] for r in quality['reputation']}
    for item in baseline['upgrades']:
        cumulative=0
        for i,cost in enumerate(item['costs']):
            cumulative+=cost; minimum=item['minimum_reputation'][i]
            affordability.append({'id':item['id'],'level':i+1,'cost':cost,'cumulative':cumulative,'unlock':minimum,'coin_only_days':max(0,math.ceil((cumulative-quality['profile_defaults']['coins'])/rate)),'earliest_including_unlock':max(0,math.ceil((cumulative-120)/rate),math.ceil(thresholds[minimum]/xp_rate))})
    summary={'raw_runs':len(source['runs']),'unique_runs':sum(len(v) for v in groups.values()),'reference':refs,'rankings':ranks,'progression':progression,'season_arithmetic':seasonal,'calendar_simulations':calendar_runs,'weekly_periods':len({d['weekly']['period'] for d in quality['calendar']}),'affordability':affordability}
    (root/'summary.json').write_text(json.dumps(summary,indent=2))
    for filename, rows in [('season_models.csv', seasonal), ('quality.csv', quality['samples']), ('upgrade_affordability.csv', affordability)]:
        with (root/filename).open('w', newline='') as f:
            writer=csv.DictWriter(f,fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    for row in calendar_runs: print('Calendar:',{k:v for k,v in row.items() if k!='trials'})
    for k,rows in ranks.items(): print('Top team',k,rows[0]['team'],'coins',rows[0]['coins']['mean'],'XP',rows[0]['xp']['mean'])
    print('Wrote isolated summary.json and pacing.csv:',root)

if __name__=='__main__': main()
