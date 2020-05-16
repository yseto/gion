/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <div
      v-if="$store.getters.length === 0"
      class="tw panel panel-default well"
    >
      <p class="text-center">
        No unreading entries.
      </p>
    </div>
    <div
      v-for="(item, index) in $store.getters.list"
      :key="index"
    >
      <div
        class="tw panel panel-default"
        :class="{ 'tw--active panel-info': index == $store.getters.selected }"
      >
        <h4
          class="viewpage"
          :class="{ 'bg-info' : item.readflag == 2 }"
        >
          <a
            :href="item.url"
            target="blank"
            rel="noreferrer"
            style="color: #333;"
          >
            <span v-if="item.title.length > 0">{{ item.title }}</span>
            <span v-else>[nothing title...]</span>
          </a>
        </h4>
        <p>{{ item.description }}</p>

        <div>
          <p
            v-if="item.readflag == 2"
            class="pull-right visible-md visible-lg"
          >
            <span class="glyphicon glyphicon-ok" /> 
            Pin!
          </p>
          <!-- //スマホ用ピン立て -->
          <br class="hidden-md hidden-lg">
          <button
            class="hidden-md hidden-lg btn btn-info btn-sm btn-block"
            @click="togglePin(index)"
          >
            Pin!
          </button>
        </div>
        <p>{{ item.date_epoch | epochToDateTime }} - {{ item.site_title }}</p>
      </div>
    </div>
  </div>
</template>

<script>
import store from './contentStore'

export default {
  data: function() {
    return {
      readItTimeoutID: null,
    };
  },
  store,

  // 移動に伴う更新
  updated: function() {
    if (document.querySelectorAll('.tw--active').length === 0) {
      return false;
    }

    const element = document.querySelectorAll('.tw--active');
    if (element.length === 1) {
      const rect = element[0].getBoundingClientRect();
      const positionY = rect.top + window.pageYOffset - 80; // offset: 80
      window.scrollTo(0, positionY);
    }
  },

  methods: {
    next: function() {
      const index = this.$store.getters.selected + 1;
      if (index === this.$store.getters.length) {
        return false;
      }
      this.$store.commit('setIndex', index);
    },
    previous: function() {
      const index = this.$store.getters.selected - 1;
      if (0 > index) {
        return false;
      }
      this.$store.commit('setIndex', index);
    },
    current: function() {
      return this.$store.getters.url;
    },
    update: function(categoryId) {
      const vm = this;
      if (categoryId === null) {
        this.$store.commit('set', {list: [], index: 0});
        return false;
      }
      vm.$root.agent({
        url: '/api/get_entry',
        data: {
          category: categoryId,
        },
      }, function(list) {
        vm.$store.commit('set', {list: list, index: 0});
        vm.readIt();
        vm.$emit('categoryUpdate');
      });
    },

    // フィードのアイテム既読リストを作成し、既読フラグを付加する
    readIt: function() {
      const vm = this;

      // ダブルタップやキーボードの連続押下の場合にイベントをキャンセルする
      if (vm.readItTimeoutID) {
        clearTimeout(vm.readItTimeoutID);
      }

      // 未読ステータスのものだけ送るため、フィードのアイテム既読リストを作成をする
      const params = vm.$store.getters.list
        .filter(item => item.readflag === 0)
        .map((item) => {
          return { serial: item.serial, feed_id: item.feed_id }
        });

      if (params.length === 0) {
        return false;
      }

      vm.readItTimeoutID = setTimeout(function() {
        vm.readItTimeoutID = null;
        vm.$root.agent({
          url: '/api/set_asread',
          jsonRequest: true,
          data: params,
        }, function() {});
      }, 500);

    },

    // ピン立て
    togglePin: function(index) {
      const vm = this;

      // スマホ対応
      if (typeof index !== 'undefined') {
        vm.$store.commit('setIndex', index);
      }

      // サーバーにピン立てを通知する
      vm.$root.agent({
        url: '/api/set_pin',
        data: vm.$store.getters.serialData,
      }, function(data) {
        vm.$store.commit('setReadflag', data.readflag);
      });
    },
  },
}
</script>
