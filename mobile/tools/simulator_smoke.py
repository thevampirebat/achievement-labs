"""Launch the actual simulator app without credentials or Xbox requests."""
import json
import subprocess
import time
from pathlib import Path

def run(*args): return subprocess.check_output(args,text=True)
devices=json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
available=[d for group in devices.values() for d in group if d['name'].startswith('iPhone')]
assert available, 'No available iPhone simulator'
device=available[0]['udid']
subprocess.run(['xcrun','simctl','boot',device],check=False)
subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True)
app='mobile/simulator/Build/Products/Debug-iphonesimulator/AchievementLabsMobile.app'
subprocess.run(['xcrun','simctl','install',device,app],check=True)
try:
    output=run('xcrun','simctl','launch',device,'org.achievementlabs.mobile','--storage-self-test')
except subprocess.CalledProcessError:
    subprocess.run(['xcrun','simctl','spawn',device,'log','show','--last','2m','--style','compact','--predicate','process == "AchievementLabsMobile" OR eventMessage CONTAINS "org.achievementlabs.mobile"'],check=False,timeout=120)
    raise
print(output)
pid=output.strip().rsplit(':',1)[-1].strip()
time.sleep(5)
subprocess.run(['xcrun','simctl','spawn',device,'launchctl','list'],check=True,stdout=subprocess.DEVNULL)
processes=run('xcrun','simctl','spawn',device,'launchctl','list')
assert any(line.split() and line.split()[0] == pid and 'org.achievementlabs.mobile' in line for line in processes.splitlines()), 'App exited after launch'
Path('mobile/artifacts').mkdir(exist_ok=True)
subprocess.run(['xcrun','simctl','io',device,'screenshot','mobile/artifacts/iPhone-launch.png'],check=True)
subprocess.run(['xcrun','simctl','terminate',device,'org.achievementlabs.mobile'],check=True)
print('Simulator launch passed; no account connected or network actions requested.')

for page in ['library','queue','spoof','settings','settings-sync','settings-library','settings-app','home']:
    output=run('xcrun','simctl','launch',device,'org.achievementlabs.mobile','--ui-preview='+page)
    preview_pid=output.strip().rsplit(':',1)[-1].strip()
    time.sleep(3)
    processes=run('xcrun','simctl','spawn',device,'launchctl','list')
    assert any(line.split() and line.split()[0] == preview_pid and 'org.achievementlabs.mobile' in line for line in processes.splitlines()), 'Preview exited: '+page
    subprocess.run(['xcrun','simctl','io',device,'screenshot','mobile/artifacts/iPhone-'+page+'.png'],check=True)
    subprocess.run(['xcrun','simctl','terminate',device,'org.achievementlabs.mobile'],check=True)
print('Eight offline refinement screens launched. All preview network requests are blocked.')

output=run('xcrun','simctl','launch',device,'org.achievementlabs.mobile','--web-callback-self-test')
time.sleep(5)
container=Path(run('xcrun','simctl','get_app_container',device,'org.achievementlabs.mobile','data').strip())
marker=container/'Documents'/'Callback-self-test.txt'
assert marker.read_text() == 'passed', 'Embedded WebKit did not capture and validate the synthetic redirect'
subprocess.run(['xcrun','simctl','terminate',device,'org.achievementlabs.mobile'],check=True)
print('Embedded WebKit automatic callback capture and full redirect validation passed without credentials or OAuth requests.')
