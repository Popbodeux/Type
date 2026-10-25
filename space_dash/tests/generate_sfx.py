from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parent.parent/'assets/audio'
rate=22050
specs={'typing':(.032,520,440),'ready':(.145,660,880),'dash':(.15,240,95),'hit':(.115,180,75),'block':(.095,390,250),'mistake':(.13,250,170),'collect':(.18,520,1040),'gameover':(.5,440,165)}
for number,(name,(duration,f0,f1)) in enumerate(specs.items()):
 rng=random.Random(4800+number)
 count=int(rate*duration)
 samples=[]
 phase=0.0
 noise=0.0
 for i in range(count):
  t=i/max(1,count-1)
  phase+=2*math.pi*(f0+(f1-f0)*t)/rate
  envelope=math.sin(math.pi*t)**1.2 * math.exp(-2.3*t)
  tone=math.sin(phase)+.18*math.sin(phase*2)
  noise=noise*.78+rng.uniform(-1,1)*.22
  if name=='dash': tone=noise*2.5+math.sin(phase)*.14
  elif name=='hit': tone=tone*.75+noise*.5
  elif name=='block': tone=math.sin(phase)+.25*math.sin(phase*1.5)
  elif name in ['ready','collect']: tone=math.sin(phase)+.28*math.sin(phase*1.5)
  samples.append(tone*envelope)
 peak=max(abs(v) for v in samples)
 pcm=b''.join(struct.pack('<h',round(v/peak*.62*32767)) for v in samples)
 with wave.open(str(root/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm)
 print(name,len(pcm),'PCM bytes')
