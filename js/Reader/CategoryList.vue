/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="panel panel-default categories__list">
    <div class="panel-heading">
      <span class="glyphicon glyphicon-list" />Categories
    </div>
    <div class="list-group">
      <a 
        v-for="(item, index) in $store.getters.list"
        :key="index"
        class="list-group-item"
        :class="{ active: index == $store.getters.selected }"
        @click.prevent="$store.commit('setIndex', index); $emit('contentUpdate');"
      >{{ item.name }} <span class="badge hidden-sm">{{ item.count }}</span></a>
    </div>
  </div>
</template>

<script>
import store from './categoryStore'

export default {
  store,
  created: function() {
    const vm = this;
    vm.$root.agent({
      url: '/api/get_category',
    }, function(list) {
      vm.$store.commit('set', { list: list, index: 0});
      vm.$emit("contentUpdate");
    });
  },
  methods: {
    next: function() {
      if (this.$store.getters.length === 0) {
        return false;
      }
      let index = this.$store.getters.selected + 1;
      if (index === this.$store.getters.length) {
        index = 0;
      }
      this.$store.commit('setIndex', index);
      this.$emit("contentUpdate");
    },
    previous: function() {
      if (this.$store.getters.length === 0) {
        return false;
      }
      let index = this.$store.getters.selected - 1;
      if (0 > index) {
        index = this.$store.getters.length - 1;
      }
      this.$store.commit('setIndex', index);
      this.$emit("contentUpdate");
    },
    current: function() {
      return this.$store.getters.category;
    },
    update: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/get_category',
      }, function(list) {
        let updated = false;

        // 表示を更新する
        list.forEach(function(_, index) {
          // 現在選択している category_id が一致するものがある時
          // indexを任意の位置に移動する
          if (vm.$store.getters.category === list[index].id) {
            vm.$store.commit('set', { list: list, index: index});
            updated = true;
            return false;
          }
        });

        // 表示していたカテゴリをすべて読み終えた場合などは、
        // カテゴリ一覧の一番上のカテゴリにindexを設定する
        // 選択可能なカテゴリがない場合は実行しない
        if (!updated) {
          vm.$store.commit('set', { list: list, index: 0});
          vm.$emit("contentUpdate");
        }
      });
    }
  },
}
</script>

