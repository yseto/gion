/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <p>
      <a
        class="btn btn-small btn-info"
        @click.prevent="toggleVisible"
      ><span class="glyphicon glyphicon-pushpin" /> Pin List</a>
      <a
        class="btn btn-small btn-default"
        @click.prevent="clean"
      ><span class="glyphicon glyphicon-remove" /> Remove All Pin</a>
    </p>

    <div
      v-if="visibleState"
      class="panel panel-default pin__list"
    >
      <div class="panel-heading">
        Pin List <span class="badge badge-info">{{ list.length }}</span>
      </div>
      <div
        v-for="(item, index) in list"
        :key="index"
        class="list-group"
      >
        <a
          class="list-group-item"
          :href="item.url"
        >{{ item.title }}</a>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data: function() {
    return {
      visibleState: false,
      list: [],
    };
  },
  methods: {
    toggleVisible: function() {
      this.visibleState = this.visibleState ? false : true;
      this.update();
    },
    clean: function() {
      const vm = this;
      if (!confirm('ピンをすべて外しますか?')) {
        return false;
      }
      this.visibleState = false;

      vm.$root.agent({
        url: '/api/remove_all_pin',
      }, function() {
        vm.list = [];
      });
    },
    // ピンリストに追加されているエントリの一覧を表示する
    update: function() {
      const vm = this;
      if (this.visibleState) {
        vm.$root.agent({
          url: '/api/get_pinlist',
        }, function(data) {
          vm.list = data;
        });
      }
    },
  }
}
</script>
