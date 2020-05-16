/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
import Vue from 'vue';
import Vuex from 'vuex';
import createPersistedState from "vuex-persistedstate";
// https://www.webopixel.net/javascript/1463.html

Vue.use(Vuex);

const state = {
  isLogin: false,
};

const mutations = {
  login (state) {
    state.isLogin = true;
  },
  logout (state) {
    state.isLogin = false;
  }
};

const getters = {
  isLogin (state) {
    return state.isLogin;
  },
};

export default new Vuex.Store({
  state,
  mutations,
  getters,
  strict: true,
  plugins: [createPersistedState({
    key: 'gion',
    paths: ['isLogin'],
  })]
});


