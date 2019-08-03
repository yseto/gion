/* vim:set ts=2 sts=2 sw=2:*/
<template>
<div>
  <GionHeader></GionHeader>
  <div class="container">
    <div class="row">
      <h4>Subscription</h4>
      <div class="col-md-8">
        <form class="form-horizontal" id="form">
          <div class="form-group">
            <label class="col-sm-3 control-label" for="inputURL">URL(Web Page)</label>
            <div class="col-sm-6">
              <input type="text" id="inputURL" placeholder="URL" class="form-control" v-model="field.url" v-on:blur="feedDetail">
            </div>
            <div class="col-sm-3">
              <a class="btn btn-info" v-on:click.prevent="feedDetail">Get Detail</a>
              <span v-if="searchState" class="glyphicon glyphicon-pencil"></span>
            </div>
          </div>
          <div class="form-group">
           <label class="col-sm-3 control-label" for="inputTitle">Title</label>
            <div class="col-sm-6">
              <input type="text" id="inputTitle" placeholder="Title" class="form-control" v-model="field.title">
            </div>
          </div>
          <div class="form-group">
           <label class="col-sm-3 control-label" for="inputRSS">URL(Subscription)</label>
            <div class="col-sm-6">
              <input type="text" id="inputRSS" placeholder="RSS" class="form-control" v-model="field.rss">
            </div>
          </div>
          <div class="form-group">
           <label class="col-sm-3 control-label" for="selectCat">Categories</label>
            <div class="col-sm-6">
              <select class="form-control" id="selectCat" placeholder="Choose Category" v-model="category">
                <option v-for="item in list" v-bind:value="item.id">{{ item.name }}</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <div class="col-sm-6 col-sm-offset-3">
              <button type="button" v-on:click.prevent="registerFeed" class="btn btn-primary">Register</button>
              <span v-if="successFeed">Thanks! add your request.</span>
            </div>
          </div>
        </form>
      </div>
      <div class="col-md-4">
        <div class="panel panel-default previewFeed" v-if="field.preview_feed">
          <div class="panel-heading">Preview</div>
          <ul class="list-group" v-for="item in field.preview_feed">
            <li class="list-group-item">{{ item.title }}<br>{{ item.date }}</a></li>
          </ul>
        </div>
      </div>
    </div>
      <hr>
    <div class="row">
      <h4>Categories</h4>
      <form class="form-horizontal" id="form">
        <div class="form-group">
          <label class="col-sm-2 control-label" for="inputCategoryName">Name</label>
          <div class="col-sm-4">
            <input type="text" class="form-control" id="inputCategoryName" v-model="inputCategoryName" placeholder="Name">
          </div>
        </div>
        <div class="form-group">
          <div class="col-sm-10 col-sm-offset-2">
            <button type="button" v-on:click.prevent="registerCategory" class="btn btn-primary">Register</button>
          </div>
        </div>
      </form>
    </div>
    <p class="clearfix hidden-lg hidden-md"><a class="btn btn-default pull-right" v-on:click="$root.returntop">Back to Top</a></p>
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
      list: [],
      searchState: false,
      field: {},
      successFeed: false,
      category: null,

      inputCategoryName: null
    };
  },
  created: function() {
    this.fetchList();
  },
  methods: {
    fetchList: function() {
      var self = this;
      agent({
        url: '/api/get_subscription',
      }, function(err, _data) {
        var data = _data.body;
        self.list = data.category;
        self.category = data.category[0].id;
      });
    },
    // カテゴリの登録
    registerCategory: function() {
      var self = this;
      if (self.inputCategoryName.length === 0) {
        return false;
      }

      agent({
        url: '/api/register_category',
        data: {
          name: self.inputCategoryName
        },
      }, function(err, j) {
        if (j.body.result === "ERROR_ALREADY_REGISTER") {
          alert("すでに登録されています。");
        } else {
          self.fetchList();
          alert("登録しました。");
        }
      });
    },
    registerFeed: function() {
      var self = this;
      agent({
        url: '/api/register_subscription',
        data: {
          'url': self.field.url,
          'rss': self.field.rss,
          'title': self.field.title,
          'parser_type': self.field.parser_type,
          'category': self.category,
        },
      }, function(error, j) {
        if (j.body === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        if (j.body.result === "ERROR_ALREADY_REGISTER") {
          alert("すでに登録されています。");
          return false;
        }
        self.successFeed = true;
        self.field = {};
      });
    },
    // ページの詳細を取得する
    feedDetail: function() {
      var self = this;
      if (typeof self.field.url === 'undefined') {
        return false;
      }
      if (self.field.url.match(/^https?:/g) === null) {
        return false;
      }

      self.successFeed = false;
      self.searchState = true;
      self.preview_feed = null;

      agent({
        url: '/api/examine_subscription',
        data: {
          url: self.field.url
        },
      }, function(err, _j) {
        var j = _j.body;
        if (j === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        self.field.rss = j.url;
        self.field.title = j.title;
        self.field.preview_feed = j.preview_feed;
        self.field.parser_type = j.parser_type;
        setTimeout(function() {
          self.searchState = false;
        }, 500);
      });
    }
  }
};
</script>

<style scoped>
.previewFeed .list-group-item {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
</style>
