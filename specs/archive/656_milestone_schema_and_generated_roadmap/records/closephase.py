#!/usr/bin/env python3
"""closephase.py P 'Phase name' files.txt [notes]  -- write progress file, tick checklist items, write handoff.
Skips checklist items whose 1-based ordinal is listed in env SKIP (comma list)."""
import sys,json,re,os,datetime
P=int(sys.argv[1]); name=sys.argv[2]; files=[l.strip() for l in open(sys.argv[3]) if l.strip()]
note=sys.argv[4] if len(sys.argv)>4 else ''
nextact=sys.argv[5] if len(sys.argv)>5 else ''
T='/home/benjamin/.config/nvim/specs/656_milestone_schema_and_generated_roadmap'
plan=T+'/plans/01_milestone-schema-generated-roadmap.md'
now=datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
L=open(plan).read().split('\n')
start=next(i for i,l in enumerate(L) if l.startswith(f'### Phase {P}:'))
end=next((i for i in range(start+1,len(L)) if L[i].startswith('### Phase ')),len(L))
skip=set(int(x) for x in os.environ.get('SKIP','').split(',') if x)
objs=[];n=0;i=start
while i<end:
    if L[i].startswith('- [ ] ') or L[i].startswith('- [x] '):
        n+=1; j=i
        while j+1<end and L[j+1].startswith('  ') and L[j+1].strip(): j+=1
        text=' '.join(x.strip() for x in L[i:j+1])[6:]
        done = n not in skip
        if done and L[i].startswith('- [ ] '):
            L[i]='- [x] '+L[i][6:]
            if '*(completed' not in L[j] and '*(deviation' not in L[j]: L[j]=L[j]+' *(completed)*'
        objs.append({"id":n,"description":text[:160],"status":"done" if done else "not_started","files_touched":files if n==1 else []})
        i=j
    i+=1
open(plan,'w').write('\n'.join(L))
os.makedirs(T+'/progress',exist_ok=True); os.makedirs(T+'/handoffs',exist_ok=True)
pf=T+f'/progress/phase-{P}-progress.json'
dev=json.load(open(pf)).get('deviations',[]) if os.path.exists(pf) else []
json.dump({"phase":P,"phase_name":name,"started_at":now,"last_updated":now,"objectives":objs,"current_objective":None,"approaches_tried":[],"deviations":dev,"handoff_count":0,"verification_notes":note},open(pf,'w'),indent=2)
hf=T+f'/handoffs/phase-{P}-handoff-'+datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')+'.md'
open(hf,'w').write(f"""# Phase {P} Handoff: {name}

## Immediate Next Action
{nextact or f'Begin Phase {P+1} of the plan.'}

## Current State
Phase {P} completed. Plan and progress file are current.

## Key Decisions Made
{note or '- None'}

## Deviations from Plan
{chr(10).join('- '+d['description']+': '+d['reason'] for d in dev) or '- None'}

## What NOT to Try
- None

## References
- Plan: specs/656_milestone_schema_and_generated_roadmap/plans/01_milestone-schema-generated-roadmap.md (Phase {P})
""")
print(pf,hf,len(objs))
