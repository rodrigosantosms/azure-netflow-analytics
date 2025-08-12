import dynamic from 'next/dynamic';
import axios from 'axios';
import { useEffect, useMemo, useState } from 'react';

const ReactECharts = dynamic(() => import('echarts-for-react'), { ssr: false });

type HeatCell = { SrcVm: string; DstVm: string; Bytes: number };

export default function Home() {
  const [heat, setHeat] = useState<HeatCell[]>([]);
  const [bars, setBars] = useState<any[]>([]);
  const [theme, setTheme] = useState<'light'|'dark'>('dark');

  useEffect(() => {
    (async () => {
      const h = await axios.get('/api/heatmap?topSources=15&topDests=15');
      setHeat(h.data);
      const t = await axios.get('/api/top-talkers?top=20&window=PT1H');
      setBars(t.data);
    })();
  }, []);

  const sources = useMemo(() => Array.from(new Set(heat.map(x => x.SrcVm))), [heat]);
  const dests = useMemo(() => Array.from(new Set(heat.map(x => x.DstVm))), [heat]);
  const matrix = useMemo(() => {
    const idxS = new Map(sources.map((s,i)=>[s,i]));
    const idxD = new Map(dests.map((d,i)=>[d,i]));
    return heat.map(x => [idxS.get(x.SrcVm), idxD.get(x.DstVm), x.Bytes]);
  }, [heat, sources, dests]);

  const heatOpt = {
    tooltip: { position: 'top', formatter: (p:any)=>`${sources[p.data[0]]} → ${dests[p.data[1]]}<br/>${(p.data[2]/(1024*1024)).toFixed(2)} MB` },
    grid: { height: '70%', top: '10%' },
    xAxis: { type: 'category', data: sources, splitArea: { show: true } },
    yAxis: { type: 'category', data: dests, splitArea: { show: true } },
    visualMap: { min: 0, max: Math.max(...matrix.map(m => m[2] || 0), 1), calculable: true, orient: 'horizontal', left: 'center', bottom: 0 },
    series: [ { name: 'Bytes', type: 'heatmap', data: matrix, emphasis: { itemStyle: { shadowBlur: 10 } } } ]
  };

  const barOpt = {
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: bars.map((b:any)=>`${b.SrcVm}→${b.DstVm}:${b.DstPort}`) },
    yAxis: { type: 'value' },
    series: [{ type: 'bar', data: bars.map((b:any)=>b.Bytes) }]
  };

  return (
    <main style={{ padding: 24, background: theme==='dark'?'#0b0e11':'#fff', minHeight: '100vh', color: theme==='dark'?'#fff':'#111' }}>
      <header style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom: 16 }}>
        <h1>NetFlow Analytics</h1>
        <button onClick={()=>setTheme(theme==='dark'?'light':'dark')}>
          Toggle {theme==='dark'?'Light':'Dark'} Mode
        </button>
      </header>
      <section style={{ marginBottom: 24 }}>
        <h2>Top Talkers (Heatmap)</h2>
        <ReactECharts option={heatOpt as any} theme={theme} style={{ height: 500 }} />
      </section>
      <section>
        <h2>Top Talkers (Bar)</h2>
        <ReactECharts option={barOpt as any} theme={theme} style={{ height: 320 }} />
      </section>
    </main>
  );
}
