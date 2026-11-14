import { createRouter, createWebHistory } from 'vue-router'
import Home from '../App.vue'

const routes = [
  { path: '/', component: Home },
  { path: '/about', component: Home },
  { path: '/scores/:id', component: Home, children: [{ path: 'edit', component: Home }] },
  { path: '/:pathMatch(.*)*', component: Home },
]

export default createRouter({ history: createWebHistory(), routes })
