import type { ReactNode, CSSProperties, MouseEvent } from 'react';
import './Card.css';

interface CardProps {
  children: ReactNode;
  gradient?: 1 | 2 | 3 | 4;
  className?: string;
  style?: CSSProperties;
  onClick?: (e: MouseEvent<HTMLDivElement>) => void;
}

export function Card({ children, gradient, className = '', style, onClick }: CardProps) {
  const gradientClass = gradient ? `gradient-card-${gradient}` : '';
  
  return (
    <div className={`card ${gradientClass} ${className}`.trim()} style={style} onClick={onClick}>
      {children}
    </div>
  );
}
