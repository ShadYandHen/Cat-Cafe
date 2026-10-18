"""Deterministic audit postprocessing; stdlib only, outputs restricted to /tmp."""
import argparse, collections, csv, json, math, pathlib, statistics

METRICS = ['offered','arrived','skipped','served','lost','loss_percent','coins','xp','idle_percent','duration','wait_mean','patience_mean','prep_seconds','overlap_percent','rush_overlap_percent','rush_busy_fraction','rush_served','fractional_coins','premium_coins','ordinary_coins','activations','prepared','incomplete']

def percentile(values, p):
    values=sorted(values); position=(len(values)-1)*p; lo=math.floor(position); hi=math.ceil(position)
    return values[lo]+(values[hi]-values[lo])*(position-lo)

def stats(values):
    return {'mean':statistics.mean(values),'p10':percentile(values,.1),'p50':percentile(values,.5),'p90':percentile(values,.9),'min':min(values),'max':max(values)}

def summarize(rows):
    result={'n':len(rows)}
    for k in METRICS:
        result[k]=stats([r[k] for r in rows])
    q=[sum(r['quality_counts'][i] for r in rows) for i in range(4)]
    result['tier_percent']=[100*v/max(1,sum(q)) for v in q]
    result['pooled_loss_percent']=100*sum(r['lost'] for r in rows)/max(1,sum(r['arrived'] for r in rows))
    result['wait_samples']=stats([v for r in rows for v in r['wait_samples']])
    result['patience_samples']=stats([v for r in rows for v in r['patience_samples']])
    result['zero_loss_percent']=100*sum(r['lost']==0 for r in rows)/len(rows)
    return result

def save_csv(path, rows):
    with path.open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--input',default='/tmp/paw-13b');args=parser.parse_args()
    root=pathlib.Path(args.input).resolve()
    if not root.is_relative_to('/tmp'):raise SystemExit('Use isolated /tmp outputs')
    pacing=json.loads((root/'pacing.json').read_text());teams=json.loads((root/'teams.json').read_text())
    economy=json.loads((root/'economy.json').read_text());candidates=json.loads((root/'ability_candidates.json').read_text())
    assert len(pacing)==1920 and len(teams)==12960 and len(candidates)==480
    pg=collections.defaultdict(list);tg=collections.defaultdict(list);eg=collections.defaultdict(list)
    for r in pacing:pg[r['model'],r['upgrade'],r['skill']].append(r)
    for r in teams:tg[r['model'],r['upgrade'],r['skill'],tuple(r['team'])].append(r)
    for r in economy:eg[r['skill']].append(r)
    psummary=[];flat=[]
    for (model,upgrade,skill),rows in pg.items():
        assert len(rows)==40
        s=summarize(rows);psummary.append({'model':model,'upgrade':upgrade,'skill':skill,'stats':s})
        flat.append(dict(model=model,upgrade=upgrade,skill=skill,**{k:s[k]['mean'] for k in METRICS},pooled_loss_percent=s['pooled_loss_percent'],loss_p90=s['loss_percent']['p90'],lost_max=s['lost']['max'],served_p10=s['served']['p10'],served_p90=s['served']['p90'],worst_patience=s['patience_samples']['min']))
    save_csv(root/'pacing-summary.csv',flat)
    tsummary=[];tflat=[]
    for (model,upgrade,skill,team),rows in tg.items():
        assert len(rows)==12
        s=summarize(rows);tsummary.append({'model':model,'upgrade':upgrade,'skill':skill,'team':team,'stats':s})
        tflat.append(dict(model=model,upgrade=upgrade,skill=skill,active=team[0],supports='+'.join(team[1:]),**{k:s[k]['mean'] for k in ['served','lost','coins','xp','idle_percent','activations','fractional_coins','premium_coins']},perfect=s['tier_percent'][3]))
    save_csv(root/'teams-summary.csv',tflat)
    # Paired support-inclusion effects holding active and the other support fixed.
    support_effects=[];lookup={(r['model'],r['upgrade'],r['skill'],tuple(r['team'])):r for r in tsummary}
    ids=['mochi','fade','momo','odin','max','blaze']
    for model in ['current','B']:
        for upgrade in [0,2,3]:
            for skill in ['low','average','high']:
                for cat in ids:
                    differences=[]
                    for active in ids:
                        if active==cat:continue
                        for partner in ids:
                            if partner in [cat,active]:continue
                            chosen=tuple([active]+sorted([cat,partner],key=ids.index))
                            target=lookup[model,upgrade,skill,chosen]['stats']
                            alternatives=[]
                            for other in ids:
                                if other in [cat,active,partner]:continue
                                team=tuple([active]+sorted([partner,other],key=ids.index))
                                alternatives.append(lookup[model,upgrade,skill,team]['stats'])
                            differences.append({k:target[k]['mean']-statistics.mean(a[k]['mean'] for a in alternatives) for k in ['served','lost','coins','xp']})
                    support_effects.append(dict(model=model,upgrade=upgrade,skill=skill,cat=cat,**{k:statistics.mean(d[k] for d in differences) for k in ['served','lost','coins','xp']}))
    save_csv(root/'support-effects.csv',support_effects)
    # Active comparisons keep the identical set of 3 equipped passives.
    role=[]
    for model in ['current','B']:
        for upgrade in [0,2,3]:
            for skill in ['low','average','high']:
                for cat in ids:
                    diffs=[]
                    for r in tsummary:
                        if (r['model'],r['upgrade'],r['skill'],r['team'][0])!=(model,upgrade,skill,cat):continue
                        equivalents=[x for x in tsummary if (x['model'],x['upgrade'],x['skill'])==(model,upgrade,skill) and set(x['team'])==set(r['team']) and x['team'][0]!=cat]
                        diffs.append({k:r['stats'][k]['mean']-statistics.mean(x['stats'][k]['mean'] for x in equivalents) for k in ['served','lost','coins','xp']})
                    role.append(dict(model=model,upgrade=upgrade,skill=skill,cat=cat,**{k:statistics.mean(d[k] for d in diffs) for k in ['served','lost','coins','xp']}))
    save_csv(root/'active-effects.csv',role)
    esummary=[];eco_flat=[]
    for skill,rows in eg.items():
        assert len(rows)==10 and not any(r['censored'] for r in rows)
        s={k:stats([r[k] for r in rows]) for k in ['maxed_day','decorated_day','level50_day','earned','remaining','fractional']}
        checkpoints={}
        for shift in [10,25,50,100]:
            selected=[c for r in rows for c in r['checkpoints'] if c['shift']==shift]
            checkpoints[str(shift)]={k:stats([r[k] for r in selected]) for k in ['coins','level','earned','fractional']}
        esummary.append({'skill':skill,'stats':s,'checkpoints':checkpoints})
        for r in rows:eco_flat.append({k:r[k] for k in ['skill','seed','maxed_day','decorated_day','level50_day','earned','remaining','fractional']})
    save_csv(root/'economy-summary.csv',eco_flat)
    sensitivity=collections.defaultdict(list)
    for pair in candidates:
        c=pair['candidate'];b=pair['control']
        sensitivity[c['candidate'],c['upgrade'],c['skill']].append({k:c[k]-b[k] for k in ['served','lost','coins','xp','activations','prep_seconds']})
    sensitivity_flat=[]
    for (candidate,upgrade,skill),rows in sensitivity.items():
        sensitivity_flat.append(dict(candidate=candidate,upgrade=upgrade,skill=skill,n=len(rows),**{k:statistics.mean(r[k] for r in rows) for k in rows[0]}))
    save_csv(root/'ability-sensitivity.csv',sensitivity_flat)
    b_summary=[]
    b_path=root/'economy-B.json'
    if b_path.exists():
        b_rows=json.loads(b_path.read_text())
        assert len(b_rows)==30 and not any(r['censored'] for r in b_rows)
        for skill in ['low','average','high']:
            selected=[r for r in b_rows if r['skill']==skill]
            b_summary.append({'skill':skill,'stats':{k:stats([r[k] for r in selected]) for k in ['maxed_day','decorated_day','level50_day','earned','remaining','fractional']}})
        save_csv(root/'economy-B-summary.csv',[{k:r[k] for k in ['skill','seed','maxed_day','decorated_day','level50_day','earned','remaining','fractional']} for r in b_rows])
    summary={'economy_B':b_summary,'pacing':psummary,'teams':tsummary,'economy':esummary,'support_effects':support_effects,'active_effects':role,'candidates':sensitivity_flat}
    (root/'summary.json').write_text(json.dumps(summary,indent=2))
    print('PASS aggregation: 1920 pacing, 12960 team, 960 sensitivity shifts; 30 current and %d candidate-B purchase trajectories; CSV/JSON in' % (30 if b_summary else 0),root)

if __name__=='__main__':main()
