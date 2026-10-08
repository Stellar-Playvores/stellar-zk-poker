import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Stellar ZK Poker",
  description: "Onchain Texas Hold'em with private cards via MPC + ZK proofs on Stellar",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
