'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';

export default function AdminPage() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error: fetchError } = await supabase
      .from('lifegroup_members')
      .select('*')
      .order('created_at', { ascending: true });
    setLoading(false);
    if (fetchError) {
      setError('Could not load submissions. Please refresh.');
      return;
    }
    setMembers(data ?? []);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function handleDelete(member) {
    const ok = window.confirm(
      `Remove ${member.first_name} ${member.last_name} from the list?`
    );
    if (!ok) return;
    const { error: deleteError } = await supabase
      .from('lifegroup_members')
      .delete()
      .eq('id', member.id);
    if (deleteError) {
      setError('Could not delete that entry. Please try again.');
      return;
    }
    setMembers((prev) => prev.filter((m) => m.id !== member.id));
  }

  return (
    <main className="container">
      <p className="eyebrow">Admin</p>
      <h1>Submissions</h1>
      <p className="subtitle">Everyone who has signed up so far.</p>

      <div className="nav-links">
        <Link href="/">Sign-Up Form</Link>
        <Link href="/groups">Create Life Groups</Link>
        <Link href="/qr">QR Code</Link>
      </div>

      <span className="count-badge">
        {members.length} {members.length === 1 ? 'person' : 'people'} signed up
      </span>

      {error && <p className="error-msg">{error}</p>}

      <div className="card">
        {loading ? (
          <p className="empty-state">Loading…</p>
        ) : members.length === 0 ? (
          <p className="empty-state">
            No submissions yet. Share the QR code to get people signed up!
          </p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Group</th>
                <th>Submitted</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {members.map((m, i) => (
                <tr key={m.id}>
                  <td>{i + 1}</td>
                  <td>{m.first_name}</td>
                  <td>{m.last_name}</td>
                  <td>{m.group_number ? `Group ${m.group_number}` : '—'}</td>
                  <td>{new Date(m.created_at).toLocaleString()}</td>
                  <td>
                    <button
                      className="delete-btn"
                      onClick={() => handleDelete(m)}
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </main>
  );
}
