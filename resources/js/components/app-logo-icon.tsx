import { Ref, SVGAttributes } from 'react';

export default function AppLogoIcon(props: SVGAttributes<SVGElement> & { ref?: Ref<SVGSVGElement> }) {
  return (
    <svg {...props} viewBox="0 0 44 44" xmlns="http://www.w3.org/2000/svg">
      <rect x="1.5" y="1.5" width="41" height="41" rx="10" fill="#0A0E17" stroke="#F97316" strokeWidth="3" />
      <rect x="8" y="8" width="28" height="28" rx="6" fill="none" stroke="rgba(255,255,255,.75)" strokeWidth="2.5" />
      <circle cx="22" cy="22" r="3.5" fill="#F97316" />
    </svg>
  );
}
