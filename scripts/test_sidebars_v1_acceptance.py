"""Acceptance predicates only; temporary JSON, never existing profiles."""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

m=runpy.run_path(str(Path(__file__).with_name('sidebars-v1-acceptance.py')))

class SidebarsPredicates(unittest.TestCase):
    def baseline(self):
        return {'sqlite':{'schema':27,'integrity':'ok','fk':0,'fingerprints':{'payments':'protected','cursor':'protected'}},'postgres':{'integrity':'PASS','recovery':'PASS','access':{'entries':[{'sidebar':{'status':1}},{'sidebar':{'status':0}}]},'users':[{'id':1,'group_id':1,'security_version':1}],'grants':[{'read':1}],'audits':[],'fingerprints':{'sidebar':'unchanged'}}}
    def check(self,base,state=None,sqlite=None,phase='initial',busy=False):
        with tempfile.TemporaryDirectory(prefix='notaris-sidebars-predicate-')as folder:
            root=Path(folder).resolve();(root/'sidebars-v1-baseline.json').write_text(json.dumps(base),encoding='utf-8')
            if busy:(root/'launch.lock').write_text('active')
            with patch.dict(m['check'].__globals__,{'snapshot':lambda _:sqlite or base['sqlite'],'state':lambda _:state or base['postgres'],'occupied':lambda _:False}):m['check'](root,phase)
    def test_readonly_initial_offline_and_lock(self):
        b=self.baseline();self.check(b);self.check(b,phase='offline')
        with self.assertRaises(RuntimeError):self.check(b,phase='final')
        with self.assertRaises(RuntimeError):self.check(b,busy=True)
        with self.assertRaises(RuntimeError):m['root_for']('../development')
    def test_every_protected_state_change_fails_closed(self):
        b=self.baseline()
        for key in b['postgres']:
            s=copy.deepcopy(b['postgres']);s[key]='changed'
            with self.assertRaises(RuntimeError):self.check(b,state=s)
        for key in b['sqlite']:
            s=copy.deepcopy(b['sqlite']);s[key]='changed'
            with self.assertRaises(RuntimeError):self.check(b,sqlite=s)

if __name__=='__main__':unittest.main()
