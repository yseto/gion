/* vim:set ts=2 sts=2 sw=2:*/
<template>
<div>
  <GionHeader></GionHeader>
  <div class="container">
    <div class="row">
      <div class="panel panel-info">
        <div class="panel-heading">
          Pin List <span class="badge">{{ list.length }}</span>
        </div>
        <ul class="list-group">
          <li class="list-group-item" v-for="(item, index) in list">
            <a class="glyphicon glyphicon-check" style="cursor:pointer;"
              v-bind:data-guid="item.guid" v-bind:data-index="index" v-on:click="applyRead">
            </a>
            <span>{{ item.update_at | localtime }}</span>
            <a v-bind:href="item.url" target="blank">{{ item.title }}</a>
          </li>
        </ul>
      </div>
      <p class="clearfix hidden-lg hidden-md">
        <a class="btn btn-default pull-right" v-on:click="$root.returntop">Back to Top</a>
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
    }, function(error, res) {
      self.list = res.body;
    });
  },
  methods: {
    // 既読にするをクリックされた時の処理
    applyRead: function(event) {
      var self = this;
      agent({
        url: '/api/set_pin',
        data: {
          'readflag': 2,
          'pinid': encodeURI(event.target.getAttribute('data-guid'))
        },
      }, function() {
        self.list.splice(event.target.getAttribute('data-index'), 1);
      });
    },
  }
};
</script>
