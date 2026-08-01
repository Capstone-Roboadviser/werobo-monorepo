'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { QRCodeCanvas } from 'qrcode.react';

export default function QrPage() {
  const [url, setUrl] = useState('');
  const boxRef = useRef(null);

  useEffect(() => {
    setUrl(window.location.origin + '/');
  }, []);

  function download() {
    const canvas = boxRef.current?.querySelector('canvas');
    if (!canvas) return;
    const link = document.createElement('a');
    link.download = 'lifegroup-signup-qr.png';
    link.href = canvas.toDataURL('image/png');
    link.click();
  }

  return (
    <main className="container narrow">
      <p className="eyebrow">Share</p>
      <h1>Sign-Up QR Code</h1>
      <p className="subtitle">
        Members can scan this code with their phone camera to open the
        sign-up form.
      </p>

      <div className="nav-links no-print">
        <Link href="/">Sign-Up Form</Link>
        <Link href="/admin">Submissions</Link>
        <Link href="/groups">Create Life Groups</Link>
      </div>

      <div className="card">
        <div className="qr-wrap">
          <div className="qr-box" ref={boxRef}>
            {url && (
              <QRCodeCanvas value={url} size={280} level="M" includeMargin />
            )}
          </div>
          <p className="qr-url">{url}</p>
          <div className="actions-row no-print" style={{ width: '100%' }}>
            <button className="btn" onClick={download}>
              ⬇️ Download PNG
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => window.print()}
            >
              🖨 Print
            </button>
          </div>
        </div>
      </div>
    </main>
  );
}
