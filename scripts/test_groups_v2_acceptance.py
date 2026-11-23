"""Groups V2 predicate regression; temporary JSON only, no existing profile."""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

m=runpy.run_path(str(Path(__file__).with_name('groups-v2-acceptance.py')))
class GroupsV2Predicates(unittest.TestCase):
    def baseline(self):
        access={'group':{'id':201,'group_nama':'CS','group_jenis':'user','status':1,'revision':1,'active_members':2},'catalog_fingerprint':'a'*64,'entries':[{'sidebar':{'id':i},'editable':i==4,'read':int(i!=4),'create':0,'update':0,'delete':0}for i in (4,20,21)]}
        return {'sqlite':{'schema':27,'integrity':'ok','fk':0,'fingerprints':{'payments':'protected','cursors':'protected'}},'postgres':{'groups':[{'id':201,'group_nama':'CS','group_jenis':'user','status':1,'revision':1}],'users':[{'id':1,'group_id':201,'security_version':1}],'fingerprints':{'grants':'protected','sidebar':'protected','user_identity':'protected','protected_groups':'protected'},'grant_counts':[{'group_id':201,'count':3}],'access':access,'audits':[],'integrity':'PASS','recovery':'PASS'}}
    def runcheck(self,base,state,phase='initial',sqlite=None):
        with tempfile.TemporaryDirectory(prefix='groups-v2-predicate-')as folder:
            root=Path(folder).resolve(strict=True);(root/'groups-v2-baseline.json').write_text(json.dumps(base))
            revision=state['access']['group']['revision']
            probe={key:200 if revision==2 or (revision==4 and key=='read') else 403 for key in ('read','create','update','delete')}
            def helper(_,action):
                if action=='validate':return json.dumps({'Catalog':'full-v2.1'})
                return '{}' if action=='http-check' else json.dumps(probe)
            with patch.dict(m['check'].__globals__,{'postgres':lambda _:state,'snapshot':lambda _:sqlite or base['sqlite'],'occupied':lambda _:True,'helper':helper}):
                m['check'](root,phase)
    def test_initial_and_protected_state(self):
        base=self.baseline()
        # Initial effective flags are zero, so the read-only backend must deny.
        with tempfile.TemporaryDirectory(prefix='groups-v2-predicate-')as folder:
            root=Path(folder).resolve(strict=True);(root/'groups-v2-baseline.json').write_text(json.dumps(base))
            with patch.dict(m['check'].__globals__,{'postgres':lambda _:base['postgres'],'snapshot':lambda _:base['sqlite'],'occupied':lambda _:False}):
                m['check'](root,'initial');(root/'launch.lock').write_text('busy')
                with self.assertRaises(RuntimeError):m['check'](root,'initial')
    def test_final_requires_exact_revision_flags_membership_and_audit(self):
        base=self.baseline();state=copy.deepcopy(base['postgres']);state['groups'][0]['revision']=4;state['access']['group']['revision']=4;state['access']['entries'][0]['read']=1
        for i in range(3):
            before=copy.deepcopy(base['postgres']['access']);after=copy.deepcopy(before);before['group']['revision']=i+1;after['group']['revision']=i+2
            state['audits'].append({'actor_id':101,'target_id':201,'target_type':'group','action':'group_grants','result':'success','request_id':f'00000000-0000-4000-8000-{i:012d}','before_state':before,'after_state':after})
        state['audits'].append({'actor_id':101,'target_id':201,'target_type':'group','action':'group_grants','result':'denied','reason_code':'stale_revision','request_id':'00000000-0000-4000-8000-999999999999'})
        self.runcheck(base,state,'final')
        for field in ('grants','sidebar','user_identity','protected_groups'):
            bad=copy.deepcopy(state);bad['fingerprints'][field]='changed'
            with self.assertRaises(RuntimeError):self.runcheck(base,bad,'final')
        for row,key,value in [(state['access']['entries'][1],'read',0),(state['users'][0],'group_id',999),(state['groups'][0],'revision',5),(state['audits'][0],'actor_id',201),(state['grant_counts'][0],'count',4)]:
            old=row[key];row[key]=value
            with self.assertRaises(RuntimeError):self.runcheck(base,state,'final')
            row[key]=old
        with self.assertRaises(RuntimeError):self.runcheck(base,state,'final',{'schema':27,'fingerprints':{'payments':'changed'}})

    def test_full_catalog_save_and_excluded_actions_are_exact(self):
        base=self.baseline();base['catalog']='full-v2.1'
        base['postgres']['access']['entries']=[{'sidebar':{'id':i},'editable':i not in (20,21),'read':int(i in (20,21)),'create':0,'update':0,'delete':0}for i in (1,2,3,4,10,11,20,21,*range(22,35))]
        state=copy.deepcopy(base['postgres']);state['groups'][0]['revision']=2;state['access']['group']['revision']=2
        for row in state['access']['entries']:
            if row['editable']:
                for key,value in zip(('read','create','update','delete'),m['acceptance_flags'](row['sidebar']['id'],2,True)):row[key]=value
        state['audits']=[{'actor_id':101,'target_id':201,'target_type':'group','action':'group_grants','result':'success','request_id':'00000000-0000-4000-8000-000000000001','before_state':base['postgres']['access'],'after_state':copy.deepcopy(state['access'])}]
        self.runcheck(base,state,'save')
        self.runcheck(base,state,'permission-refresh')
        with self.assertRaises(RuntimeError):self.runcheck(base,state,'backend-denied')
        for id,key in ((23,'create'),(32,'delete'),(33,'update'),(20,'read'),(28,'delete')):
            bad=copy.deepcopy(state);row=next(row for row in bad['access']['entries']if row['sidebar']['id']==id);row[key]=1-row[key]
            with self.assertRaises(RuntimeError):self.runcheck(base,bad,'save')
        badbase=copy.deepcopy(base);badbase['postgres']['access']['entries'].pop()
        with self.assertRaises(RuntimeError):self.runcheck(badbase,state,'save')

if __name__=='__main__':unittest.main()
