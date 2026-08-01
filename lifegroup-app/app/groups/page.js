'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { supabase } from '../../lib/supabase';

function shuffle(array) {
  const a = [...array];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Split n people into groups of 4–5 (ideally 5). When n makes that
// impossible (e.g. 6), pick the split closest to the 4–5 range,
// preferring more groups of 5 on ties.
function bestGroupSizes(n) {
  let best = null;
  for (let g = 1; g <= n; g++) {
    const base = Math.floor(n / g);
    const extra = n % g;
    const sizes = Array.from({ length: g }, (_, i) =>
      i < extra ? base + 1 : base
    );
    const penalty = sizes.reduce(
      (sum, s) => sum + (s < 4 ? 4 - s : s > 5 ? s - 5 : 0),
      0
    );
    const fives = sizes.filter((s) => s === 5).length;
    if (
      !best ||
      penalty < best.penalty ||
      (penalty === best.penalty && fives > best.fives)
    ) {
      best = { sizes, penalty, fives };
    }
  }
  return best.sizes;
}

export default function GroupsPage() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
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

  async function createGroups() {
    if (members.length === 0) return;
    setCreating(true);
    setError('');

    const shuffled = shuffle(members);
    const sizes = bestGroupSizes(shuffled.length);
    const updates = [];
    let cursor = 0;
    sizes.forEach((size, groupIndex) => {
      for (let i = 0; i < size; i++) {
        updates.push({ id: shuffled[cursor].id, group_number: groupIndex + 1 });
        cursor++;
      }
    });

    const results = await Promise.all(
      updates.map((u) =>
        supabase
          .from('lifegroup_members')
          .update({ group_number: u.group_number })
          .eq('id', u.id)
      )
    );
    setCreating(false);
    if (results.some((r) => r.error)) {
      setError('Some assignments failed to save. Please try again.');
      return;
    }
    load();
  }

  const grouped = members.reduce((acc, m) => {
    if (!m.group_number) return acc;
    (acc[m.group_number] = acc[m.group_number] || []).push(m);
    return acc;
  }, {});
  const groupNumbers = Object.keys(grouped)
    .map(Number)
    .sort((a, b) => a - b);
  const unassigned = members.filter((m) => !m.group_number);

  return (
    <main className="container">
      <p className="eyebrow">Admin</p>
      <h1>Create Life Groups</h1>
      <p className="subtitle">
        Randomly place everyone who signed up into life groups of 4–5 members.
        Pressing the button again reshuffles everyone into new groups.
      </p>

      <div className="nav-links no-print">
        <Link href="/">Sign-Up Form</Link>
        <Link href="/admin">Submissions</Link>
        <Link href="/qr">QR Code</Link>
      </div>

      {error && <p className="error-msg">{error}</p>}

      <div className="actions-row no-print">
        <button
          className="btn"
          onClick={createGroups}
          disabled={creating || loading || members.length === 0}
        >
          {creating
            ? 'Creating groups…'
            : groupNumbers.length > 0
              ? '🔀 Reshuffle Life Groups'
              : '✨ Create Life Groups'}
        </button>
        {groupNumbers.length > 0 && (
          <button className="btn btn-secondary" onClick={() => window.print()}>
            🖨 Print Groups
          </button>
        )}
      </div>

      {loading ? (
        <p className="empty-state">Loading…</p>
      ) : members.length === 0 ? (
        <p className="empty-state">
          No one has signed up yet. Share the QR code first!
        </p>
      ) : groupNumbers.length === 0 ? (
        <p className="empty-state">
          {members.length} {members.length === 1 ? 'person is' : 'people are'}{' '}
          ready to be grouped. Press the button above!
        </p>
      ) : (
        <>
          <div className="groups-grid">
            {groupNumbers.map((n) => (
              <div className="group-card" key={n}>
                <h3>Life Group {n}</h3>
                <p className="size">
                  {grouped[n].length}{' '}
                  {grouped[n].length === 1 ? 'member' : 'members'}
                </p>
                <ul>
                  {grouped[n].map((m) => (
                    <li key={m.id}>
                      {m.first_name} {m.last_name}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
          {unassigned.length > 0 && (
            <p className="subtitle" style={{ marginTop: 20 }}>
              ⚠️ {unassigned.length}{' '}
              {unassigned.length === 1 ? 'person' : 'people'} signed up after
              groups were made. Press reshuffle to include them.
            </p>
          )}
        </>
      )}
    </main>
  );
}
