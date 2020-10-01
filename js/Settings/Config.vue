/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div role="form">
    <div class="row form-group">
      <label
        class="col-form-label col-sm-4"
        for="numentry"
      >表示件数の上限</label>
      <div class="col-sm-8">
        <input
          v-model="numentry"
          type="number"
          placeholder="0で無制限"
          class="form-control"
        >
        <span class="form-text">一度に表示する件数の上限を設定できます。</span>
      </div>
    </div>
    <div class="row form-group">
      <label
        class="col-form-label col-sm-4"
        for="numsubstr"
      >概要の文字数制限</label>
      <div class="col-sm-8">
        <input
          v-model="numsubstr"
          type="number"
          placeholder="0で無制限"
          class="form-control"
        >
        <span class="form-text">概要の文字数の上限を設定できます。</span>
      </div>
    </div>
    <div class="row form-group">
      <label class="col-form-label col-sm-4">その他の設定</label>
      <div class="col-sm-8">
        <div class="form-check">
          <input
            id="nopinlist"
            v-model="checked"
            type="checkbox"
            value="nopinlist"
            class="form-check-input"
          >
          <label
            class="form-check-label"
            for="nopinlist"
          >ログインしたらすぐにエントリ一覧を表示する</label>
        </div>
      </div>
    </div>
    <div class="row form-group">
      <div class="col-sm-4" />
      <div class="col-sm-8">
        <button
          class="btn"
          :class="finished ? 'btn-outline-primary' : 'btn-primary'"
          @click="apply"
        >
          {{ finished ? "Saved!..." : "OK" }}
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data: function() {
    return {
      checked: [],
      numentry: 0,
      numsubstr: 0,
      finished: false,
    };
  },
  created: function() {
    const vm = this;
    vm.$root.agent({ url: '/api/get_numentry' }).then(data => {
      if (data.nopinlist) {
        vm.checked.push('nopinlist');
      }
      vm.numsubstr = data.numsubstr;
      vm.numentry = data.numentry;
    });
  },
  methods: {
    apply: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/set_numentry',
        data: {
          numentry: vm.numentry,
          nopinlist: (vm.checked.indexOf('nopinlist') >= 0) ? 1 : 0,
          numsubstr: vm.numsubstr,
        },
      }).then(() => {
        vm.finished = true;
        setTimeout(function() {
          vm.finished = false;
        }, 1000);
      });
    },
  }
}
</script>

