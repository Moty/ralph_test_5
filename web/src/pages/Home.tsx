import { Card, Button, SectionHeader } from '../components/ui';

export default function Home() {
  return (
    <div className="container">
      <h1>NutritionAI</h1>
      
      <SectionHeader>Today's Stats</SectionHeader>
      <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
        <Card gradient={1}>
          <h3>Calories</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0</p>
        </Card>
        <Card gradient={2}>
          <h3>Protein</h3>
          <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>0g</p>
        </Card>
      </div>

      <SectionHeader>Quick Actions</SectionHeader>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--spacing-md)' }}>
        <Button variant="primary" fullWidth>Capture Meal</Button>
        <Button variant="secondary" fullWidth>View History</Button>
      </div>
    </div>
  );
}
