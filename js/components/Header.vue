/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div
    v-if="$route.meta.anonymous ? false : true"
    class="navbar navbar-default navbar-fixed-top"
    role="navigation"
  >
    <div class="container">
      <div class="navbar-header">
        <button
          type="button"
          class="navbar-toggle"
          @click="navbar"
        >
          <span class="sr-only">Toggle navigation</span>
          <span class="icon-bar" />
          <span class="icon-bar" />
          <span class="icon-bar" />
        </button>
        <span class="navbar-brand">Gion</span>
      </div>
      <div
        class="navbar-collapse collapse"
        :class="{ show: navbarState }"
      >
        <ul
          v-for="item in items"
          :key="item.caption"
          class="nav navbar-nav"
        >
          <li :class="{ active: $root.$route.path === item.route }">
            <a @click="go(item.route)"><span
              class="glyphicon"
              :class="item.icon"
            /> {{ item.caption }}</a>
          </li>
        </ul>
        <ul class="nav navbar-nav navbar-right">
          <li :class="{ active: $root.$route.path === '/settings' }">
            <a @click="go('/settings')"><span class="glyphicon glyphicon-wrench" /> Settings</a>
          </li>
          <li class="hidden-sm">
            <a
              style="cursor:pointer;"
              @click="helpModal=true"
            >
              <i class="glyphicon glyphicon-question-sign" /> Help
            </a>
          </li>
          <li><a @click="go('/logout')"><span class="glyphicon glyphicon-off" /> Logout</a></li>
        </ul>
      </div><!--/.navbar-collapse -->
    </div>

    <div
      v-if="helpModal"
      id="helpModal"
      class="modal show"
      tabindex="-1"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <button
              type="button"
              class="close"
              data-dismiss="modal"
              aria-label="Close"
              @click="helpModal=false"
            >
              <span aria-hidden="true">&times;</span>
            </button>
            <h4 class="modal-title">
              Help
            </h4>
          </div>
          <div class="modal-body">
            <p>Pin Listでは、ピン止めしたエントリの一覧が表示されます。</p>
            <p><span class="glyphicon glyphicon-check" /> をクリックすると該当のエントリのピンを外すことができます。</p>
            <p><span class="glyphicon glyphicon-check" /> のとなりに表示されている時間はピンを立てた時間です。</p>
  
            <hr>
  
            <p>URLに巡回したいWebサイトのアドレスを入力して、<a class="btn btn-info">Get Detail</a>をクリックすると、必要な情報を取得します。</p>
            <p>この方法で取得できない場合は、Webページのデータを確認してください。RSSを配信していない可能性があります。</p>
            <hr>
            <p>カテゴリを増やしたい場合は、下の入力欄にカテゴリの名前を入力してください。この時追加したカテゴリはすぐに、サイト登録でお使いになれます。</p>
  
            <hr>
  
            <table class="table table-striped table-bordered">
              <tr><th>Key</th><th>Description</th></tr>
              <tr><th>A</th><td>一つ前のカテゴリ</td></tr>
              <tr><th>S</th><td>一つ次のカテゴリ</td></tr>
              <tr><th>K</th><td>一つ前のアイテムを選択する</td></tr>
              <tr><th>J</th><td>一つ次のアイテムを選択する</td></tr>
              <tr><th>O</th><td>ピンリストを開く、閉じる</td></tr>
              <tr><th>P</th><td>ピンを立てる、外す</td></tr>
              <tr><th>V</th><td>アイテムを開く</td></tr>
              <tr><th>R</th><td>ページを再読み込みする</td></tr>
            </table>
  
            <hr>
  
            <p>変更ボタンで巡回先のカテゴリを移動させることができます。</p>
            <p>削除ボタンで巡回先を巡回対象から外すことができます。</p>
            <p>カテゴリを削除した場合、カテゴリ以下に登録されている巡回先も同時に削除されます。</p>
  
            <hr>
          </div>
          <div class="modal-footer">
            <button
              class="btn btn-default"
              @click="helpModal=false"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  
    <div
      v-if="$root.error"
      id="errorModal"
      class="modal show"
      tabindex="-1"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h4 class="modal-title">
              Sorry
            </h4>
          </div>
          <div class="modal-body">
            <p>申し訳ありません。エラーが発生しました。<br>管理者にご連絡ください。</p>
          </div>
          <div class="modal-footer">
            <button
              class="btn btn-default"
              @click.prevent="$root.error=false"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data: function() {
    return {
      items: [
        {
          icon: 'glyphicon-pushpin',
          caption: 'Pin List',
          route: '/pin',
        }, {
          icon: 'glyphicon-inbox',
          caption: 'Read entries',
          route: '/entry',
        }, {
          icon: 'glyphicon-plus-sign',
          caption: 'Add a new subscription',
          route: '/add',
        }, {
          icon: 'glyphicon-list',
          caption: 'Manage subscription',
          route: '/subscription',
        }
      ],
      navbarState: false,
      helpModal: false,
    };
  },
  methods: {
    navbar: function() {
      this.navbarState = this.navbarState ? false : true;
    },
    go: function(to) {
      this.navbarState = false;
      if (this.$route.path !== to) {
        this.$router.push(to);
      }
    },
  },
}
</script>

