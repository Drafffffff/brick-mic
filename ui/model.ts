export interface MicState {
  state:string; connected?:boolean; session?:number; seconds?:number;
  rms?:number; text?:string; error?:string;
  wakeGeneration?:number;
  fastWake?:boolean;
}
export const COPY={
  bluetooth:'正在打开蓝牙', service:'正在准备语音服务', waiting:'等待 Mac 连接',
  ready:'按住 A，说完松开', recording:'正在听你说话', processing:'正在识别',
  result:'识别完成', error:'暂时无法连接',
  poweroff:'正在关机',poweroffHint:'下次开机会回到 Brick Mic',
  bootHint:'准备好后会自动连接 Mac',waitingHint:'在 Mac 打开 Brick Mic，保持蓝牙开启',
  readyHint:'对着掌机麦克风说话，文字会同步到 Mac',recordHint:'松开 A 结束 · B 取消本次录音',
  processingHint:'录音已结束，正在等待最终文字',resultHint:'文字已同步到 Mac · 按住 A 继续说话',
  errorHint:'按 A 重试 · MENU 返回',fontError:'字体加载失败，请重新安装完整应用包',
  steps:['打开蓝牙','准备语音服务','连接 Mac'],
  connected:'已连接 Mac',starting:'正在启动',disconnected:'尚未连接',
  retry:'重新连接',footer:['按住说话','取消','返回'],limit:'最长录音 60 秒',read:'上下阅读',
  realtime:'蓝牙语音输入',empty:'说话后，识别文字会显示在这里',
};
export function mode(s:MicState):keyof Pick<typeof COPY,'bluetooth'|'service'|'waiting'|'ready'|'recording'|'processing'|'result'|'error'|'poweroff'> {
  if(s.state==='poweroff')return 'poweroff';
  if(s.state==='error'||s.error)return 'error';
  if(s.state==='bluetooth'||s.state==='service')return s.state;
  if(!s.connected)return 'waiting';
  if(s.state==='recording'||s.state==='processing')return s.state;
  return s.text?'result':'ready';
}
export function clock(seconds=0){const n=Math.max(0,Math.floor(Number.isFinite(seconds)?seconds:0));return `${Math.floor(n/60).toString().padStart(2,'0')}:${(n%60).toString().padStart(2,'0')}`;}
export function mix(a:string,b:string,weight:number){
  const p=Math.min(1,Math.max(0,weight));
  return '#'+[1,3,5].map(i=>Math.round(parseInt(a.slice(i,i+2),16)*(1-p)+parseInt(b.slice(i,i+2),16)*p).toString(16).padStart(2,'0')).join('');
}
export function stepIndex(s:MicState){const m=mode(s);return m==='bluetooth'?0:m==='service'?1:2;}
export function scrollRow(row:number,delta:number,count:number){return Math.max(0,Math.min(Math.max(0,count-4),row+delta));}
