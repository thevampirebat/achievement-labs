"""Read-only audit of public catalogue inputs. Findings are review candidates, not live unlock verification."""
import argparse,collections,hashlib,json,re,zipfile
from pathlib import Path

def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
def requests(recipe):
 first=next(iter(recipe.values()),{})
 return [('Direct',recipe)] if isinstance(first,dict) and 'ReplacementType' in first else list(recipe.items())
def scan(bundle,groups_path):
 z=zipfile.ZipFile(bundle); data=json.loads(z.read('Data.json')); status=json.loads(z.read('PublicStatus.json'))
 labels={str(r['titleId']):r.get('titleName',r.get('name',str(r['titleId']))) for r in status}
 groups=json.loads(Path(groups_path).read_text()); identities={t['titleId']:{a['id']:a['name'] for p in t['packs'] for a in p['achievements']} for t in groups['titles']}
 enabled=set(map(str,data['SupportedTitleIDs'])); findings=[]; counts=collections.Counter(); supported=[]
 def add(kind,tid,aid='',request='',**details):findings.append(dict(kind=kind,titleId=tid,titleName=labels.get(tid,data[tid].get('TitleName',tid)),achievementId=aid,request=request,**details))
 for tid,block in data.items():
  if not tid.isdigit():continue
  counts['numericTitleBlocks']+=1
  if tid not in enabled or block.get('Enabled') is False or tid+'.json' not in z.namelist():continue
  supported.append(tid); template=z.read(tid+'.json').decode('utf-8-sig'); ach=block.get('Achievements',{}); named=identities.get(tid,{})
  counts['titlesWithNameReference']+=bool(named); same_recipe=collections.defaultdict(list)
  for aid,recipe in ach.items():
   counts['recipes']+=1
   if not isinstance(recipe,dict):add('invalid_recipe',tid,aid);continue
   same_recipe[json.dumps(recipe,sort_keys=True)].append(aid)
   if named and aid not in named:add('recipe_id_absent_from_name_reference',tid,aid)
   for rn,req in requests(recipe):
    counts['requests']+=1;body=template
    if not isinstance(req,dict):add('invalid_request',tid,aid,rn);continue
    for op_name,op in req.items():
     if not isinstance(op,dict):add('invalid_operation',tid,aid,rn,operation=op_name);continue
     target=op.get('Target','');typ=op.get('ReplacementType');r=op.get('Replacement','')
     if typ in ['RangeInt','RangeFloat']:r=str(op.get('Min',0))
     elif typ=='StupidFuckingLDAPTimestamp':r='0'
     elif typ not in ['Replace','RawBody']:add('unknown_operation',tid,aid,rn,operation=op_name,operationType=typ)
     if isinstance(r,bool):r=str(r).lower()
     elif isinstance(r,(dict,list)):r=json.dumps(r)
     else:r=str(r)
     if typ!='RawBody' and target and target not in body:
      reason='line_endings_only' if target.replace('\r\n','\n') in body.replace('\r\n','\n') else 'target_not_found'
      add('unmatched_replacement',tid,aid,rn,operation=op_name,reason=reason,targetPreview=target[:120])
     body=r if typ=='RawBody' else body.replace(target,r)
    body=body.replace('REPLACESEQ','1').replace('REPLACETIME','2026-10-13T00:00:00Z').replace('REPLACEXUID','0').replace('REPLACESESSIONGUID','00000000-0000-0000-0000-000000000000')
    if re.search(r'REPLACE[A-Z0-9_]+',body):add('unresolved_placeholder',tid,aid,rn)
    try:p=json.loads(body)
    except Exception as ex:add('invalid_json_with_standard_parser',tid,aid,rn,error=type(ex).__name__);continue
    base=p.get('data',{}).get('baseData',{});payload_tid=str(base.get('titleId',''))
    if payload_tid!=tid:add('payload_title_mismatch',tid,aid,rn,payloadTitleId=payload_tid)
    if block.get('ServiceConfigId') and base.get('serviceConfigId')!=block['ServiceConfigId']:add('payload_scid_mismatch',tid,aid,rn)
    props=base.get('properties',{});criterion=props.get('AchievementName')
    if criterion and named:
     hits=[i for i,n in named.items() if norm(n)==norm(str(criterion))]
     if hits and aid not in hits:add('criterion_matches_another_display_name',tid,aid,rn,criterion=criterion,matches=[dict(id=i,name=named[i]) for i in hits],selectedName=named.get(aid))
  for raw,ids in same_recipe.items():
   if len(ids)>1:add('identical_recipes_within_title',tid,achievementIds=ids,achievementNames=[named.get(i) for i in ids])
  if block.get('SourceTitleId'):add('edition_copy_requires_game_specific_review',tid,sourceTitleId=str(block['SourceTitleId']),catalogueResearchStatus=block.get('ResearchStatus',''))
 counts['locallyEnabledTitles']=len(supported);counts['advertisedTitles']=len(status);counts['findingRows']=len(findings)
 return dict(scope='Raw bundled public catalogue before runtime Dishonored and legacy edition corrections. Structural/name-reference audit only; no live requests. Standard Python JSON may reject syntax normalized by the app; those rows need comparison with Windows regression results.',bundleSha256=hashlib.sha256(Path(bundle).read_bytes()).hexdigest(),counts=dict(counts),findings=findings)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('bundle');a.add_argument('groups');a.add_argument('output');v=a.parse_args();r=scan(v.bundle,v.groups);Path(v.output).write_text(json.dumps(r,indent=2));print(json.dumps(r['counts']));print(collections.Counter(f['kind'] for f in r['findings']));
 for kind in ['criterion_matches_another_display_name','identical_recipes_within_title','payload_title_mismatch','payload_scid_mismatch','unmatched_replacement']:
  rows=[f for f in r['findings'] if f['kind']==kind];titles=collections.Counter(f['titleId'] for f in rows);print(kind,dict(titles))
