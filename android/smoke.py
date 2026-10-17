"""Offline-only emulator verification: synthetic UI, no sign-in or live Xbox calls."""
import subprocess,time,pathlib
root=pathlib.Path('android/artifacts');root.mkdir(exist_ok=True)
def run(*args):return subprocess.check_output(args,text=True)
subprocess.run(['adb','install','-r','android/app/build/outputs/apk/debug/app-debug.apk'],check=True)
for page in ['home','library','queue','spoof','settings']:
 subprocess.run(['adb','shell','am','force-stop','org.achievementlabs.mobile'],check=True)
 subprocess.run(['adb','shell','am','start','-W','-n','org.achievementlabs.mobile/.MainActivity','--ez','preview','true','--es','page',page],check=True)
 time.sleep(4)
 assert run('adb','shell','pidof','org.achievementlabs.mobile').strip(),'App exited: '+page
 with open(root/f'Android-{page}.png','wb') as f:subprocess.run(['adb','exec-out','screencap','-p'],check=True,stdout=f)
log=run('adb','logcat','-d','-s','AndroidRuntime:E')
assert 'FATAL EXCEPTION' not in log,log
print('Five offline Android screens launched without credentials or Xbox requests.')
