import './Input.css';

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  // Additional custom props can be added here
}

export const Input: React.FC<InputProps> = ({ className = '', ...props }) => {
  return (
    <input
      className={`input ${className}`}
      {...props}
    />
  );
};
