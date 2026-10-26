#!/usr/bin/env python3
"""Exercise the downloaded bundle through LaunchServices, outside the build directory."""
from pathlib import Path
import json,os,signal,subprocess,sys,tempfile,time
root=Path(__file__).resolve().parents[2]
out=root/'artifacts/macos-preview/checks';out.mkdir(exist_ok=True)
archive=root/'artifacts/macos-preview/AchievementLabs-macOS-0.1.0.1-arm64.zip'
window_query=out/'windows.swift'
window_query.write_text('''import CoreGraphics
import Foundation
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
let matches = windows.filter { window in
    let name = window[kCGWindowOwnerName as String] as? String ?? ""
    let bounds = window[kCGWindowBounds as String] as? [String:Any] ?? [:]
    return ["AchievementLabs","Achievement Labs"].contains(name) && (window[kCGWindowLayer as String] as? Int ?? -1) == 0 && (bounds["Width"] as? Double ?? 0) > 100
}.map { ["pid": $0[kCGWindowOwnerPID as String] ?? 0, "id": $0[kCGWindowNumber as String] ?? 0] }
let bytes = try JSONSerialization.data(withJSONObject:matches)
print(String(data:bytes,encoding:.utf8)!)
''')
query=out/'window-query'
subprocess.run(['swiftc',str(window_query),'-o',str(query)],check=True)
with tempfile.TemporaryDirectory(prefix='Achievement Labs downloaded app ') as folder:
    app=Path(folder)/'Achievement Labs.app'
    subprocess.run(['ditto','-x','-k',str(archive),folder],check=True)
    subprocess.run(['codesign','--verify','--strict','--verbose=2',str(app)],check=True)
    missing=[str(p.relative_to(app)) for p in app.rglob('*') if p.is_symlink() and not p.exists()]
    assert not missing,('Broken packaged links',missing)
    with (out/'finder-stdout.txt').open('w') as stdout,(out/'finder-stderr.txt').open('w') as stderr:
        launch=subprocess.Popen(['open','-W','-n',str(app)],cwd='/',stdout=stdout,stderr=stderr)
        windows=[]
        for attempt in range(30):
            windows=json.loads(subprocess.check_output([str(query)],text=True))
            if windows:break
            if launch.poll() not in (None,0):break
            time.sleep(1)
        if not windows:
            # Capture host-resolution errors without reading any account data.
            env=dict(os.environ,COREHOST_TRACE='1',COREHOST_TRACEFILE=str(out/'finder-host-trace.txt'))
            try:
                result=subprocess.run([str(app/'Contents/MacOS/AchievementLabs')],cwd='/',env=env,stdout=stdout,stderr=stderr,timeout=15)
            except subprocess.TimeoutExpired:pass
            raise RuntimeError('Downloaded .app did not create a visible window through LaunchServices; see finder-stderr/host-trace.')
        time.sleep(5)
        assert json.loads(subprocess.check_output([str(query)],text=True)), 'Normal startup window disappeared'
        try:subprocess.run(['screencapture','-x','-l',str(windows[0]['id']),str(out/'Mac-Finder-launch.png')],check=True)
        except subprocess.CalledProcessError:pass
        for window in windows:
            try:os.kill(window['pid'],signal.SIGTERM)
            except ProcessLookupError:pass
        launch.wait(timeout=20)
    subprocess.run(['codesign','--verify','--strict',str(app)],check=True)
    (out/'finder-launch.json').write_text(json.dumps(dict(passed=True,archiveExtracted=True,launchServices=True,normalStartup=True,workingDirectory='/',visibleWindows=len(windows),signatureValidAfterLaunch=True),indent=2))
    print('PASS: downloaded ZIP extraction, intact links/signature and normal Finder-style startup from / with a visible native window.')
