"""通过回环 HTTP 验证 CLI 的预览、授权、重试以及文件交付边界。"""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread
import unittest
from zipfile import ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[2]
PID = '9007199254740993001'
TASK = {'projectId': PID, 'taskNo': 'PG-acceptance', 'generationMode': 'ADOPT_FRONTEND', 'status': 'SUCCESS'}
CODE = 'receipt-demo'


class Fixture(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def respond(self, data, status=200, message=''):
        raw = json.dumps({'code': 0, 'data': data, 'message': message}, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        state = self.server.state
        if self.path.startswith('/api/projects?'):
            return self.respond({'records': [state['project']] if 'project' in state else []})
        if self.path.startswith('/api/project-generations?'):
            return self.respond([TASK] if state.get('generated') else [])
        if self.path.endswith('/download/BACKEND'):
            state['download'] = state.get('download', 0) + 1
            artifact = io.BytesIO()
            with ZipFile(artifact, 'w') as output:
                output.writestr('backend/docs/kaiwu-project-blueprint.json', json.dumps({**TASK, 'projectCode': CODE}))
                archived = ZipInfo('backend/pom.xml')
                archived.extra = bytes.fromhex('555405000100000000')  # 旧 ZIP 的 Unix 0 修改时间
                output.writestr(archived, '<project/>')
            self.send_response(200)
            self.end_headers()
            self.wfile.write(artifact.getvalue())
            return
        if self.path.endswith(TASK['taskNo']):
            return self.respond(TASK)
        if self.path.endswith('/access-admin/roles'):
            return self.respond([{'roleCode': 'manager', 'status': 'ACTIVE'}])
        if self.path.endswith('/access-admin/permissions'):
            return self.respond([{'code': 'purchase:request:submit'}])
        self.send_error(404)

    def do_POST(self):
        state = self.server.state
        body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))) or b'{}')
        if self.path == '/api/auth/refresh':
            return self.respond({'accessToken': 'test'})
        if self.headers.get('Authorization') != 'Bearer test':
            return self.respond({}, 401)
        if self.path == '/api/projects':
            if 'project' in state:
                return self.respond({}, 409)
            state['project'] = {'id': PID, **body, 'builtIn': False, 'status': 'ACTIVE'}
            return self.respond(state['project'])
        if self.path == '/api/project-generations':
            if state.pop('fail_generate', False):
                return self.respond({}, 503)
            if state.get('generated') or body != {'projectId': PID, 'generationMode': 'ADOPT_FRONTEND'}:
                return self.respond({}, 409)
            state['generated'] = True
            return self.respond(TASK)
        if self.path.startswith(f'/api/projects/{PID}/manifest/'):
            with_roles = 'roles.yml' in body['files']
            if 'menus.yml' not in body['files'] or 'binding.yml' in body['files']:
                return self.respond({}, 400)
            if self.path.endswith('/plan'):
                state.setdefault('role_plans', []).append(with_roles)
                changes = []
                if with_roles and not state.get('manager_grant'):
                    changes.append({'resource':'ROLE_GRANT','key':'manager','action':'CREATE','detail':'ok','category':'ACCESS'})
                if state.get('config_pending'):
                    changes.append({'resource':'CONFIG','key':'label','action':'UPDATE','detail':'ok','category':'NORMAL'})
                if with_roles and state.pop('finish_concurrently', False):
                    state['synced'] = True
                baseline = state.get('baseline_reply', state.get('synced', False))
                plan = {'changes':changes,'missingPermissions':[],'planHash':'manifest','hasBaseline':baseline}
                return self.respond(plan)
            if body.get('planHash')=='manifest' and body.get('applyAccess') is with_roles:
                if state.pop('fail_sync', False):
                    return self.respond({}, 403)
                if with_roles:
                    state['manager_grant'] = True
                state['config_pending'] = False
                state['synced'] = True
                return self.respond({})
        if self.path.startswith(f'/{CODE}-svc/workflow/api/v1/workflow/manifest/'):
            if self.headers.get('X-Project-Id')!=PID or body.get('businessType')!='purchase':
                return self.respond({},400)
            if 'workflow_error' in state:
                return self.respond({}, *state['workflow_error'])
            if self.path.endswith('/plan'):
                return self.respond({'action':'UNCHANGED' if state.get('workflow') else 'CREATE','planHash':'workflow','roles':['manager'],'initiatePermission':'purchase:request:submit'})
            if body.get('planHash')=='workflow' and not state.get('workflow'):
                state['workflow']=True
                return self.respond({})
        self.send_error(400)


class ProductHandoff(unittest.TestCase):
    def test_adopt_and_independent_workflow_sync(self):
        with tempfile.TemporaryDirectory() as folder, HTTPServer(('127.0.0.1',0),Fixture) as server:
            root=Path(folder)
            cli=root/'system/scripts'
            cli.mkdir(parents=True)
            for file in ['kaiwu.sh','database-config.sh','workflow-sync.sh','project-adopt.sh']:
                shutil.copy(ROOT/'scripts'/file,cli/file)
            shutil.copy(ROOT/'kaiwu-workspace.env',cli.parent)
            session=root/'.kaiwu/cli/cli-session'
            session.parent.mkdir(parents=True)
            session.write_text('# Netscape HTTP Cookie File\n')
            front=root/'custom-web'
            (front/'docs').mkdir(parents=True)
            flow=front/'kaiwu/workflows/purchase'
            flow.mkdir(parents=True)
            (flow/'binding.yml').write_text('businessType: purchase\n')
            for f in ['menus','roles']:
                (front/'kaiwu'/f'{f}.yml').write_text('[]\n')
            blueprint=front/'docs/kaiwu-project-blueprint.json'
            blueprint.write_text(json.dumps({'projectName':'采购','projectCode':CODE,'templateVersion':'v27','adoptionId':'00000000-0000-4000-8000-000000000007'}))
            subprocess.run(['git','init','-q',front], check=True)
            subprocess.run(['git','-C',front,'remote','add','origin','https://example.invalid/team/demo.git'],check=True)
            source={p:p.read_bytes() for p in front.rglob('*') if p.is_file() and '.git' not in p.parts}
            server.state={}
            Thread(target=server.serve_forever,daemon=True).start()
            def run(group,operation,*args,success=True):
                result=subprocess.run(['bash',cli/'kaiwu.sh',group,operation,front,*args], env={**os.environ,'NO_PROXY':'127.0.0.1','no_proxy':'127.0.0.1','KAIWU_URL':f'http://127.0.0.1:{server.server_port}'},capture_output=True,text=True,errors='replace', timeout=15)
                self.assertEqual(result.returncode==0,success, result.stdout+result.stderr)
                return result
            try:
                preview = run('project','adopt').stdout
                self.assertIn('首次导入的项目角色', preview)
                self.assertFalse(server.state)
                # 项目已登记，首次清单事务失败：继续同步时仍需导入角色。
                server.state['fail_sync'] = True
                run('project','adopt','--apply',success=False)
                self.assertNotIn('synced',server.state)
                # 无法确认是否已有回执时，既不上传 roles.yml，也不执行同步。
                server.state.update(role_plans=[], baseline_reply='false')
                run('project','adopt','--apply',success=False)
                self.assertEqual(server.state['role_plans'],[False])
                self.assertNotIn('synced',server.state)
                server.state.pop('baseline_reply')
                server.state['role_plans'].clear()
                run('project','adopt')
                self.assertEqual(server.state['role_plans'],[False,True])
                self.assertNotIn('synced',server.state)
                # 同步成功，但创建生成任务失败：此时服务端已有回执，本地无后端目录。
                server.state['fail_generate'] = True
                run('project','adopt','--apply',success=False)
                self.assertTrue(server.state['manager_grant'])
                self.assertNotIn('generated',server.state)
                server.state.update(manager_grant=False, config_pending=True, role_plans=[])
                run('project','adopt')
                run('project','adopt','--apply')
                self.assertEqual(server.state['role_plans'],[False,False])
                self.assertFalse(server.state['manager_grant'])
                self.assertFalse(server.state['config_pending'])
                # 兼容旧 CLI 零差异未留回执：生成任务本身证明首次同步已经结束。
                server.state.pop('synced')
                server.state.update(role_plans=[], config_pending=True)
                run('project','adopt')
                run('project','adopt','--apply')
                self.assertEqual(server.state['role_plans'],[False,False])
                self.assertFalse(server.state['manager_grant'])
                run('project','sync','--apply','--with-access')
                self.assertTrue(server.state['manager_grant'])
                self.assertTrue(server.state['synced'])
                self.assertEqual(server.state['download'],1)
                self.assertEqual(server.state['project']['repositoryUrl'],'https://example.invalid/team/demo.git')
                self.assertGreater((root/(CODE+'-service')/'pom.xml').stat().st_mtime, 0)
                self.assertNotIn('workflow',server.state)
                pulled=root/'pull'
                (pulled/(CODE+'-web')).mkdir(parents=True)
                subprocess.run(['bash',cli/'kaiwu.sh','project','pull',CODE,'--dir',pulled],env={**os.environ,'NO_PROXY':'127.0.0.1','no_proxy':'127.0.0.1','KAIWU_URL':f'http://127.0.0.1:{server.server_port}'},capture_output=True,check=True)
                self.assertTrue((pulled/(CODE+'-service')/'pom.xml').exists())
                self.assertFalse(list((pulled/(CODE+'-web')).iterdir()))
                for status,reason,hint in [(403,'forbidden','workflow:document:manage'),(409,'workflow.callbackTargetMissing','callbacks.targets[purchase]'),(404,'missing','Workflow 路由')]:
                    server.state['workflow_error']=(status,reason)
                    self.assertIn(hint,run('workflow','sync','--apply',success=False).stderr)
                    self.assertNotIn('workflow',server.state)
                del server.state['workflow_error']
                run('workflow','sync')
                self.assertNotIn('workflow',server.state)
                run('workflow','sync','--apply')
                run('workflow','sync','--apply')
                self.assertTrue(server.state['workflow'])
                self.assertEqual(source,{p:p.read_bytes() for p in front.rglob('*') if p.is_file() and '.git' not in p.parts})
                server.state['project']['description']='foreign'
                run('project','adopt','--apply',success=False)
                # 前端蓝图早于初始化标识时，以共同的 Git 根提交识别。
                old = json.loads(blueprint.read_text())
                old.pop('adoptionId')
                blueprint.write_text(json.dumps(old))
                subprocess.run(['git','-C',front,'add','.'],check=True)
                subprocess.run(['git','-C',front,'-c','user.name=Fixture','-c','user.email=test@example.invalid','commit','-qm','base'],check=True)
                state=server.state
                state.clear()
                (root/(CODE+'-service')).rename(root/'previous-backend')
                # 首次没有差异仍保存成功回执；生成前中断后不可重新引入已撤销授权。
                state.update(manager_grant=True, fail_generate=True)
                run('project','adopt','--apply',success=False)
                self.assertTrue(state['synced'])
                state.update(manager_grant=False, role_plans=[])
                run('project','adopt','--apply')
                self.assertEqual(state['role_plans'],[False])
                self.assertFalse(state['manager_grant'])
                self.assertTrue(state['project']['description'].startswith('产品前端 git-'))
                run('project','adopt','--apply')
                # 两次预检之间另一客户端已完成首次导入：本次不得继续写授权。
                state.clear()
                state.update(finish_concurrently=True, manager_grant=False)
                (root/(CODE+'-service')).rename(root/'legacy-backend')
                run('project','adopt','--apply',success=False)
                self.assertFalse(state['manager_grant'])
                self.assertNotIn('generated', state)
                run('project','adopt','--apply')
                self.assertFalse(state['manager_grant'])
            finally:
                server.shutdown()

    def test_invalid_project_code_names_actual_source(self):
        with tempfile.TemporaryDirectory() as folder:
            project = Path(folder)
            route = project / 'deploy/server/gateway-route.yml'
            blueprint = project / 'docs/kaiwu-project-blueprint.json'
            (project / 'kaiwu').mkdir()
            route.parent.mkdir(parents=True)
            blueprint.parent.mkdir()

            def error():
                result = subprocess.run(
                    ['bash', ROOT / 'scripts/kaiwu.sh', 'project', 'sync', project],
                    text=True, capture_output=True, timeout=5,
                )
                self.assertNotEqual(result.returncode, 0)
                return result.stderr

            blueprint.write_text(json.dumps({'projectCode': CODE}))
            route.write_text('projectCode: Bad_Code\n')
            self.assertIn(str(route), error())
            route.unlink()
            for raw in ['{"projectCode":"Bad_Code"}', '{}', '{"projectCode":7}', '{',
                        json.dumps({'projectCode': CODE + '\n'})]:
                with self.subTest(blueprint=raw):
                    blueprint.write_text(raw)
                    message = error()
                    self.assertIn(str(blueprint), message)
                    self.assertNotIn('gateway-route.yml', message)
            blueprint.unlink()
            message = error()
            self.assertIn(str(route), message)
            self.assertIn(str(blueprint), message)

if __name__=='__main__':
    unittest.main()
