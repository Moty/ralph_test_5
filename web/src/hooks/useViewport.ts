import { useState, useEffect } from 'react';

export type Viewport = 'mobile' | 'tablet' | 'desktop' | 'large';

const BREAKPOINTS = {
  tablet: 768,
  desktop: 1024,
  large: 1440,
};

function getViewport(width: number): Viewport {
  if (width >= BREAKPOINTS.large) return 'large';
  if (width >= BREAKPOINTS.desktop) return 'desktop';
  if (width >= BREAKPOINTS.tablet) return 'tablet';
  return 'mobile';
}

export function useViewport() {
  const [viewport, setViewport] = useState<Viewport>(() =>
    typeof window !== 'undefined' ? getViewport(window.innerWidth) : 'mobile'
  );
  const [width, setWidth] = useState(() =>
    typeof window !== 'undefined' ? window.innerWidth : 375
  );

  useEffect(() => {
    const handleResize = () => {
      const newWidth = window.innerWidth;
      setWidth(newWidth);
      setViewport(getViewport(newWidth));
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return {
    viewport,
    width,
    isMobile: viewport === 'mobile',
    isTablet: viewport === 'tablet',
    isDesktop: viewport === 'desktop' || viewport === 'large',
    isLarge: viewport === 'large',
    isAtLeastTablet: viewport !== 'mobile',
    isAtLeastDesktop: viewport === 'desktop' || viewport === 'large',
  };
}
