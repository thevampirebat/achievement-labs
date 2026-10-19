#!/usr/bin/env python3
"""Configure a developer's unique identities before building or signing this test app."""
import argparse, os, plistlib, re, shutil, tempfile, zipfile
from pathlib import Path

def identifier(value):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]{2,180}',value) or '..' in value:
        raise argparse.ArgumentTypeError('Use a reverse-domain identifier with letters, digits, dots and hyphens.')
    return value

def configure(args):
    bundle=args.bundle_id; group=args.group_id or 'group.'+bundle
    if not group.startswith('group.'): raise ValueError('App Group must start with group.')
    scheme='achievementlabs-widgettest-'+args.team_id.lower()
    entitlements={'com.apple.security.application-groups':[group]}
    if args.ipa:
        if not args.output: raise ValueError('--output is required with --ipa')
        if args.ipa.resolve()==args.output.resolve(): raise ValueError('Keep the original IPA; choose a different output path.')
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            with zipfile.ZipFile(args.ipa) as archive:
                for name in archive.namelist():
                    if name.startswith('/') or '..' in Path(name).parts: raise ValueError('Unsafe archive path')
                archive.extractall(root)
                for info in archive.infolist():
                    mode=(info.external_attr >> 16) & 0o777
                    if mode: os.chmod(root/info.filename,mode)
            apps=list((root/'Payload').glob('*.app'))
            if len(apps)!=1: raise ValueError('Expected exactly one app')
            app=apps[0]; extensions=list((app/'PlugIns').glob('*.appex'))
            if len(extensions)!=1: raise ValueError('Expected exactly one widget extension')
            for target,identity in [(app,bundle),(extensions[0],bundle+'.sessionwidget')]:
                infoPath=target/'Info.plist'; info=plistlib.loads(infoPath.read_bytes())
                info['CFBundleIdentifier']=identity
                info['LabsWidgetAppGroup']=group; info['LabsWidgetURLScheme']=scheme
                if target==app:
                    info['CFBundleURLTypes']=[{'CFBundleURLName':'Labs widget test','CFBundleURLSchemes':[scheme]}]
                    info['BGTaskSchedulerPermittedIdentifiers']=[bundle+'.queue.*']
                infoPath.write_bytes(plistlib.dumps(info,fmt=plistlib.FMT_BINARY))
                shutil.rmtree(target/'_CodeSignature',ignore_errors=True)
                (target/'embedded.mobileprovision').unlink(missing_ok=True)
            args.output.parent.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(args.output,'w',zipfile.ZIP_DEFLATED) as archive:
                for path in root.rglob('*'):
                    if path.is_file(): archive.write(path,path.relative_to(root))
        args.output.with_suffix('.AppGroups.entitlements').write_bytes(plistlib.dumps(entitlements))
        print('Configured unsigned IPA:',args.output.name)
        print('Sign the app AND extension with your own matching profiles. This script does not sign the IPA.')
    else:
        mobile=args.source
        project=mobile/'project.yml'; text=project.read_text()
        oldBundle=re.search(r'PRODUCT_BUNDLE_IDENTIFIER: ([\w.-]+)',text).group(1)
        oldGroup=re.search(r'LabsWidgetAppGroup: ([\w.-]+)',text).group(1)
        oldScheme=re.search(r'LabsWidgetURLScheme: ([\w.-]+)',text).group(1)
        text=re.sub(r'(LabsWidgetAppGroup: )[^\n]+',lambda m:m.group(1)+group,text)
        text=re.sub(r'(LabsWidgetURLScheme: )[^\n]+',lambda m:m.group(1)+scheme,text)
        text=text.replace('PRODUCT_BUNDLE_IDENTIFIER: '+oldBundle+'.sessionwidget','PRODUCT_BUNDLE_IDENTIFIER: '+bundle+'.sessionwidget')
        text=text.replace('PRODUCT_BUNDLE_IDENTIFIER: '+oldBundle+'\n','PRODUCT_BUNDLE_IDENTIFIER: '+bundle+'\n')
        text=text.replace('['+oldBundle+'.queue.*]','['+bundle+'.queue.*]')
        text=text.replace('CFBundleURLSchemes: ['+oldScheme+']','CFBundleURLSchemes: ['+scheme+']')
        text=re.sub(r'^    DEVELOPMENT_TEAM: .+\n','',text,flags=re.M)
        text=text.replace('    CODE_SIGN_STYLE: Automatic','    CODE_SIGN_STYLE: Automatic\n    DEVELOPMENT_TEAM: '+args.team_id)
        project.write_text(text)
        (mobile/'AppGroups.entitlements').write_bytes(plistlib.dumps(entitlements))
        print('Source configured. Run xcodegen generate, then build with your developer team in Xcode.')
    print('App:',bundle,'\nWidget:',bundle+'.sessionwidget','\nApp Group:',group,'\nURL scheme:',scheme)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--team-id',required=True,type=lambda value: value if re.fullmatch('[A-Z0-9]{10}',value) else p.error('Team ID must be 10 uppercase letters/digits'))
    p.add_argument('--bundle-id',required=True,type=identifier)
    p.add_argument('--group-id',type=identifier)
    mode=p.add_mutually_exclusive_group(required=True)
    mode.add_argument('--source',type=Path,help='Mobile source folder containing project.yml')
    mode.add_argument('--ipa',type=Path,help='Unsigned widget-test IPA to configure before signing')
    p.add_argument('--output',type=Path)
    configure(p.parse_args())
if __name__=='__main__': main()
