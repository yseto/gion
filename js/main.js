/* vim:set ts=2 sts=2 sw=2:*/
import Vue from 'vue'
import Vuex from 'vuex'
import VueRouter from 'vue-router'
Vue.use(VueRouter)
Vue.use(Vuex)

import parse from 'date-fns/parse'
import format from 'date-fns/format'
import fromUnixTime from 'date-fns/fromUnixTime'

import _agent from './components/UserAgent.js'
import TokenStore from './components/TokenStore.js'
import GionHeader from './components/Header.vue'

import Home from './Home.vue'
import Login from './Login.vue'
import Logout from './Logout.vue'

import PinList from './PinList.vue'
import addSubscription from './addSubscription.vue'
import Reader from './Reader.vue'
import Settings from './Settings.vue'
import manageSubscription from './manageSubscription.vue'
import NotFound from './NotFound.vue'

Vue.config.productionTip = false
Vue.filter('localtime', function (mysqlDT) {
  return format(
    parse(`${mysqlDT} Z`, 'yyyy-MM-dd HH:mm:ss X', (new Date())),
    'yyyy-MM-dd HH:mm'
  );
});

Vue.filter('epochToDateTime', function (epoch) {
  return format(fromUnixTime(epoch), 'MM/dd HH:mm');
});

const router = new VueRouter({
//mode: 'history',
  routes: [
    { path: '/', component: Home, meta: { requiresAuth: true }, },
    { path: '/pin', component: PinList, meta: { requiresAuth: true }, },
    { path: '/add', component: addSubscription, meta: { requiresAuth: true }, },
    { path: '/entry', component: Reader, meta: { requiresAuth: true },},
    { path: '/settings', component: Settings, meta: { requiresAuth: true }, },
    { path: '/subscription', component: manageSubscription, meta: { requiresAuth: true }, },

    { path: '/login', component: Login, meta: { anonymous: true } },
    { path: '/logout', component: Logout, meta: {anonymous: true } },
    { path: '*', component: NotFound, meta: { anonymous: true } },
  ]
})


Vue.directive('focus', {
  inserted: function (el) {
    el.focus();
  }
});

router.beforeEach((to, from, next) => {
  if (to.matched.some(record => record.meta.requiresAuth) && !TokenStore.getters.isLogin) {
    next({ path: '/login', query: { redirect: to.fullPath }});
  } else {
    next();
  }
});

new Vue({
  components: {
    GionHeader,
  },
  data: {
    error: false,
  },
  methods: {
    returntop: function() {
      window.scrollTo(0, 0);
    },
    agent: function(args, then) {
      return _agent(args, then, TokenStore);
    },
  },
  router,
}).$mount('#app')
