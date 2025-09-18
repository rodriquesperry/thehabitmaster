'use client';

import { useEffect, useState } from 'react';
import { createClient } from '../lib/supabaseClient';
import { Auth } from '@supabase/auth-ui-react';
import { ThemeSupa } from '@supabase/auth-ui-shared';
import Link from 'next/link';

type Habit = {
  id: string;
  title: string;
  target_per_week: number;
};

function Pomodoro({ focusMin=25, breakMin=5, onCycle }: { focusMin?:number; breakMin?:number; onCycle?:(mode:'focus'|'break')=>void }) {
  const [mode, setMode] = useState<'focus'|'break'>('focus');
  const [sec, setSec] = useState(focusMin * 60);
  const [running, setRunning] = useState(false);

  useEffect(() => {
    if (!running) return;
    const t = setInterval(() => setSec(s => (s>0 ? s-1 : 0)), 1000);
    return () => clearInterval(t);
  }, [running]);

  useEffect(() => {
    if (sec === 0) {
      const next = mode === 'focus' ? 'break' : 'focus';
      setMode(next);
      setSec(next === 'focus' ? focusMin*60 : breakMin*60);
      onCycle?.(next);
    }
  }, [sec, mode, focusMin, breakMin, onCycle]);

  const mm = String(Math.floor(sec/60)).padStart(2,'0');
  const ss = String(sec%60).padStart(2,'0');

  return (
    <div style={{ border:'1px solid #222', padding:16, borderRadius:12, background:'#111' }}>
      <h3 style={{ marginTop:0 }}>{mode.toUpperCase()}</h3>
      <div style={{ fontSize:48, fontWeight:700, letterSpacing:1, margin:'12px 0' }}>{mm}:{ss}</div>
      <div style={{ display:'flex', gap:8 }}>
        <button onClick={()=>setRunning(r=>!r)} style={{ padding:'8px 12px', borderRadius:8, border:'1px solid #333', background:'#1a1a1a', color:'#fff' }}>{running ? 'Pause' : 'Start'}</button>
        <button onClick={()=>setSec(s=>s+60)} style={{ padding:'8px 12px', borderRadius:8, border:'1px solid #333', background:'#1a1a1a', color:'#fff' }}>+1 min</button>
        <button onClick={()=>setSec(0)} style={{ padding:'8px 12px', borderRadius:8, border:'1px solid #333', background:'#1a1a1a', color:'#fff' }}>Skip</button>
        <button onClick={()=>{ setMode('focus'); setSec(focusMin*60); setRunning(false); }} style={{ padding:'8px 12px', borderRadius:8, border:'1px solid #333', background:'#1a1a1a', color:'#fff' }}>Reset</button>
      </div>
    </div>
  );
}

export default function Page() {
  const supabase = createClient();
  const [session, setSession] = useState<any>(null);
  const [habits, setHabits] = useState<Habit[]>([]);
  const [selectedHabit, setSelectedHabit] = useState<string>('');
  const [note, setNote] = useState('');

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => { sub.subscription.unsubscribe(); };
  }, []);

  useEffect(() => {
    if (!session) return;
    (async () => {
      const { data, error } = await supabase.from('habits').select('id, title, target_per_week').order('created_at', { ascending: true });
      if (!error && data) setHabits(data);
    })();
  }, [session]);

  async function startSession() {
    if (!selectedHabit) return alert('Pick a habit');
    const { data, error } = await supabase.from('sessions').insert({
      habit_id: selectedHabit,
      user_id: session.user.id,
      planned_duration_min: 25,
      notes: 'Started from web'
    }).select('id').single();
    if (error) alert(error.message);
    else console.log('Session started', data.id);
  }

  async function completeSession() {
    const { data: latest } = await supabase
      .from('sessions')
      .select('id')
      .eq('user_id', session.user.id)
      .eq('habit_id', selectedHabit)
      .order('started_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!latest) return alert('No session to complete.');
    const { error } = await supabase.from('sessions').update({
      completed: true,
      actual_duration_min: 25,
      notes: note || null
    }).eq('id', latest.id);
    if (error) alert(error.message);
    else { setNote(''); alert('Session completed 🎉'); }
  }

  if (!session) {
    return (
      <div>
        <h1>Atomic Habits + Pomodoro</h1>
        <p>Sign in to start building tiny wins.</p>
        <Auth supabaseClient={supabase} appearance={{ theme: ThemeSupa }} providers={[]} view="sign_in" />
        <p style={{ opacity:.8, marginTop:8 }}>Tip: Enable email OTP or magic link in Supabase Auth.</p>
      </div>
    );
  }

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center' }}>
        <h1>Welcome</h1>
        <button onClick={()=>supabase.auth.signOut()} style={{ padding:'8px 12px', borderRadius:8, border:'1px solid #333', background:'#1a1a1a', color:'#fff' }}>Sign out</button>
      </div>

      <h2 style={{ marginTop:0 }}>Pick a Habit</h2>
      <select value={selectedHabit} onChange={e=>setSelectedHabit(e.target.value)} style={{ padding:8, borderRadius:8, background:'#111', color:'#fff', border:'1px solid #333' }}>
        <option value="">-- select --</option>
        {habits.map(h => <option key={h.id} value={h.id}>{h.title}</option>)}
      </select>

      <div style={{ marginTop:16, display:'grid', gap:16 }}>
        <Pomodoro onCycle={(m)=>console.log('Cycle ->', m)} />
        <div style={{ display:'flex', gap:8 }}>
          <button onClick={startSession} style={{ padding:'10px 14px', borderRadius:8, border:'1px solid #2a2a2a', background:'#151515', color:'#fff' }}>Start Session</button>
          <button onClick={completeSession} style={{ padding:'10px 14px', borderRadius:8, border:'1px solid #2a2a2a', background:'#151515', color:'#fff' }}>Complete Session</button>
        </div>
        <textarea placeholder="Optional note..." value={note} onChange={e=>setNote(e.target.value)} rows={3} style={{ width:'100%', padding:10, borderRadius:8, background:'#101010', color:'#fff', border:'1px solid #333' }} />
        <p style={{ opacity:.8 }}>New account? Run the seed function to create 5 sample habits (see README).</p>
        <p><Link href="/stats">View Stats</Link></p>
      </div>
    </div>
  );
}
