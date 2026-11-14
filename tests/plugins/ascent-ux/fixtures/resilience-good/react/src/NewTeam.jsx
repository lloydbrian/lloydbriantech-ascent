import { useState } from 'react';
import axios from 'axios';

export default function NewTeam({ onCreated }) {
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const [problem, setProblem] = useState('');
  function handleSubmit(e) {
    e.preventDefault();
    setSaving(true);
    axios.post('/api/teams', { name })
      .then((res) => onCreated(res.data))
      .catch(() => setProblem('The team was not created.'))
      .finally(() => setSaving(false));
  }
  return (
    <form onSubmit={handleSubmit}>
      <label>Team name <input name="name" value={name} onChange={(e) => setName(e.target.value)} /></label>
      <label><input type="checkbox" name="newsletter" /> Email me the league newsletter</label>
      <button type="submit" disabled={saving}>Create</button>
      {problem && <p role="alert">{problem}</p>}
    </form>
  );
}
