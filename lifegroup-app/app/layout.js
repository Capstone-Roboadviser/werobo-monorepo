import './globals.css';

export const metadata = {
  title: 'Life Group Sign-Up',
  description: 'Sign up to be placed in a life group',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
