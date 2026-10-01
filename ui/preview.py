#!/usr/bin/env python3
"""The real PocketJS UI with a local Unix-socket microphone mock; no cloud calls."""
import argparse,json,math,os,socket,subprocess,tempfile,threading,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PACKAGE=ROOT/'build/brick-mic/pocketjs-preview'
TEXT='今天我们试着用掌机输入一段中文。按住 A 说话，松开后等待识别，文字就会同步到 Mac。\n\n新的界面沿用系统主题色和中文字体，长句会自动换行。上下键可以阅读较长的识别结果。'*4

class Mock:
    def __init__(self,path,state='ready'):
        self.server=socket.socket(socket.AF_UNIX);self.server.bind(str(path));self.server.listen()
        self.commands=[];self.state=state;self.session=1;self.started=time.monotonic();self.finish=0;self.alive=True
        self.offline_until=0;self.recovered_pings=0
        self.thread=threading.Thread(target=self.serve,daemon=True);self.thread.start()
    def serve(self):
        while self.alive:
            try:
                conn,_=self.server.accept()
                with conn:
                    command=conn.recv(128).decode().strip();now=time.monotonic()
                    if now<self.offline_until:continue
                    if command=='ping' and self.offline_until:self.recovered_pings+=1
                    if command in ('start','stop','cancel'):
                        self.commands.append(command)
                        if command=='start':self.state='recording';self.started=now;self.session+=1
                        elif command=='stop' and self.state=='recording':self.state='processing';self.finish=now+.35
                        elif command=='cancel':self.state='ready';self.finish=0
                    if self.state=='processing' and self.finish and now>=self.finish:self.state='result'
                    if command=='ping':payload=b'ready\n'
                    else:
                        elapsed=now-self.started
                        data=dict(state='ready' if self.state=='result' else self.state,connected=self.state not in ('bluetooth','service','disconnected','error'),session=self.session,seconds=elapsed,rms=int(3500+2600*math.sin(elapsed*6)),text=TEXT if self.state=='result' else '',error='蓝牙服务暂时不可用，请按 A 重试。' if self.state=='error' else '')
                        payload=(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n').encode()
                    conn.sendall(payload)
            except OSError:
                if self.alive:raise
    def close(self):self.alive=False;self.server.close()

def run(state,frames=0,output=None,input_test=False,settings=None,power_test=False):
    with tempfile.TemporaryDirectory(prefix='brick-mic-preview-') as folder:
        data=Path(folder);mock=Mock(data/'mic.sock',state)
        env={**os.environ,'BRICK_MIC_PREVIEW':'1','BRICK_MIC_SOCKET':str(data/'mic.sock'),'POCKETJS_DATA':str(data/'cache'),'BRICK_MIC_FONT':str(ROOT/'fonts/font1.ttf'),'BRICK_MIC_SETTINGS':str(settings or ROOT/'ui/theme-preview.txt')}
        args=[str(PACKAGE/('pocketjs-mic' if frames else 'Brick Mic UI Preview.app/Contents/MacOS/pocketjs-mic'))]
        if frames:args+=['--headless','--frames',str(frames)]
        if input_test:args+=['--input-test']
        if power_test:args+=['--power-test']
        if output:args+=['--dump',str(output),'--dump-first',str(output)+'.first.ppm']
        if not frames:
            forwarded=['open','-n','-W']
            for key in ['BRICK_MIC_PREVIEW','BRICK_MIC_SOCKET','POCKETJS_DATA','BRICK_MIC_FONT','BRICK_MIC_SETTINGS']:
                forwarded+=['--env',key+'='+env[key]]
            args=forwarded+[str(PACKAGE/'Brick Mic UI Preview.app')]
        try:
            proc=subprocess.run(args,cwd=PACKAGE,env=env,check=True,timeout=30 if frames else None)
            return mock.commands
        finally:mock.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--state',default='ready',choices=['bluetooth','service','disconnected','ready','recording','processing','result','error']);parser.add_argument('--frames',type=int,default=0);parser.add_argument('--output',type=Path)
    args=parser.parse_args();run(args.state,args.frames,args.output)
