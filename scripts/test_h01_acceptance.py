import runpy
from pathlib import Path
import unittest
m=runpy.run_path(str(Path(__file__).with_name('h01-acceptance.py')))
check=m['verify_events']
class H01Predicates(unittest.TestCase):
    def test_initial_empty_only(self):
        check([], 'initial')
        with self.assertRaises(RuntimeError):check([{'event':'entrypoint'}],'initial')
    def test_reads_login_only_and_no_false_success(self):
        entries=[{'event':'entrypoint','entry':'lib/main.dart','ui_smoke':False,'isolated_manual_configuration':False,'unix_ms':1000,'launch':'1'},{'event':'session','state':'authenticated','unix_ms':1000,'launch':'1'},{'event':'restore','restored':True},{'event':'global_outcome','outcome':'disabledByPolicy'},{'event':'lifecycle','state':'inactive'},{'event':'lifecycle','state':'resumed'},{'event':'http_error','kind':'connectionError'},{'event':'http_response','status':200},{'event':'launch_closed','unix_ms':331000,'launch':'1'}]
        check(entries,'final')
        for method,path in [('GET','/api/v1/sync/pull'),('GET','/api/v1/pemohon/sync/delete'),('POST','/api/v1/transaksi-notaris/sync/create'),('PUT','/api/v1/x'),('PATCH','/api/v1/profile'),('DELETE','/api/v1/x')]:
            with self.assertRaises(RuntimeError):check(entries+[{'event':'http','method':method,'path':path,'allowed':True}],'final')
        with self.assertRaises(RuntimeError):check(entries+[{'event':'global_outcome','outcome':'success'}],'final')
        with self.assertRaises(RuntimeError):check(entries+[{'event':'http','method':'GET','path':'/api/v1/profile','allowed':False}],'final')
    def test_launch_time_is_not_runtime_wait_proof(self):
        entries=[{'event':'launch_start','unix_ms':0,'launch':'1'},{'event':'entrypoint','entry':'lib/main.dart','ui_smoke':False,'isolated_manual_configuration':False,'unix_ms':330000,'launch':'1'},{'event':'session','state':'authenticated','unix_ms':330000,'launch':'1'},{'event':'launch_closed','unix_ms':331000,'launch':'1'}]
        with self.assertRaises(RuntimeError):check(entries,'wait')
if __name__=='__main__':unittest.main()
