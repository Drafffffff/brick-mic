import {createSignal,For,Show,type JSX} from 'solid-js';
import {mount} from '@pocketjs/framework/solid';
import {View,Text} from '@pocketjs/framework/solid/components';
import {onFrame} from '@pocketjs/framework/solid/lifecycle';
import {BTN} from '@pocketjs/framework/input';
import {reportAppAction} from '@pocketjs/framework/host';
import {installServices,prepare} from '../native/services.ts';
import {COPY,mode,clock,mix,stepIndex,scrollRow,type MicState} from './model.ts';
interface Bridge {theme():string[];fonts(text:string):boolean;snapshot():MicState;command(op:'start'|'stop'|'cancel'|'retry'):boolean}
const mic=(globalThis as unknown as {mic:Bridge}).mic;
function App(){
  installServices();
  const c=mic.theme(),bg=c[7],ink=c[4],muted=c[6],accent=c[1],selected=c[5];
  const hairline=mix(bg,ink,.13),soft=mix(bg,accent,.1);
  const alphabet=JSON.stringify(COPY)+'Brick Mic MENU A B Mac 0123456789/:·—%秒行录音正在启动蓝牙语音输入上下阅读';
  if(!mic.fonts(alphabet))throw new Error(COPY.fontError);
  const [state,setState]=createSignal<MicState>({state:'bluetooth'});
  const [phase,setPhase]=createSignal(0),[levels,setLevels]=createSignal<number[]>(Array(28).fill(3));
  const [lines,setLines]=createSignal<string[]>([]),[row,setRow]=createSignal(0);
  let frame=0,old=0,holding=false,lastText='',generation=0,direction=0,held=0,wakeGeneration=0;
  const current=()=>mode(state());
  const booting=()=>current()==='bluetooth'||current()==='service'||current()==='waiting';
  const subtitle=()=>current()==='poweroff'?COPY.poweroffHint:current()==='bluetooth'||current()==='service'?COPY.bootHint:current()==='waiting'?COPY.waitingHint:current()==='recording'?COPY.recordHint:current()==='processing'?COPY.processingHint:current()==='result'?COPY.resultHint:current()==='error'?COPY.errorHint:COPY.readyHint;
  const updateText=async(text:string)=>{
    const mine=++generation;setRow(0);setLines([]);
    if(!text)return;
    try{const rows=await prepare(text);if(mine===generation)setLines(rows);}
    catch(e){if(mine===generation)setState(s=>({...s,state:'error',error:e instanceof Error?e.message:COPY.fontError}));}
  };
  onFrame(buttons=>{
    frame++;const pressed=buttons&~old,released=old&~buttons;old=buttons;
    if(pressed&BTN.CROSS){holding=false;if(booting())reportAppAction('app.exit',1);else mic.command('cancel');}
    else{
      if((pressed&BTN.CIRCLE)&&!booting()&&current()!=='processing'&&current()!=='poweroff'){
        if(current()==='error'&&!state().connected){mic.command('retry');holding=false;}
        else holding=mic.command('start');if(holding){setRow(0);setLevels(Array(28).fill(3));}
      }
      if((released&BTN.CIRCLE)&&holding){holding=false;mic.command('stop');}
    }
    const d=buttons&BTN.DOWN?1:buttons&BTN.UP?-1:0;
    if(d!==direction){direction=d;held=0;}else if(d)held++;
    if(d&&(held===0||held>18&&held%5===0))setRow(r=>scrollRow(r,d,lines().length));
    if(frame%6===0){
      const s=mic.snapshot();setState(s);
      if((s.wakeGeneration||0)!==wakeGeneration){wakeGeneration=s.wakeGeneration||0;holding=false;old=0;direction=held=0;}
      const text=s.error||s.text||'';if(text!==lastText){lastText=text;void updateText(text);}
      if(s.state==='recording'){
        const amplitude=Math.min(1,Math.max(0,(s.rms||0)/6500));
        setLevels(v=>[...v.slice(1),3+amplitude*81]);
      }
    }
    if(frame%2===0&&(booting()||current()==='processing'))setPhase(p=>(p+1)%180);
  });
  function Label(p:{children:JSX.Element;size?:number;width?:number;color?:string;align?:number}){
    const size=p.size||30;
    return <Text style={{fontSlot:size===54?23:size===40?22:21,width:p.width||912,height:size+24,lineHeight:size+20,textColor:p.color||ink,textAlign:p.align||0}}>{p.children}</Text>;
  }
  function Key(p:{name:string;label:string;active?:boolean;width?:number}){
    return <View class="flex-row items-center gap-[14]">
      <View class="items-center justify-center h-[46] rounded-[23]" style={{width:p.width||46,bgColor:accent,opacity:p.active?.85:1}}>
        <Text style={{fontSlot:21,textColor:selected,textAlign:1,width:p.width||46,height:44,lineHeight:42}}>{p.name}</Text>
      </View>
      <Label width={p.name==='A'?190:p.name==='B'?100:64} color={muted}>{p.label}</Label>
    </View>;
  }
  return <View class="relative w-full h-full overflow-hidden" style={{bgColor:bg}}>
    <View class="absolute left-[56] top-[40] flex-row items-center gap-[18]">
      <View class="w-[30] h-[36] relative">
        <View class="absolute left-[9] top-[0] w-[12] h-[24] rounded-[6]" style={{bgColor:accent}} />
        <View class="absolute left-[3] top-[12] w-[24] h-[19] rounded-[10]" style={{borderWidth:2,borderColor:ink}} />
        <View class="absolute left-[6] top-[10] w-[18] h-[12]" style={{bgColor:bg}} />
        <View class="absolute left-[14] top-[30] w-[2] h-[6]" style={{bgColor:ink}} />
      </View>
      <Label size={40} width={320}>Brick Mic</Label>
    </View>
    <View class="absolute right-[56] top-[52] flex-row items-center justify-center gap-[12] h-[42] px-[18] rounded-[21]" style={{bgColor:soft}}>
      <View class="w-[8] h-[8] rounded-[4]" style={{bgColor:state().connected?accent:muted}} />
      <Text style={{fontSlot:21,textColor:ink,height:40,lineHeight:36}}>{state().connected?COPY.connected:current()==='bluetooth'||current()==='service'?COPY.starting:COPY.disconnected}</Text>
    </View>
    <View class="absolute left-[56] top-[119] w-[912] h-[1]" style={{bgColor:hairline}} />
    <View class="absolute left-[56] top-[178]"><Label size={54}>{COPY[current()]}</Label></View>
    <View class="absolute left-[56] top-[272]"><Label color={muted}>{subtitle()}</Label></View>
    <Show when={booting()}>
      <View class="absolute left-[56] top-[365] w-[912] h-[5] rounded-[3] overflow-hidden" style={{bgColor:hairline}}>
        <View class="absolute left-[0] top-[0] w-[144] h-[5] rounded-[3]" style={{bgColor:accent,translateX:phase()/180*1056-144}} />
      </View>
      <View class="absolute left-[56] top-[414] flex-col gap-[14]">
        <For each={COPY.steps}>{(name,i)=><View class="flex-row items-center gap-[18] h-[48]">
          <View class="w-[10] h-[10] rounded-[5]" style={{bgColor:i()<=stepIndex(state())?accent:hairline,opacity:i()===stepIndex(state())?.45+.55*Math.sin(phase()/180*Math.PI)**2:1}} />
          <Label color={i()===stepIndex(state())?ink:muted}>{name}</Label>
        </View>}</For>
      </View>
    </Show>
    <Show when={!booting()&&current()!=='result'&&current()!=='error'&&current()!=='poweroff'}>
      <View class="absolute left-[56] top-[365] w-[912] h-[106] flex-row justify-between items-center">
        <For each={Array.from({length:28},(_,i)=>i)}>{i=><View class="w-[9] rounded-[5]" style={{height:current()==='recording'?levels()[i]:3,bgColor:current()==='recording'?accent:hairline}} />}</For>
      </View>
      <View class="absolute left-[56] top-[514] flex-row items-center gap-[24]">
        <Show when={current()==='recording'}><Label size={40} width={180}>{clock(state().seconds)}</Label></Show>
        <Show when={current()==='processing'}><For each={[0,1,2]}>{i=><View class="w-[8] h-[8] rounded-[4]" style={{bgColor:accent,opacity:(phase()%27)>i*9?.85:.25}} />}</For></Show>
        <Label color={muted}>{current()==='recording'?COPY.limit:current()==='processing'?COPY.processingHint:COPY.empty}</Label>
      </View>
    </Show>
    <Show when={current()==='result'||current()==='error'}>
      <View class="absolute left-[56] top-[348] w-[912] h-[256] overflow-hidden flex-col">
        <For each={lines().slice(row(),row()+4)}>{line=><Text style={{fontSlot:20,textColor:ink,width:912,height:60,lineHeight:60}}>{line}</Text>}</For>
      </View>
      <Show when={lines().length>4}>
        <View class="absolute left-[56] top-[616]"><Label color={muted}>{COPY.read} · {row()+1}—{Math.min(row()+4,lines().length)} / {lines().length}</Label></View>
      </Show>
    </Show>
    <View class="absolute left-[56] top-[679] w-[912] h-[1]" style={{bgColor:hairline}} />
    <View class="absolute left-[56] top-[702] flex-row items-center"><Key name="A" label={current()==='error'&&!state().connected?COPY.retry:COPY.footer[0]} active={current()==='recording'} /></View>
    <View class="absolute left-[408] top-[702]"><Key name="B" label={booting()?COPY.footer[2]:COPY.footer[1]} /></View>
    <View class="absolute right-[56] top-[702]"><Key name="MENU" label={COPY.footer[2]} width={108} /></View>
  </View>;
}
mount(App);
