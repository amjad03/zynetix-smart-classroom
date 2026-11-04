import '@zynetix/web-ui/src/styles.css';
import '../lib/outcomes.css';
export const metadata = { title: 'Zynetix College Admin' };
export default function Root({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
