/* vim:set ts=2 sts=2 sw=2:*/
<template>
  <div
    class="navbar navbar-default navbar-fixed-top"
    role="navigation"
  >
    <div class="container">
      <div class="navbar-header">
        <button
          type="button"
          class="navbar-toggle"
          @click="$root.navbar"
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
        :class="{ show: $root.navbarState }"
      >
        <ul
          v-for="item in items"
          :key="item.caption"
          class="nav navbar-nav"
        >
          <li :class="{ active: $root.currentRoute === item.route }">
            <a @click="$root.go(item.route)"><span :class="item.icon" /> {{ item.caption }}</a>
          </li>
        </ul>
        <ul class="nav navbar-nav navbar-right">
          <li :class="{ active: $root.currentRoute === '#settings' }">
            <a @click="$root.go('#settings')"><span class="glyphicon glyphicon-wrench" /> Settings</a>
          </li>
          <li class="hidden-sm">
            <a
              style="cursor:pointer;"
              @click="$root.helpModal=true"
            >
              <i class="glyphicon glyphicon-question-sign" /> Help
            </a>
          </li>
          <li><a href="/logout"><span class="glyphicon glyphicon-off" /> Logout</a></li>
        </ul>
      </div><!--/.navbar-collapse -->
    </div>

    <div
      v-if="$root.helpModal"
      id="helpModal"
      class="modal show"
      tabindex="-1"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
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
              @click="$root.helpModal=false"
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
      items: [],
    };
  },
  created: function() {
    const vm = this;
    const items = {
      'entry': {
        icon: 'inbox',
        caption: 'Read entries'
      },
      'pin': {
        icon: 'pushpin',
        caption: 'Pin List'
      },
      'add': {
        icon: 'plus-sign',
        caption: 'Add a new subscription'
      },
      'subscription': {
        icon: 'list',
        caption: 'Manage subscription'
      },
    };
    const lineup = this.defaultReader() ? ['entry', 'pin'] : ['pin', 'entry'];
    lineup.concat(['add', 'subscription']).forEach(function(element) {
      let item = items[element];
      item.icon = `glyphicon glyphicon-${item.icon}`;
      item.route = `#${element}`;
      vm.items.push(item);
    });
  },
  methods: {
    defaultReader: function() {
      return document.querySelector('meta[name=mode-nopin]').content === 'true';
    }
  },
}
</script>

<style scoped>
.navbar-nav li {
  cursor: pointer;
}
</style>
