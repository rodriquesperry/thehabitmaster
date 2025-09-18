export const metadata = { title: 'Habit Starter', description: 'Atomic Habits + Pomodoro' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Helvetica Neue, Arial, sans-serif', background:'#0b0c0f', color:'#e6e6e6', margin:0 }}>
        <div style={{ maxWidth: 860, margin: '0 auto', padding: 24 }}>{children}</div>
      </body>
    </html>
  );
}
