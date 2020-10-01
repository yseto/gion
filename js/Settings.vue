/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div>
    <div class="container">
      <div>
        <div role="form">
          <div class="row">
            <div class="form-group">
              <label
                class="control-label col-sm-2"
                for="numentry"
              >表示件数の上限</label>
              <div class="col-sm-10">
                <input
                  id="numentry"
                  v-model="numentry"
                  type="number"
                  placeholder="0で無制限"
                >
                <span class="help-block">一度に表示する件数の上限を設定できます。</span>
              </div>
            </div>
            <div class="form-group">
              <label
                class="control-label col-sm-2"
                for="numsubstr"
              >概要の文字数制限</label>
              <div class="col-sm-10">
                <input
                  id="numsubstr"
                  v-model="numsubstr"
                  type="number"
                  placeholder="0で無制限"
                >
                <span class="help-block">概要の文字数の上限を設定できます。</span>
              </div>
            </div>
            <div class="form-group">
              <label class="control-label col-sm-2">その他の設定</label>
              <div class="col-sm-10">
                <div class="checkbox">
                  <label><input
                    v-model="checked"
                    type="checkbox"
                    value="nopinlist"
                  >ログインしたらすぐにエントリ一覧を表示する</label>
                </div>
              </div>
            </div>
            <div class="form-group">
              <div class="col-sm-10 col-sm-offset-2">
                <a
                  class="btn btn-primary"
                  @click="apply"
                >OK</a>
                <span v-if="finished">Thanks. Setting your values.</span>
              </div>
            </div>
          </div>
          <hr>
        </div>
      </div>
      <hr>
      <h4>パスワード設定</h4>
      <div class="row">
        <div role="form">
          <div class="form-group">
            <label
              class="control-label col-sm-3"
              for="passwordOld"
            >今のパスワード</label>
            <div class="col-sm-13">
              <input
                id="passwordOld"
                v-model="passwordOld"
                type="password"
                placeholder="8文字以上"
              >
            </div>
          </div>
          <div class="form-group">
            <label
              class="control-label col-sm-3"
              for="password"
            >新しいパスワード</label>
            <div class="col-sm-13">
              <input
                id="password"
                v-model="password"
                type="password"
                placeholder="8文字以上"
              >
            </div>
          </div>
          <div class="form-group">
            <label
              class="control-label col-sm-3"
              for="passwordc"
            >新しいパスワード(確認)</label>
            <div class="col-sm-13">
              <input
                id="passwordc"
                v-model="passwordc"
                type="password"
                placeholder="8文字以上"
              >
            </div>
          </div>
          <div class="form-group">
            <div class="col-sm-13 col-sm-offset-3">
              <a
                class="btn btn-primary"
                @click.prevent="updatePassword"
              >Password Change.</a>
            </div>
          </div>
        </div>
      </div><!--/row-->
      <hr>
  
      <h4>OPML</h4>
  
      <div class="row">
        <div class="form-group">
          <label class="control-label col-sm-3">エクスポート</label>
          <div class="col-sm-13">
            <a
              class="btn btn-info"
              @click="opmlExport"
            >エクスポート</a>
          </div>
        </div>
  
        <div class="form-group">
          <label class="control-label col-sm-3">インポート</label>
          <div class="col-sm-13">
            <input
              ref="file"
              type="file"
            >
          </div>
        </div>
        <div class="form-group">
          <div class="col-sm-13 col-sm-offset-3">
            <button
              class="btn btn-default"
              @click="opmlImport"
            >
              インポート
            </button>
          </div>
        </div>
      </div><!--/row-->
      <hr>
      <p class="clearfix hidden-lg hidden-md">
        <a
          class="btn btn-default pull-right"
          @click="$root.returntop"
        >Back to Top</a>
      </p>
    </div><!--/container-->
  </div>
</template>

<script>
import fileDownload from 'js-file-download';

export default {
  data: function() {
    return {
      checked: [],
      numentry: 0,
      numsubstr: 0,
      finished: false,
      password: null,
      passwordOld: null,
      passwordc: null,
    };
  },
  created: function() {
    const vm = this;
    vm.$root.agent({
      url: '/api/get_numentry',
    }, function(data) {
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
      }, function() {
        vm.finished = true;
        setTimeout(function() {
          vm.finished = false;
        }, 1000);
      });
    },
    updatePassword: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/update_password',
        data: {
          password_old: vm.passwordOld,
          password: vm.password,
          passwordc: vm.passwordc
        }
      }, function(data) {
        alert(data.result);
      });
    },
    opmlExport: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/opml_export',
      }, function(data) {
        fileDownload(data.xml, 'opml.xml');
      });
    },
    opmlImport: function() {
      const vm = this;
      const file = vm.$refs.file.files[0];
      const reader = new FileReader();
      reader.addEventListener("load", function () {
        vm.$root.agent({
          url: '/api/opml_import',
          data: {
            xml: reader.result,
          },
        }, function() {});
      }, false);

      if (file) {
        reader.readAsText(file);
      }
    },
  }
};
</script>
