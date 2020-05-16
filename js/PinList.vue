/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <div class="row">
      <div class="panel panel-info pin__list__page">
        <div class="panel-heading">
          Pin List <span class="badge">{{ list.length }}</span>
        </div>
        <ul class="list-group">
          <li
            v-for="(item, index) in list"
            :key="index"
            class="list-group-item"
          >
            <a
              class="glyphicon glyphicon-check"
              style="cursor:pointer;"
              :data-serial="item.serial"
              :data-feed_id="item.feed_id"
              :data-index="index"
              @click="applyRead"
            />
            <span>{{ item.update_at | localtime }}</span>
            <a
              :href="item.url"
              target="blank"
            >{{ item.title }}</a>
          </li>
        </ul>
      </div>
      <p class="clearfix hidden-lg hidden-md">
        <a
          class="btn btn-default pull-right"
          @click="$root.returntop"
        >Back to Top</a>
      </p>
    </div>
  </div>
</template>

<script>
export default {
  data: function() {
    return {
      list: [],
    };
  },
  created: function() {
    var vm = this;
    vm.$root.agent({
      url: '/api/get_pinlist'
    }, function(data) {
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
      }, function() {
        vm.list.splice(event.target.getAttribute('data-index'), 1);
      });
    },
  }
};
</script>
