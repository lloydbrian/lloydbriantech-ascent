<script setup>
import { ref, watch } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const scores = ref([]);
const error = ref('');
const busy = ref(false);
const court = ref('');
const consent = ref(false);
const updates = ref(false);

async function load() {
  error.value = '';
  try {
    const res = await fetch(`/api/scores?court=${route.query.court ?? ''}`);
    if (res.status >= 400) { error.value = 'Scores did not load.'; return; }
    if (res.status === 204) return;
    scores.value = await res.json();
  } catch (e) {
    error.value = 'Scores did not load.';
  }
}
watch(() => route.query.court, load, { immediate: true });

async function add() {
  busy.value = true;
  try {
    await fetch('/api/scores', { method: 'POST', body: JSON.stringify({ court: court.value, share: consent.value }) });
    await load();
  } catch (e) {
    error.value = 'The score was not saved.';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <form @submit.prevent="add">
    <label>Court <input v-model="court" name="court"></label>
    <label><input type="checkbox" name="consent" v-model="consent"> Share my scores with partner leagues</label>
    <label><input type="checkbox" v-model="updates"> Send me league offers</label>
    <button :disabled="busy">Add</button>
  </form>
  <p v-if="error" role="alert">{{ error }} <button @click="load">Retry</button></p>
  <ul><li v-for="s in scores" :key="s.id">{{ s.court }}: {{ s.score }}</li></ul>
</template>
