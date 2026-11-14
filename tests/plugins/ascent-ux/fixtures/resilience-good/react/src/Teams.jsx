import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';

export default function Teams() {
  const [params, setParams] = useSearchParams();
  const division = params.get('division') ?? 'all';
  const [notice, setNotice] = useState('');
  const qc = useQueryClient();
  const teams = useQuery({
    queryKey: ['teams', division],
    queryFn: () => fetch(`/api/teams?division=${division}`).then((r) => { if (!r.ok) throw new Error('teams'); return r.json(); }),
  });
  const rename = useMutation({
    mutationFn: ({ id, name }) => fetch(`/api/teams/${id}`, { method: 'PATCH', body: JSON.stringify({ name }) }),
    onMutate: async ({ id, name }) => {
      const previous = qc.getQueryData(['teams', division]);
      qc.setQueryData(['teams', division], (old) => old.map((t) => (t.id === id ? { ...t, name } : t)));
      return { previous };
    },
    onError: (err, vars, ctx) => {
      qc.setQueryData(['teams', division], ctx.previous);
      setNotice('The new name was not saved.');
    },
  });
  if (teams.isError) return <p role="alert">Teams did not load. <button onClick={() => teams.refetch()}>Try again</button></p>;
  return (
    <section>
      <select value={division} onChange={(e) => setParams({ division: e.target.value })}>
        <option value="all">All divisions</option>
        <option value="north">North</option>
      </select>
      {notice && <p role="status">{notice}</p>}
      <ul>{(teams.data ?? []).map((t) => <li key={t.id}><button onClick={() => rename.mutate({ id: t.id, name: t.name + ' FC' })}>{t.name}</button></li>)}</ul>
    </section>
  );
}
