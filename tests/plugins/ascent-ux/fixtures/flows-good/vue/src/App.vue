<template>
  <nav>
    <router-link to="/about">About</router-link>
    <RouterLink :to="'/scores/4'">Score 4</RouterLink>
    <router-link :to="{ name: 'home' }">Home</router-link>
    <router-link to="/scores/4/edit">Edit score 4</router-link>
  </nav>
  <button aria-controls="panel" @click="open = !open">Details</button>
  <div id="panel" v-if="open">Details</div>
</template>

<script setup>
import { ref } from 'vue'
const open = ref(false)
</script>
