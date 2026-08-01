'use client';

import { useState } from 'react';
import { supabase } from '../lib/supabase';

export default function SignUpPage() {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    const first = firstName.trim();
    const last = lastName.trim();
    if (!first || !last) {
      setError('Please enter both your first and last name.');
      return;
    }
    setSubmitting(true);
    setError('');
    const { error: insertError } = await supabase
      .from('lifegroup_members')
      .insert({ first_name: first, last_name: last });
    setSubmitting(false);
    if (insertError) {
      setError('Something went wrong. Please try again.');
      return;
    }
    setDone(true);
  }

  return (
    <main className="container narrow">
      <p className="eyebrow">Life Groups</p>
      <h1>Join a Life Group</h1>
      <p className="subtitle">
        Enter your name below and you&apos;ll be randomly placed into a life
        group of 4–5 members.
      </p>

      <div className="card">
        {done ? (
          <div className="success">
            <div className="check">🎉</div>
            <h2>You&apos;re in!</h2>
            <p>
              Thanks, {firstName.trim()}! Your name has been submitted.
              Group assignments will be announced soon.
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit}>
            <label htmlFor="first">First Name</label>
            <input
              id="first"
              type="text"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              placeholder="e.g. Eugene"
              autoComplete="given-name"
            />
            <label htmlFor="last">Last Name</label>
            <input
              id="last"
              type="text"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              placeholder="e.g. Hong"
              autoComplete="family-name"
            />
            {error && <p className="error-msg">{error}</p>}
            <button className="btn" type="submit" disabled={submitting}>
              {submitting ? 'Submitting…' : 'Submit My Name'}
            </button>
          </form>
        )}
      </div>
    </main>
  );
}
