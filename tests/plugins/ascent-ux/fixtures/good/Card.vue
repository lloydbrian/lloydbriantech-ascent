<template>
  <article>
    <h2>{{ title }}</h2>
    <img :src="src" :alt="title">
    <input v-model="q" :aria-label="t('search')">
    <button @click="open">{{ t('open') }}</button>
    <span role="button" tabindex="0" @click="open" @keydown.enter="open">Open</span>
  </article>
</template>
