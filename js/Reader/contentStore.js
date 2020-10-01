/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
import Vue from 'vue'
Vue.use(Vuex)
import Vuex from 'vuex'

export default new Vuex.Store({
  state: {
    list: [],
    selected: 0
  },
  mutations: {
    set (state, payload) {
      state.list = payload.list;
      state.selected = payload.index;
    },
    setIndex (state, index) {
      state.selected = index;
    },
    setReadflag (state, flag) {
      state.list[state.selected].readflag = flag;
    },
  },
  getters: {
    serialData: state => {
      const item = state.list[state.selected];
      return {
        serial: item.serial,
        feed_id: item.feed_id,
        readflag: item.readflag,
      };
    },
    url: state => {
      const item = state.list[state.selected];
      return item.url;
    },
    selected: state => {
      return state.selected;
    },
    length: state => {
      return state.list.length;
    },
    list: state => {
      return state.list;
    },
  },
})

