import copy,runpy,unittest
from pathlib import Path
m=runpy.run_path(str(Path(__file__).with_name('profile-v1-acceptance.py')))
class ProfilePredicates(unittest.TestCase):
 def baseline(self):
  return {'integrity':'PASS','recovery':'PASS','least_privilege':'PASS','protected':{'users':'protected','locks':'protected'},'profile':{'id':201,'username':'user.profile','email':'user@example.invalid','group_id':201,'group_nama':'Reader','group_jenis':'user','status':1,'revision':1,'nama':'Rani Profil','no_telp':None,'alamat':None},'audits':[],'audit_sequence':{'LastValue':1,'IsCalled':False}}
 def saved(self,b):
  c=copy.deepcopy(b);c['profile'].update(revision=2,nama='Rani Profil Diperbarui',no_telp='+62 812-3456-7890',alamat='Alamat demonstrasi diperbarui');c['audit_sequence']['IsCalled']=True
  c['audits']=[{'actor_id':201,'target_id':201,'action':'profile_self_update','target_type':'self_profile','source':'online_admin_api','result':'success','request_id':'00000000-0000-4000-8000-000000000001','before_state':{'revision':1,'fields':['nama','no_telp','alamat'],'origin':'self_service_profile'},'after_state':{'revision':2,'fields':['nama','no_telp','alamat'],'origin':'self_service_profile'}}];return c
 def test_initial_and_one_save(self):
  b=self.baseline();m['verify_delta'](b,b,'initial');m['verify_delta'](b,self.saved(b),'save')
 def test_protected_identity_and_audit_corruption_rejected(self):
  b=self.baseline()
  for key in('id','group_id','group_jenis','username','email','status','revision'):
   c=self.saved(b);c['profile'][key]='forged'
   with self.assertRaises(RuntimeError):m['verify_delta'](b,c,'final')
  for key in('actor_id','target_id','action','target_type','source','result','before_state','after_state','request_id'):
   c=self.saved(b);c['audits'][0][key]='forged'
   with self.assertRaises(RuntimeError):m['verify_delta'](b,c,'final')
 def test_no_extra_save_or_hidden_protected_write(self):
  b=self.baseline();c=self.saved(b);c['protected']['locks']='changed'
  with self.assertRaises(RuntimeError):m['verify_delta'](b,c,'final')
  with self.assertRaises(RuntimeError):m['verify_delta'](b,b,'final')
  with self.assertRaises(RuntimeError):m['verify_delta'](b,self.saved(b),'initial')
if __name__=='__main__':unittest.main()
