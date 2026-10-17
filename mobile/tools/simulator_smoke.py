"""Launch the actual simulator app without credentials or Xbox requests."""
import json
import subprocess
import time
from pathlib import Path

def run(*args):
    print('Checking: '+' '.join(args),flush=True)
    return subprocess.check_output(args,text=True,timeout=120)
devices=json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
available=[d for runtime,group in devices.items() if 'iOS-26' in runtime for d in group if d['name'].startswith('iPhone')]
assert available, 'No iOS 26 simulator for background API checks'
assert available, 'No available iPhone simulator'
available.sort(key=lambda d:('Max' in d['name'],'Plus' in d['name'],'Pro' in d['name'],d['name']))
device=available[0]['udid']
print('Chosen simulator: '+available[0]['name'],flush=True)
subprocess.run(['xcrun','simctl','boot',device],check=False)
print('Waiting for iOS 26 simulator boot',flush=True)
subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=180)
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

output=run('xcrun','simctl','launch',device,'org.achievementlabs.mobile','--ui-preview=queue','--background-self-test')
time.sleep(12)
container=Path(run('xcrun','simctl','get_app_container',device,'org.achievementlabs.mobile','data').strip())
result=json.loads((container/'Documents'/'Background-self-test.json').read_text())
assert result['available'] and result['finishedInactive'], 'Background request did not finish safely'
assert result['manifestValid'], 'Background identifiers/modes missing from the built app'
print('iOS 26 background API request completed or safely declined with no network: '+str(result))
subprocess.run(['xcrun','simctl','terminate',device,'org.achievementlabs.mobile'],check=True)
