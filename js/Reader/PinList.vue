/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <p>
      <a
        class="btn btn-sm btn-info"
        @click.prevent="toggleVisible"
      >Pin List</a>
    </p>
    <div
      v-if="visibleState"
      class="card pin__list"
    >
      <div class="card-header">
        Pin List <span class="badge badge-info">{{ list.length }}</span>
      </div>
      <div class="list-group">
        <a
          v-for="(item, index) in list"
          :key="index"
          class="list-group-item"
          :href="item.url"
        >{{ item.title }}</a>
      </div>
      <div class="card-footer text-center">
        <a
          class="btn btn-sm btn-outline-dark"
          :class="{ disabled : list.length == 0}"
          @click.prevent="clean"
        >Remove All Pin</a>
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

      vm.$root.agent({ url: '/api/remove_all_pin' }).then(() => {
        vm.list = [];
      });
    },
    // ピンリストに追加されているエントリの一覧を表示する
    update: function() {
      const vm = this;
      if (this.visibleState) {
        vm.$root.agent({ url: '/api/get_pinlist' }).then(data => {
          vm.list = data;
        });
      }
    },
  }
}
</script>
