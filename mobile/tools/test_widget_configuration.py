import argparse, importlib.util, json, os, plistlib, tempfile, zipfile
from pathlib import Path

root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('configure_widget_test',root/'tools/configure_widget_test.py')
helper=importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
with tempfile.TemporaryDirectory() as temporary:
    work=Path(temporary); source=work/'mobile'; source.mkdir()
    (source/'project.yml').write_text((root/'project.yml').read_text())
    args=argparse.Namespace(team_id='ABCDE12345',bundle_id='com.example.widgettester',group_id='group.com.example.widgettester',source=source,ipa=None,output=None)
    helper.configure(args)
    text=(source/'project.yml').read_text()
    assert 'PRODUCT_BUNDLE_IDENTIFIER: com.example.widgettester\n' in text
    assert 'PRODUCT_BUNDLE_IDENTIFIER: com.example.widgettester.sessionwidget' in text
    assert text.count('LabsWidgetAppGroup: group.com.example.widgettester')==2
    assert 'DEVELOPMENT_TEAM: ABCDE12345' in text
    assert 'com.example.widgettester.queue.*' in text
    assert plistlib.loads((source/'AppGroups.entitlements').read_bytes())['com.apple.security.application-groups']==['group.com.example.widgettester']
    ipa=work/'original.ipa'; output=work/'configured.ipa'
    info={'CFBundleIdentifier':'org.achievementlabs.widgettest','CFBundleShortVersionString':'0.12.4'}
    with zipfile.ZipFile(ipa,'w') as archive:
        archive.writestr('Payload/Test.app/Info.plist',plistlib.dumps(info))
        archive.writestr('Payload/Test.app/PlugIns/Widget.appex/Info.plist',plistlib.dumps(info))
        executable=zipfile.ZipInfo('Payload/Test.app/Test'); executable.external_attr=0o100755 << 16
        archive.writestr(executable,b'synthetic-executable')
        archive.writestr('Payload/Test.app/Catalogue/data.json',b'{"fixture":true}')
    before=ipa.read_bytes()
    args.source=None; args.ipa=ipa; args.output=output; helper.configure(args)
    assert ipa.read_bytes()==before
    with zipfile.ZipFile(output) as archive:
        app=plistlib.loads(archive.read('Payload/Test.app/Info.plist'))
        widget=plistlib.loads(archive.read('Payload/Test.app/PlugIns/Widget.appex/Info.plist'))
        assert app['CFBundleIdentifier']=='com.example.widgettester'
        assert widget['CFBundleIdentifier']=='com.example.widgettester.sessionwidget'
        assert app['LabsWidgetAppGroup']==widget['LabsWidgetAppGroup']=='group.com.example.widgettester'
        assert app['CFBundleURLTypes'][0]['CFBundleURLSchemes']==[app['LabsWidgetURLScheme']]
        assert app['BGTaskSchedulerPermittedIdentifiers']==['com.example.widgettester.queue.*']
        assert archive.getinfo('Payload/Test.app/Test').external_attr >> 16 & 0o111
        assert archive.read('Payload/Test.app/Catalogue/data.json')==b'{"fixture":true}'
    assert output.with_suffix('.AppGroups.entitlements').exists()
print('PASS: unique identities, shared-group consistency, background prefix, URL routes, IPA executable permissions and original preservation')
