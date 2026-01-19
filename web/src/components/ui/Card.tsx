import type { ReactNode, CSSProperties } from 'react';
import './Card.css';

interface CardProps {
  children: ReactNode;
  gradient?: 1 | 2 | 3 | 4;
  className?: string;
  style?: CSSProperties;
}

export function Card({ children, gradient, className = '', style }: CardProps) {
  const gradientClass = gradient ? `gradient-card-${gradient}` : '';
  
  return (
    <div className={`card ${gradientClass} ${className}`.trim()} style={style}>
      {children}
    </div>
  );
}
