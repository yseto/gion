/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <h4>パスワード設定</h4>
    <div role="form">
      <div class="row form-group">
        <label
          class="col-form-label col-sm-4"
          for="passwordOld"
        >今のパスワード</label>
        <div class="col-sm-8">
          <input
            v-model="passwordOld"
            type="password"
            placeholder="8文字以上"
            class="form-control"
          >
        </div>
      </div>
      <div class="row form-group">
        <label
          class="col-form-label col-sm-4"
          for="password"
        >新しいパスワード</label>
        <div class="col-sm-8">
          <input
            v-model="password"
            type="password"
            placeholder="8文字以上"
            class="form-control"
          >
        </div>
      </div>
      <div class="row form-group">
        <label
          class="col-form-label col-sm-4"
          for="passwordc"
        >新しいパスワード(確認)</label>
        <div class="col-sm-8">
          <input
            v-model="passwordc"
            type="password"
            placeholder="8文字以上"
            class="form-control"
          >
        </div>
      </div>
      <div class="row form-group">
        <div class="col-sm-4" />
        <div class="col-sm-8">
          <a
            class="btn btn-primary"
            @click.prevent="updatePassword"
          >Password Change.</a>
        </div>
      </div>
    </div>
  </div>
</template>

<script>

export default {
  data: function() {
    return {
      password: null,
      passwordOld: null,
      passwordc: null,
    };
  },
  methods: {
    updatePassword: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/update_password',
        data: {
          password_old: vm.passwordOld,
          password: vm.password,
          passwordc: vm.passwordc
        }
      }).then( data => alert(data.result) );
    },
  },
}
</script>

