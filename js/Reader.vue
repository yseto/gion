/* vim:set ts=2 sts=2 sw=2:*/
<template>
<div>
  <GionHeader></GionHeader>
  <div class="container">
    <div class="row">
      <div class="col-sm-3">
        <!-- PINLIST -->
        <p>
          <a class="btn btn-small btn-info" v-on:click.prevent="pinListSwitch"><span class="glyphicon glyphicon-pushpin"></span> Pin List</a>
          <a class="btn btn-small btn-default" v-on:click.prevent="pinListClean"><span class="glyphicon glyphicon-remove"></span> Remove All Pin</a>
        </p>
  
        <div v-if="pinListState == true" class="panel panel-default pin__list">
          <div class="panel-heading">Pin List <span class="badge badge-info">{{ pinList.length }}</span></div>
          <div class="list-group" v-for="item in pinList">
            <a class="list-group-item" v-bind:href="item.url">{{ item.title }}</a>
          </div>
        </div>
  
        <!-- CATEGORIES -->
        <div class="panel panel-default categories__list">
          <div class="panel-heading"><span class="glyphicon glyphicon-list"></span>Categories</div>
          <div class="list-group">
            <a 
               class="list-group-item"
               v-for="(item, index) in categoryList"
               v-bind:class="{ active: index == category.selected() }"
               v-on:click.prevent="category.set(categoryList, index);contentUpdate();"
               >{{ item.name }} <span class="badge hidden-sm">{{ item.count }}</span></a>
          </div>
        </div>
      </div>
    
  
      <!-- CONTENT -->
      <div class="col-sm-9" id="contents_list">
        <div class="tw panel panel-default well" v-if="contentList.length === 0">
          <p class="text-center">No unreading entries.</p>
        </div>
        <div v-for="(item, index) in contentList">
          <div class="tw panel panel-default" v-bind:class="{ 'tw--active panel-info': index == content.selected() }">
            <h4 class="viewpage" v-bind:class="{ 'bg-info' : item.readflag == 2 }">
              <a v-bind:href="item.url" target="blank" rel="noreferrer" style="color: #333;">
              <span v-if="item.title.length > 0">{{ item.title }}</span>
              <span v-else>[nothing title...]</span>
              </a>
            </h4>
            <p>{{ item.description }}</p>
  
            <br class="hidden-md hidden-lg">
            <div class="text-right">
              <span style="margin-left:1em;" v-for="(undef, button) in externalApi">
                <button
                  class="btn btn-success btn-sm"
                  v-bind:data-service="button"
                  v-bind:data-url="item.raw_url"
                  v-on:click.prevent="add_bookmark"
                >{{ button }}</button>
              </span>
            </div>
            <div>
              <p
                v-if="item.readflag == 2"
                class="pull-right visible-md visible-lg"
                >
                <span class="glyphicon glyphicon-ok"></span> 
                Pin!
              </p>
              <!-- //スマホ用ピン立て -->
              <br class="hidden-md hidden-lg">
              <button
                class="hidden-md hidden-lg btn btn-info btn-sm btn-block"
                v-on:click="togglePin(index)"
              >
              Pin!
              </button>
            </div>
            <p>{{ item.date_epoch | epochToDateTime }} - {{ item.site_title}}</p>
          </div>
        </div>
      </div>
  
    </div><!--/row-->
  
    <ul class="pager hidden-lg hidden-md">
      <li class="previous"><a v-on:click.prevent="categoryPrevious" class="btn btn-default">&lt;&lt; Category Back</a></li>
      <li class="next"><a v-on:click.prevent="categoryNext" class="btn btn-default">Category Next &gt;&gt;</a></li>
    </ul>
  
    <p class="clearfix hidden-lg hidden-md"><a class="btn btn-default pull-right" v-on:click="$root.returntop">Back to Top</a></p>
  </div><!--/.container-->
</div>
</template>

<script>
import GionHeader from './components/Header.vue'
import agent from './components/UserAgent.js'

// 状態管理 ref. https://jp.vuejs.org/v2/guide/state-management.html
const categoryStore = {
  state: {
    category: null,
    selected: 0
  },
  set: function(list, index) {
    this.state.category = list[index].id;
    this.state.selected = index;
  },
  set_index: function(index) {
    this.state.selected = index;
  },
  clear: function() {
    this.state.category = null;
    this.state.selected = 0;
  },
  selected: function() {
    return this.state.selected;
  },
  category: function() {
    return this.state.category;
  }
};
const contentStore = {
  state: {
    serial: null,
    feed_id: null,
    selected: 0
  },
  set: function(list, index) {
    this.state.serial = list[index].serial;
    this.state.feed_id = list[index].feed_id;
    this.state.url = list[index].raw_url;
    this.state.selected = index;
  },
  clear: function() {
    this.state.serial = null;
    this.state.feed_id = null;
    this.state.url = null;
    this.state.selected = 0;
  },
  selected: function() {
    return this.state.selected;
  },
  serial: function() {
    return {
      serial: this.state.serial,
      feed_id: this.state.feed_id,
    };
  },
  url: function() {
    return this.state.url;
  }
};

export default {
  components: {
    GionHeader,
  },
  data: function() {
    return {
      category: categoryStore,
      categoryList: [],
      content: contentStore,
      contentList: [],
      pinListState: false,
      pinList: [],
      externalApi: {},
      moveFlag: true, // ピン立てでは移動しない
    };
  },
  created: function() {
    //console.log('created');
    var self = this;
    agent({
      url: '/api/get_social_service',
    }, function(err, _data) {
      var data = _data.body;
      data.resource.forEach(function(_, index) {
        self.externalApi[data.resource[index].service] = true;
      });
    });

    // CATEGORY
    agent({
      url: '/api/get_category',
    }, function(err, _data) {
      var data = _data.body;
      self.categoryList = data;
      if (data.length === 0) {
        self.category.clear();
        return false;
      }
      self.category.set(self.categoryList, 0);
      //console.log(self.categoryList);
      //console.log(self.category.category());
      self.contentUpdate();
    });
  },
  destroyed: function() {
    //console.log('destroyed');
    document.removeEventListener('keypress', this.keypress_handler);
  },
  mounted: function() {
    // キーボードのイベント
    document.addEventListener("keypress", this.keypress_handler);
  },
  // 移動
  updated: function() {
    //console.log('updated');
    if (document.querySelectorAll('.tw--active').length === 0) {
      return false;
    }
    //console.log('updated', 'exists');

    if (this.moveFlag === false) {
      this.moveFlag = true;
      return false;
    }

    var element = document.querySelectorAll('.tw--active');
    if (element.length !== 1) {
      return false;
    }
    var rect = element[0].getBoundingClientRect();
    var positionY = rect.top + window.pageYOffset - 80; // offset: 80
    window.scrollTo(0, positionY);
  },
  methods: {
    keypress_handler: function(e) {
      //console.log('keypress');
      e.preventDefault();
      // http://www.programming-magic.com/file/20080205232140/keycode_table.html
      switch (e.keyCode || e.which) {
        case 97:
          this.categoryPrevious();
          break; // A
        case 115:
          this.categoryNext();
          break; // S
        case 111:
          this.pinListSwitch();
          break; // O
        case 112:
          this.togglePin();
          break; // P
        case 114:
          this.contentUpdate();
          break; // R
        case 107:
          this.contentPrevious();
          break; // K
        case 106:
          this.contentNext();
          break; // J 
        case 118:
          this.itemView();
          break; // V
        case 105:
          this.addBookmarkKeyboard('hatena');
          break; // I
        case 108:
          this.addBookmarkKeyboard('pocket');
          break; // L
      }
    },

    // ::: CATEGORY :::
    // カテゴリの移動
    categoryNext: function() {
      if (this.categoryList.length === 0) {
        return false;
      }
      var index = this.category.selected() + 1;
      if (index === this.categoryList.length) {
        index = 0;
      }
      this.category.set(this.categoryList, index);
      this.contentUpdate();
    },
    categoryPrevious: function() {
      if (this.categoryList.length === 0) {
        return false;
      }
      var index = this.category.selected() - 1;
      if (0 > index) {
        index = this.categoryList.length - 1;
      }
      this.category.set(this.categoryList, index);
      this.contentUpdate();
    },
    // カテゴリ一覧の更新
    categoryUpdate: function() {
      var self = this;
      //console.info('categoryUpdate');

      agent({
        url: '/api/get_category',
      }, function(err, _data) {
        var data = _data.body;
        var updated = false;
        self.categoryList = data;

        // Vue の dataを更新する
        data.forEach(function(_, index) {
          // category_id が一致するものがある
          // 画面描画を更新する必要がある
          if (self.category.category() === data[index].id) {
            self.category.set_index(index); // 更新
            updated = true; // 更新したフラグ
            return false;
          }
        });
        // 更新していない場合は、カテゴリ一覧を一番上に設定する
        // ただし、選択可能なカテゴリがない場合は実行しない
        if (data.length > 0 && !updated) {
          self.category.set(self.categoryList, 0);
          self.contentUpdate();
        }
        //console.log('done');
      });
    },
    // ::: CONTENT :::
    // エントリの移動
    contentNext: function() {
      var index = this.content.selected() + 1;
      if (index === this.contentList.length) {
        return false;
      }
      this.content.set(this.contentList, index);
    },
    contentPrevious: function() {
      var index = this.content.selected() - 1;
      if (0 > index) {
        return false;
      }
      this.content.set(this.contentList, index);
    },
    // エントリ一覧の更新
    contentUpdate: function() {
      var self = this;
      //console.info('contentUpdate');

      // 初期値は0に設定すると、初期状態(カテゴリリストの先頭)のカテゴリを示す
      var id = (self.category.category() === null) ? 0 : self.category.category();

      agent({
        url: '/api/get_entry',
        data: {
          category: id
        },
      }, function(err, _data) {
        var data = _data.body;
        self.contentList = (typeof data.entry !== 'undefined') ? data.entry : [];
        if (self.contentList.length > 0) {
          self.read_it();
          self.content.set(self.contentList, 0);
        }
        self.categoryUpdate();
      });
    },
    // アイテムを閲覧する
    itemView: function() {
      var index = this.content.selected();
      window.open(this.contentList[index].url);
    },
    // フィードのアイテム既読リストを作成し、既読フラグを付加する
    read_it: function() {
      var self = this;
      //console.warn('flagged');

      var params = [], id = this.category.category();
      self.contentList.forEach(function(item) {
        // 未読ステータスのものだけ送るため、
        // フィードのアイテム既読リストを作成をする
        if (item.readflag === 0) {
          params.push({ serial: item.serial, feed_id: item.feed_id });
        }
      });

      console.warn('read_it > params', params);
      // 未読ステータスのものがなければ抜ける
      if (params.length === 0) {
        return false;
      }

      // ダブルタップやキーボードの連続押下で、誤ってしまった場合、送信前にカテゴリを確認する。
      setTimeout(function() {
        if (id !== categoryStore.category()) {
          //console.warn(id, categoryStore.category() );
          //console.warn('read_it', 'no send');
          return false;
        }
        //console.warn('read_it', 'send');
        agent({
          url: '/api/set_asread',
          json_request: true,
          data: JSON.stringify(params),
        }, function() {
          //console.log('read_it', 'send.done');
        });
      }, 500);
    },
    // ::: PINLIST :::
    // ピン立て
    togglePin: function(index) {
      var self = this;
      index = (typeof index !== 'undefined') ? index : self.content.selected();
      // サーバーにピン立てを通知する
      //console.log(self.contentList[index].readflag);
      agent({
        url: '/api/set_pin',
        data: {
          readflag: self.contentList[index].readflag,
          serial: self.contentList[index].serial,
          feed_id: self.contentList[index].feed_id,
        },
      }, function(err, data) {
        //console.log(data);
        self.contentList[index].readflag = data.body.readflag;
        self.moveFlag = false;
      });
    },
    // ピンリストに追加されているエントリの一覧を表示する
    pinListUpdate: function() {
      var self = this;
      agent({
        url: '/api/get_pinlist',
      }, function(err, data) {
        self.pinList = data.body;
      });
    },
    pinListSwitch: function() {
      this.pinListState = (this.pinListState === true) ? false : true;
      if (this.pinListState === true) {
        this.pinListUpdate();
      }
    },
    pinListClean: function() {
      var self = this;
      if (!confirm('ピンをすべて外しますか?')) {
        return false;
      }

      self.pinListState = false;
      agent({
        url: '/api/remove_all_pin',
      }, function() {
        self.pinList = [];
      });
    },
    // ::: BOOKMARK :::
    // 外部サービスへポストする
    add_bookmark: function(event) {
      var comment;
      var service = event.subscription.getAttribute('data-service');

      if (service === 'hatena') {
        comment = window.prompt("type a comment", "");
      }

      agent({
        url: '/external_api/' + service + '/post',
        data: {
          url: event.subscription.getAttribute('data-url'),
          comment: comment,
        },
      }, function() {});
    },
    addBookmarkKeyboard: function(service) {
      var self = this;
      var comment;

      if (service === 'hatena') {
        comment = window.prompt("type a comment", "");
      }

      agent({
        url: '/external_api/' + service + '/post',
        data: {
          url: self.content.url(),
          comment: comment,
        },
      }, function() {});
    }
  },
};
</script>

<style scoped>
.tw {
  margin: 0 0 5px !important;
  padding: 0 15px;
  box-sizing: border-box;
}
.tw--active {
  padding-left: 8px;
  border-left-width: 8px !important;
}
.categories__list .list-group-item, .pin__list .list-group-item {
  padding: 4px 10px;
  cursor: pointer;
}
</style>
