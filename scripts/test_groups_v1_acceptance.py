"""Strict Groups acceptance predicates: JSON-only temporary fixtures."""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

m=runpy.run_path(str(Path(__file__).with_name('groups-v1-acceptance.py')))

class GroupsPredicates(unittest.TestCase):
    def fixture(self):
        return {'sqlite':{'fingerprints':{'payments':'unchanged','cursor':'unchanged'}},'postgres':{'fingerprints':{'grants':'protected','user_identity':'protected'},'integrity':'PASS','recovery':'PASS','groups':[{'id':201,'group_nama':'Operasional','group_jenis':'user','status':1,'revision':1},{'id':202,'group_nama':'Pelayanan','group_jenis':'user','status':1,'revision':1}], 'users':[{'id':202,'group_id':202,'status':1,'revision':1,'security_version':1}], 'audits':[]}}
    def test_initial_readonly_and_preservation(self):
        base=self.fixture()
        with tempfile.TemporaryDirectory(prefix='groups-predicate-') as folder:
            root=Path(folder).resolve(strict=True);(root/'groups-v1-baseline.json').write_text(json.dumps(base))
            def check(state,sqlite=None):
                with patch.dict(m['check'].__globals__,{'postgres':lambda _:state,'snapshot':lambda _:sqlite or base['sqlite']}):m['check'](root,'initial')
            check(base['postgres'])
            for key in ('grants','user_identity'):
                changed=copy.deepcopy(base['postgres']);changed['fingerprints'][key]='changed'
                with self.assertRaises(RuntimeError):check(changed)
            changed=copy.deepcopy(base['postgres']);changed['groups'][0]['revision']=2
            with self.assertRaises(RuntimeError):check(changed)
            with self.assertRaises(RuntimeError):check(base['postgres'],{'cursor':9})
            (root/'launch.lock').write_text('busy')
            with self.assertRaises(RuntimeError):check(base['postgres'])
    def test_complete_state_exact_revision_membership_revocation_and_audit(self):
        base=self.fixture();state=copy.deepcopy(base['postgres'])
        state['groups'][0].update(group_nama='Operasional Terbaru',revision=2)
        state['groups'][1].update(status=0,revision=2)
        state['groups'].append({'id':1001,'group_nama':'Grup Baru Diperbarui','group_jenis':'user','status':1,'revision':2})
        state['users'][0]['security_version']=2
        for i,(action,target,result) in enumerate([('group_create',1001,'success'),('group_update',1001,'success'),('group_update',201,'success'),('group_update',201,'denied'),('group_deactivate',202,'success')]):
            state['audits'].append({'actor_id':101,'target_id':target,'target_type':'group','action':action,'result':result,'reason_code':'stale_revision' if result=='denied' else '', 'request_id':f'00000000-0000-4000-8000-{i:012d}'})
        with tempfile.TemporaryDirectory(prefix='groups-predicate-') as folder:
            root=Path(folder).resolve(strict=True);(root/'groups-v1-baseline.json').write_text(json.dumps(base))
            with patch.dict(m['check'].__globals__,{'postgres':lambda _:state,'snapshot':lambda _:base['sqlite']}):
                m['check'](root,'final')
                for row,key,value in [(state['users'][0],'group_id',201),(state['users'][0],'security_version',1),(state['groups'][1],'status',1),(state['audits'][0],'actor_id',201)]:
                    old=row[key];row[key]=value
                    with self.assertRaises(RuntimeError):m['check'](root,'final')
                    row[key]=old

if __name__=='__main__':unittest.main()
