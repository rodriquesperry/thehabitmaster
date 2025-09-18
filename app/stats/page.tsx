'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabaseClient';

type Row = { habit_id: string; title: string; completion_rate_pct: number; completed_sessions: number; total_sessions: number; };

export default function StatsPage() {
  const supabase = createClient();
  const [rows, setRows] = useState<Row[]>([]);

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.from('v_habit_stats').select('*');
      if (!error && data) setRows(data as Row[]);
    })();
  }, []);

  return (
    <div>
      <h1>Stats</h1>
      <table style={{ width:'100%', borderCollapse:'collapse' }}>
        <thead>
          <tr>
            <th style={{ textAlign:'left', borderBottom:'1px solid #333', padding:'8px 4px' }}>Habit</th>
            <th style={{ textAlign:'right', borderBottom:'1px solid #333', padding:'8px 4px' }}>Completed</th>
            <th style={{ textAlign:'right', borderBottom:'1px solid #333', padding:'8px 4px' }}>Total</th>
            <th style={{ textAlign:'right', borderBottom:'1px solid #333', padding:'8px 4px' }}>Completion %</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(r => (
            <tr key={r.habit_id}>
              <td style={{ padding:'8px 4px', borderBottom:'1px solid #222' }}>{r.title}</td>
              <td style={{ padding:'8px 4px', textAlign:'right', borderBottom:'1px solid #222' }}>{r.completed_sessions}</td>
              <td style={{ padding:'8px 4px', textAlign:'right', borderBottom:'1px solid #222' }}>{r.total_sessions}</td>
              <td style={{ padding:'8px 4px', textAlign:'right', borderBottom:'1px solid #222' }}>{Math.round(r.completion_rate_pct)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
