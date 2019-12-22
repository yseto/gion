/* vim:set ts=2 sts=2 sw=2:*/
<template>
  <div>
    <GionHeader />
    <div class="container">
      <div>
        <form role="form">
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
                    value="noreferrer"
                  >リファラを抑制する</label>
                </div>
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
          <div class="row">
            <div class="form-group">
              <label class="control-label col-sm-2">連携設定</label>
              <div class="col-sm-10">
                <table class="table table-condenced">
                  <tr>
                    <th>サービス</th>
                    <th>状態</th>
                  </tr>
                  <tr
                    v-for="(value, service) in external_api"
                    :key="value.state"
                  >
                    <td>{{ value.name }}</td>
                    <td v-if="value.state">
                      <a
                        class="btn btn-default btn-xs"
                        :href="'/external_api/'+service+'/disconnect'"
                      >
                        <span class="glyphicon glyphicon-remove" /> 連携の解除
                      </a>
                      <span>{{ value.username }}</span>
                    </td><td v-else>
                      <a
                        class="btn btn-default btn-xs"
                        :href="'/external_api/'+service+'/connect'"
                      >
                        <span class="glyphicon glyphicon-link" /> 連携する
                      </a>
                    </td>
                  </tr>
                </table>
              </div>
            </div>
          </div><!--/row-->
        </form>
      </div>
      <hr>
      <h4>パスワード設定</h4>
      <div class="row">
        <form
          id="form2"
          role="form"
        >
          <div class="form-group">
            <label
              class="control-label col-sm-3"
              for="password_old"
            >今のパスワード</label>
            <div class="col-sm-13">
              <input
                id="password_old"
                v-model="password_old"
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
        </form>
      </div><!--/row-->
      <hr>
  
      <template v-if="hasAdmin">
        <h4>ユーザー追加</h4>
        <div class="row">
          <form
            id="form2"
            role="form"
          >
            <div class="form-group">
              <label
                class="control-label col-sm-3"
                for="username"
              >ユーザー名</label>
              <div class="col-sm-13">
                <input
                  id="username"
                  v-model="username"
                  type="text"
                >
              </div>
            </div>
            <div class="form-group">
              <label
                class="control-label col-sm-3"
                for="user_password"
              >パスワード</label>
              <div class="col-sm-13">
                <input
                  id="user_password"
                  v-model="user_password"
                  type="password"
                  placeholder="8文字以上"
                >
              </div>
            </div>
            <div class="form-group">
              <div class="col-sm-13 col-sm-offset-3">
                <a
                  class="btn btn-primary"
                  @click="createUser"
                >Create User</a>
              </div>
            </div>
          </form>
        </div><!--/row-->
        <hr>
      </template>
  
      <h4>OPML</h4>
  
      <div class="row">
        <div class="form-group">
          <label class="control-label col-sm-3">エクスポート</label>
          <div class="col-sm-13">
            <a
              class="btn btn-info"
              href="../opml/opml_export"
            >エクスポート</a>
          </div>
        </div>
  
        <form
          action="../opml/opml_import"
          method="post"
          role="form"
          enctype="multipart/form-data"
        >
          <input
            type="hidden"
            name="_token"
            :value="csrfToken"
          >
          <div class="form-group">
            <label class="control-label col-sm-3">インポート</label>
            <div class="col-sm-13">
              <input
                type="file"
                name="file"
              >
            </div>
          </div>
          <div class="form-group">
            <div class="col-sm-13 col-sm-offset-3">
              <button
                type="submit"
                class="btn btn-default"
              >
                インポート
              </button>
            </div>
          </div>
        </form>
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
import GionHeader from './components/Header.vue'
import agent from './components/UserAgent.js'

export default {
  components: {
    GionHeader,
  },
  data: function() {
    return {
      checked: [],
      numentry: 0,
      numsubstr: 0,
      external_api: {
        pocket: {
          name: 'Pocket',
          state: false,
        },
        hatena: {
          name: 'Hatena Bookmark',
          state: false,
        },
      },
      finished: false,
      password: null,
      password_old: null,
      passwordc: null,
      username: null,
      user_password: null
    };
  },
  computed: {
    hasAdmin: function() {
      return document.querySelector('meta[name=permission]').content == 'true';
    },
    csrfToken: function() {
      return document.getElementsByName('csrf-token')[0].content;
    },
  },
  created: function() {
    var self = this;
    agent({
      url: '/api/get_numentry',
    }, function(data) {
        if (data.noreferrer) {
          self.checked.push('noreferrer');
        }
        if (data.nopinlist) {
          self.checked.push('nopinlist');
        }
        self.numsubstr = data.numsubstr;
        self.numentry = data.numentry;
    });
    agent({
      url: '/api/get_social_service',
    }, function(data) {
        data.resource.forEach(function(_, index) {
          self.external_api[data.resource[index].service].state = true;
          self.external_api[data.resource[index].service].username = data.resource[index].username;
        });
    });
  },
  methods: {
    apply: function() {
      var self = this;
      agent({
        url: '/api/set_numentry',
        data: {
          numentry: self.numentry,
          noreferrer: (self.checked.indexOf('noreferrer') >= 0) ? 1 : 0,
          nopinlist: (self.checked.indexOf('nopinlist') >= 0) ? 1 : 0,
          numsubstr: self.numsubstr,
        },
      }, function() {
        self.finished = true;
        setTimeout(function() {
          self.finished = false;
        }, 1000);
      });
    },
    updatePassword: function() {
      var self = this;
      agent({
        url: '/api/update_password',
        data: {
          password_old: self.password_old,
          password: self.password,
          passwordc: self.passwordc
        }
      }, function(data) {
          alert(data.result);
      });
    },
    createUser: function() {
      var self = this;
      agent({
        url: '/api/create_user',
        data: {
          username: self.username,
          password: self.user_password
        }
      }, function(data) {
          alert(data.result);
      });
    }
  }
};
</script>
