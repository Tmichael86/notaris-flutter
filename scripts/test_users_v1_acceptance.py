"""Focused acceptance predicates; JSON-only temporary fixtures, no PostgreSQL."""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

m=runpy.run_path(str(Path(__file__).with_name('users-v1-acceptance.py')))


class AcceptancePredicates(unittest.TestCase):
    def test_initial_and_fail_closed_preservation(self):
        base={'sqlite':{'fingerprints':{'payments':'protected','cursor':'protected'}},
              'postgres':{'fingerprints':{'groups':'protected'},'integrity':'PASS','recovery':'PASS',
                          'users':[{'id':301,'nama':'Operator 01'},{'id':302,'nama':'Operator 02'}],'audits':[]}}
        with tempfile.TemporaryDirectory(prefix='users-predicates-') as folder:
            root=Path(folder).resolve(strict=True)
            (root/'users-v1-baseline.json').write_text(json.dumps(base))
            globals_=m['check'].__globals__
            def run(state,sqlite=None,phase='initial'):
                with patch.dict(globals_,{'postgres':lambda _:state,'snapshot':lambda _:sqlite or base['sqlite']}):
                    m['check'](root,phase)
            run(base['postgres'])
            for changed in ('groups','protected_users'):
                bad=copy.deepcopy(base['postgres']);bad['fingerprints'][changed]='altered'
                with self.assertRaises(RuntimeError):run(bad)
            with self.assertRaises(RuntimeError):run(base['postgres'],{'fingerprints':{'payments':'altered'}})
            bad=copy.deepcopy(base['postgres']);bad['users'][0]['nama']='rewritten'
            with self.assertRaises(RuntimeError):run(bad)
            (root/'launch.lock').write_text('running')
            with self.assertRaises(RuntimeError):run(base['postgres'])

    def test_create_exact_identity_revision_and_audit(self):
        base={'sqlite':{'unchanged':True},'postgres':{'fingerprints':{},'users':[]}}
        created={'id':1001,'group_id':201,'username':'operator.baru','email':'operator.baru@example.invalid',
                 'nama':'Operator Baru','status':1,'revision':1,'security_version':1}
        audit={'actor_id':101,'target_id':1001,'target_type':'user','action':'user_create','result':'success',
               'request_id':'00000000-0000-4000-8000-000000000001'}
        state={'fingerprints':{},'integrity':'PASS','recovery':'PASS','users':[created],'audits':[audit]}
        with tempfile.TemporaryDirectory(prefix='users-predicates-') as folder:
            root=Path(folder).resolve(strict=True);(root/'users-v1-baseline.json').write_text(json.dumps(base))
            with patch.dict(m['check'].__globals__,{'postgres':lambda _:state,'snapshot':lambda _:base['sqlite']}):
                m['check'](root,'create')
                created['revision']=2
                with self.assertRaises(RuntimeError):m['check'](root,'create')
                created['revision']=1;audit['actor_id']=201
                with self.assertRaises(RuntimeError):m['check'](root,'create')
                audit['actor_id']=101;state['audits'].append(audit)
                with self.assertRaises(RuntimeError):m['check'](root,'create')


if __name__=='__main__':unittest.main()
