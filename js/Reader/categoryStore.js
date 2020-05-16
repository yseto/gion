/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
import Vue from 'vue'
Vue.use(Vuex)
import Vuex from 'vuex'

export default new Vuex.Store({
  state: {
    list:   [],
    selected: 0
  },
  mutations: {
    set (state, payload) {
      const list = payload.list;
      const index = payload.index;
      state.list = list;
      state.selected = index;
    },
    setIndex (state, index) {
      state.selected = index;
    },
  },
  getters: {
    category: state => {
      // category_id or null
      return state.list[state.selected] ? state.list[state.selected].id : null;
    },
    selected: state => {
      return state.selected;
    },
    list: state => {
      return state.list;
    },
    length: state => {
      return state.list.length;
    },
  }
})
