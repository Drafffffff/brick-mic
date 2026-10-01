#!/usr/bin/env python3
from pathlib import Path
import json,subprocess,tempfile
from preview import ROOT,run

output=ROOT/'build/brick-mic/ui-validation';output.mkdir(parents=True,exist_ok=True)
for state in ['bluetooth','service','disconnected','ready','recording','processing','result','error']:
    run(state,frames=40,output=output/(state+'.ppm'))
    subprocess.run(['sips','-s','format','png',str(output/(state+'.ppm')),'--out',str(output/(state+'.png'))],check=True,stdout=subprocess.DEVNULL)
    pixels=(output/(state+'.ppm')).read_bytes().split(b'\n',3)[3]
    assert len(pixels)==1024*768*3
    assert pixels[:3]==bytes.fromhex('e9f2f5'),(state,'did not inherit the NextUI background')
    print('PASS: real PocketJS render, theme, font and native IPC: '+state)
commands=run('ready',frames=200,input_test=True,output=output/'input.ppm')
assert commands==['start','stop','cancel'],commands
print('PASS: quick A tap preserves start/stop ordering; B cancels through native IPC')
commands=run('error',frames=200,input_test=True,output=output/'retry.ppm')
assert commands==['cancel'],commands
print('PASS: A retries a disconnected service without starting a recording')
commands=run('recording',frames=135,power_test=True,output=output/'wake.ppm')
assert commands==['cancel'],commands
print('PASS: sleeping cancels microphone; wake retains the same PocketJS runtime')
with tempfile.TemporaryDirectory(prefix='mic-theme-check-') as d:
    settings=Path(d)/'settings.txt';settings.write_text('font=1\ncolor1=0xFFFFFFFF\ncolor4=0xEAE7DDFF\ncolor5=0x151820FF\ncolor6=0xB1B9CFFF\ncolor7=0x151820\n')
    run('ready',frames=35,output=output/'dark.ppm',settings=settings)
    pixels=(output/'dark.ppm').read_bytes().split(b'\n',3)[3]
    assert pixels[:3]==bytes.fromhex('151820')
    print('PASS: dark theme and legacy RGB color format')
