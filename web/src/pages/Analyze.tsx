import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Button, Card, SectionHeader } from '../components/ui';
import { mealApi } from '../services/api';
import type { AnalysisResult, ApiError } from '../services/api';

export default function Analyze() {
  const location = useLocation();
  const navigate = useNavigate();
  const { imageFile, imagePreview } = location.state || {};
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<AnalysisResult | null>(null);

  const submitAnalysis = async () => {
    if (!imageFile) {
      setError('No image selected');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const selectedModel = localStorage.getItem('selectedModel') || undefined;
      const data = await mealApi.analyze(imageFile, selectedModel);
      setResult(data);
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.message || 'Failed to analyze image');
    } finally {
      setLoading(false);
    }
  };

  if (!imageFile) {
    return (
      <div className="container">
        <h1>Analyze</h1>
        <p>No image selected</p>
        <Button variant="secondary" onClick={() => navigate('/camera')}>
          ← Back to Camera
        </Button>
      </div>
    );
  }

  if (result) {
    return (
      <div className="container">
        <h1>Analysis Results</h1>
        
        {imagePreview && (
          <img 
            src={imagePreview} 
            alt="Analyzed meal" 
            style={{ 
              width: '100%', 
              maxHeight: '30vh', 
              objectFit: 'contain',
              borderRadius: 'var(--border-radius-md)',
              marginBottom: 'var(--spacing-lg)'
            }} 
          />
        )}

        <SectionHeader>Totals</SectionHeader>
        <div style={{ display: 'grid', gap: 'var(--spacing-md)', marginBottom: 'var(--spacing-xl)' }}>
          <Card gradient={1}>
            <h3>Calories</h3>
            <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(result.totals.calories)}</p>
          </Card>
          <Card gradient={2}>
            <h3>Protein</h3>
            <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(result.totals.protein)}g</p>
          </Card>
          <Card gradient={3}>
            <h3>Carbs</h3>
            <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(result.totals.carbs)}g</p>
          </Card>
          <Card gradient={4}>
            <h3>Fat</h3>
            <p style={{ fontSize: 'var(--font-size-3xl)', margin: 0 }}>{Math.round(result.totals.fat)}g</p>
          </Card>
        </div>

        <SectionHeader>Items</SectionHeader>
        {result.items.map((item, idx) => (
          <Card key={idx} style={{ marginBottom: 'var(--spacing-md)', padding: 'var(--spacing-md)' }}>
            <h3 style={{ marginTop: 0, marginBottom: 'var(--spacing-sm)' }}>{item.name}</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--spacing-sm)', fontSize: 'var(--font-size-sm)' }}>
              <div>
                <div style={{ opacity: 0.6 }}>Cal</div>
                <div style={{ fontWeight: 600 }}>{Math.round(item.calories)}</div>
              </div>
              <div>
                <div style={{ opacity: 0.6 }}>Protein</div>
                <div style={{ fontWeight: 600 }}>{Math.round(item.protein)}g</div>
              </div>
              <div>
                <div style={{ opacity: 0.6 }}>Carbs</div>
                <div style={{ fontWeight: 600 }}>{Math.round(item.carbs)}g</div>
              </div>
              <div>
                <div style={{ opacity: 0.6 }}>Fat</div>
                <div style={{ fontWeight: 600 }}>{Math.round(item.fat)}g</div>
              </div>
            </div>
          </Card>
        ))}

        <div style={{ display: 'flex', gap: 'var(--spacing-md)', marginTop: 'var(--spacing-xl)' }}>
          <Button variant="secondary" fullWidth onClick={() => navigate('/')}>
            ← Home
          </Button>
          <Button variant="primary" fullWidth onClick={() => navigate('/history')}>
            History →
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Analyze Meal</h1>
      
      {imagePreview && (
        <img 
          src={imagePreview} 
          alt="Meal to analyze" 
          style={{ 
            width: '100%', 
            maxHeight: '50vh', 
            objectFit: 'contain',
            borderRadius: 'var(--border-radius-md)',
            marginBottom: 'var(--spacing-lg)'
          }} 
        />
      )}

      {error && (
        <Card style={{ marginBottom: 'var(--spacing-lg)', padding: 'var(--spacing-lg)', backgroundColor: 'var(--color-error)', color: 'white' }}>
          <p style={{ margin: 0 }}>{error}</p>
        </Card>
      )}

      {loading ? (
        <div style={{ textAlign: 'center', padding: 'var(--spacing-xl)', opacity: 0.6 }}>
          Analyzing your meal...
        </div>
      ) : (
        <div style={{ display: 'flex', gap: 'var(--spacing-md)' }}>
          <Button variant="secondary" fullWidth onClick={() => navigate('/camera')}>
            ← Back
          </Button>
          <Button variant="primary" fullWidth onClick={submitAnalysis}>
            Analyze 🔍
          </Button>
        </div>
      )}
    </div>
  );
}
