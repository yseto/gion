/* vim:set ts=2 sts=2 sw=2:*/
import Vue from 'vue'
import moment from 'moment';

import Home from './Home.vue'
import PinList from './PinList.vue'
import addSubscription from './addSubscription.vue'
import Reader from './Reader.vue'
import Settings from './Settings.vue'
import manageSubscription from './manageSubscription.vue'
import NotFound from './NotFound.vue'

Vue.config.productionTip = false
Vue.filter('localtime', function (mysql_dt) {
  return moment.utc(mysql_dt, 'YYYY-MM-DD HH:mm:ss').local().format('YYYY-MM-DD HH:mm');
});
Vue.filter('epochToDateTime', function (epoch) {
  return moment.unix(epoch).format('MM/DD HH:mm');
});

// ref https://jp.vuejs.org/v2/guide/routing.html
new Vue({
  data: {
    currentRoute: window.location.hash,
    helpModal: false,
    error: false,
    navbarState: false
  },
  computed: {
    ViewComponent: function() {
      const routes = {
        '': Home,
        '#pin': PinList,
        '#add': addSubscription,
        '#entry': Reader,
        '#settings': Settings,
        '#subscription': manageSubscription,
      };
      return routes[this.currentRoute] || NotFound;
    },
  },
  methods: {
    go: function(value) {
      window.location.hash = value;
      this.currentRoute = value;
      this.navbarState = false;
    },
    returntop: function() {
      window.scrollTo(0, 0);
    },
    navbar: function() {
      this.navbarState = this.navbarState ? false : true;
    },
  },
  render: function(h) {
    return h(this.ViewComponent);
  }
}).$mount('#app');
