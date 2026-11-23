import copy
import runpy
from pathlib import Path
import unittest
m=runpy.run_path(str(Path(__file__).with_name('h02-acceptance.py')))
class H02Predicates(unittest.TestCase):
 def test_exact_category_actor_identity_and_tombstone(self):
  base=[{'id':1,'nama':'Baseline'}];r={'id':2,'uuid':'00000000-0000-4000-8000-000000000001','nama':'Kategori H02','created_by':101,'updated_by':None,'is_sync_dirty':1,'last_synced_at':None,'created_at':1,'status':1,'deleted_at':None}
  m['verify_category'](base,base+[r],'editor-create')
  edited={**r,'nama':'Kategori H02 diperiksa','updated_by':101};m['verify_category'](base,base+[edited],'editor-update',r)
  final={**edited,'status':0,'deleted_at':2};m['verify_category'](base,base+[final],'final',r)
  for field,value in [('uuid','unknown'),('created_by',201),('updated_by',101),('is_sync_dirty',0),('last_synced_at',9),('nama','wrong')]:
   with self.assertRaises(RuntimeError):m['verify_category'](base,base+[{**r,field:value}],'editor-create')
  with self.assertRaises(RuntimeError):m['verify_category'](base,[{'id':1,'nama':'Changed'},r],'editor-create')
  with self.assertRaises(RuntimeError):m['verify_category'](base,base+[r],'read-only')
 def test_deny_http_mutation_and_false_global_success(self):
  m['verify_events']([],'initial')
  for event in [{'event':'http','allowed':True,'method':'PUT','path':'/api/v1/pemohon'},{'event':'global_outcome','outcome':'success'}]:
   with self.assertRaises(RuntimeError):m['verify_events']([event],'read-only')
if __name__=='__main__':unittest.main()
