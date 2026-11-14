<script>
  import { goto } from '$app/navigation';
</script>

<h1>Scores</h1>
<a href="https://example.org/league">League site</a>
<a href="/scores/7">Score 7</a>
<button on:click={() => goto('/scores/8')}>Score 8</button>
<label for="q">Search</label><input id="q" aria-describedby="q-hint"><span id="q-hint">Team name</span>
