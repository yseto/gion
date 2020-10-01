/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <div class="card pin__list__page">
      <div class="card-header">
        Pin List <span class="badge badge-info">{{ list.length }}</span>
      </div>
      <ul class="list-group">
        <li
          v-for="(item, index) in list"
          :key="index"
          class="list-group-item"
        >
          <a
            class="btn btn-sm btn-info"
            style="cursor:pointer;"
            :data-serial="item.serial"
            :data-feed_id="item.feed_id"
            :data-index="index"
            @click="applyRead"
          >
            削除
          </a>
          <span>{{ item.update_at | localtime }}</span>
          <a
            :href="item.url"
            target="blank"
          >{{ item.title }}</a>
        </li>
      </ul>
    </div>
    <BackToTop />
  </div>
</template>

<script>
import BackToTop from './components/BackToTop.vue'

export default {
  components: {
    BackToTop,
  },
  data: function() {
    return {
      list: [],
    };
  },
  created: function() {
    var vm = this;
    vm.$root.agent({ url: '/api/get_pinlist' }).then(data => {
      vm.list = data;
    });
  },
  methods: {
    // 既読にするをクリックされた時の処理
    applyRead: function(event) {
      var vm = this;
      vm.$root.agent({
        url: '/api/set_pin',
        data: {
          readflag: 2,
          serial: event.target.getAttribute('data-serial'),
          feed_id: event.target.getAttribute('data-feed_id'),
        },
      }).then(() => {
        vm.list.splice(event.target.getAttribute('data-index'), 1);
      });
    },
  }
};
</script>
