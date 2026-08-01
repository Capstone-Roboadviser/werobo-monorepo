import { createClient } from '@supabase/supabase-js';

// The publishable key is safe to expose in client code; access is
// controlled by row level security policies on the database.
const SUPABASE_URL = 'https://okmpqlajjudnxklfcjml.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_9zD-7O23KcxjbKAsDbQ-5w_VtPeXaub';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
