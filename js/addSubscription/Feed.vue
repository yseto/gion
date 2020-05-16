/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="row">
    <div class="col-md-8">
      <h4>Subscription</h4>
      <div class="form-horizontal">
        <div class="form-group">
          <label
            class="col-sm-3 control-label"
            for="inputURL"
          >URL(Web Page)</label>
          <div class="col-sm-6">
            <input
              v-model="field.url"
              type="text"
              placeholder="URL"
              class="form-control"
              @blur="feedDetail"
            >
          </div>
          <div class="col-sm-3">
            <a
              class="btn btn-info"
              @click.prevent="feedDetail"
            >Get Detail</a>
            <span
              v-if="searchState"
              class="glyphicon glyphicon-pencil"
            />
          </div>
        </div>
        <div class="form-group">
          <label
            class="col-sm-3 control-label"
            for="inputTitle"
          >Title</label>
          <div class="col-sm-6">
            <input
              v-model="field.title"
              type="text"
              placeholder="Title"
              class="form-control"
            >
          </div>
        </div>
        <div class="form-group">
          <label
            class="col-sm-3 control-label"
            for="inputRSS"
          >URL(Subscription)</label>
          <div class="col-sm-6">
            <input
              v-model="field.rss"
              type="text"
              placeholder="RSS"
              class="form-control"
            >
          </div>
        </div>
        <div class="form-group">
          <label
            class="col-sm-3 control-label"
            for="selectCat"
          >Categories</label>
          <div class="col-sm-6">
            <select
              v-model="category"
              class="form-control"
              placeholder="Choose Category"
            >
              <option
                v-for="item in list"
                :key="item.id"
                :value="item.id"
              >
                {{ item.name }}
              </option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <div class="col-sm-6 col-sm-offset-3">
            <button
              type="button"
              class="btn btn-primary"
              @click.prevent="registerFeed"
            >
              Register
            </button>
            <span v-if="successFeed">Thanks! add your request.</span>
          </div>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div
        v-if="field.preview_feed"
        class="panel panel-default previewFeed"
      >
        <div class="panel-heading">
          Preview
        </div>
        <ul
          v-for="item in field.preview_feed"
          :key="item.title"
          class="list-group"
        >
          <li class="list-group-item">
            {{ item.title }}<br>{{ item.date }}
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data: function() {
    return {
      list: [],
      searchState: false,
      field: {},
      successFeed: false,
      category: null,
    };
  },
  created: function() {
    this.fetchList();
  },
  methods: {
    fetchList: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/get_subscription',
      }, function(data) {
        vm.list = data.category;
        vm.category = data.category[0].id;
      });
    },

    registerFeed: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/register_subscription',
        data: {
          'url': vm.field.url,
          'rss': vm.field.rss,
          'title': vm.field.title,
          'parser_type': vm.field.parser_type,
          'category': vm.category,
        },
      }, function(data) {
        if (data === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        if (data.result === "ERROR_ALREADY_REGISTER") {
          alert("すでに登録されています。");
          return false;
        }
        vm.successFeed = true;
        vm.field = {};
      });
    },
    // ページの詳細を取得する
    feedDetail: function() {
      const vm = this;
      if (vm.field.url === undefined) {
        return false;
      }
      if (vm.field.url.match(/^https?:/g) === null) {
        return false;
      }

      vm.successFeed = false;
      vm.searchState = true;

      vm.$root.agent({
        url: '/api/examine_subscription',
        data: {
          url: vm.field.url
        },
      }, function(data) {
        if (data === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        vm.field.rss = data.url;
        vm.field.title = data.title;
        vm.field.preview_feed = data.preview_feed;
        vm.field.parser_type = data.parser_type;
        setTimeout(function() {
          vm.searchState = false;
        }, 500);
      });
    }
  },
}
</script>

