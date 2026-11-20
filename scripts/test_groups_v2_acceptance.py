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
            probe={'read':200,'create':403,'update':403,'delete':403}
            with patch.dict(m['check'].__globals__,{'postgres':lambda _:state,'snapshot':lambda _:sqlite or base['sqlite'],'occupied':lambda _:True,'helper':lambda _,action:'{}'if action=='http-check'else json.dumps(probe)}):
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

if __name__=='__main__':unittest.main()
