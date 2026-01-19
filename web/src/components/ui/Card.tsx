import type { ReactNode } from 'react';
import './Card.css';

interface CardProps {
  children: ReactNode;
  gradient?: 1 | 2 | 3 | 4;
  className?: string;
}

export function Card({ children, gradient, className = '' }: CardProps) {
  const gradientClass = gradient ? `gradient-card-${gradient}` : '';
  
  return (
    <div className={`card ${gradientClass} ${className}`.trim()}>
      {children}
    </div>
  );
}
