/* vim:set ts=2 sts=2 sw=2:*/
<template>
  <div>
    <GionHeader />
    <div class="container">
      <div class="row">
        <div class="panel panel-info">
          <div class="panel-heading">
            Pin List <span class="badge">{{ list.length }}</span>
          </div>
          <ul class="list-group">
            <li
              v-for="(item, index) in list"
              :key="item.url"
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
  </div>
</template>

<script>
import GionHeader from './components/Header.vue'
import agent from './components/UserAgent.js'

export default {
  components: {
    GionHeader,
  },
  data: function() {
    return {
      list: [],
    };
  },
  created: function() {
    var self = this;
    agent({
      url: '/api/get_pinlist'
    }, function(data) {
      self.list = data;
    });
  },
  methods: {
    // 既読にするをクリックされた時の処理
    applyRead: function(event) {
      var self = this;
      agent({
        url: '/api/set_pin',
        data: {
          readflag: 2,
          serial: event.target.getAttribute('data-serial'),
          feed_id: event.target.getAttribute('data-feed_id'),
        },
      }, function() {
        self.list.splice(event.target.getAttribute('data-index'), 1);
      });
    },
  }
};
</script>
