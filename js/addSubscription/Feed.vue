/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="row">
    <div class="col-md-8">
      <h4>Subscription</h4>
      <div class="form-horizontal">
        <div class="row form-group">
          <label
            class="col-sm-3 col-form-label"
            for="inputURL"
          >URL(Web Page)</label>
          <div class="col-sm-6">
            <input
              v-model="url"
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
            <div
              v-if="searchState"
              class="spinner-border spinner-border-sm"
              role="status"
            >
              <span class="sr-only">Loading...</span>
            </div>
          </div>
        </div>
        <div class="row form-group">
          <label
            class="col-sm-3 col-form-label"
            for="inputTitle"
          >Title</label>
          <div class="col-sm-6">
            <input
              v-model="title"
              type="text"
              placeholder="Title"
              class="form-control"
            >
          </div>
        </div>
        <div class="row form-group">
          <label
            class="col-sm-3 col-form-label"
            for="inputRSS"
          >URL(Subscription)</label>
          <div class="col-sm-6">
            <input
              v-model="rss"
              type="text"
              placeholder="RSS"
              class="form-control"
            >
          </div>
        </div>
        <div class="row form-group">
          <label
            class="col-sm-3 col-form-label"
            for="selectCat"
          >Categories</label>
          <div class="col-sm-6">
            <select
              v-model="category"
              class="form-control"
              placeholder="Choose Category"
            >
              <option
                v-for="item in categories"
                :key="item.id"
                :value="item.id"
              >
                {{ item.name }}
              </option>
            </select>
          </div>
        </div>
        <div class="row form-group">
          <div class="col-sm-3" />
          <div class="col-sm-6">
            <button
              type="button"
              class="btn"
              :class="success ? 'btn-outline-primary' : 'btn-primary'"
              :disabled="!canRegister"
              @click.prevent="registerFeed"
            >
              {{ success ? "Saved!..." : "Register" }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div
        v-if="previewFeed"
        class="card previewFeed"
      >
        <div class="card-header">
          Preview
        </div>
        <ul class="list-group">
          <li
            v-for="item in previewFeed"
            :key="item.title"
            class="list-group-item"
          >
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
      categories: [],
      searchState: false,

      url: null,
      title: null,
      rss: null,

      previewFeed: null,
      success: false,
      category: null,
    };
  },
  computed: {
    canRegister: function() {
      return this.url && this.url.match(/^https?:/g) &&
      this.rss && this.rss.match(/^https?:/g) &&
      this.title &&
      this.category;
    },
  },
  created: function() {
    this.fetchList();
  },
  methods: {
    clear: function() {
      const vm = this;
      vm.url = null;
      vm.title = null;
      vm.rss = null;
      setTimeout(function() {
        vm.success = false;
      }, 750);
    },
    fetchList: function() {
      const vm = this;
      vm.$root.agent({ url: '/api/get_categories' }).then(data => {
        vm.categories = data;
        if (data.length > 0) {
          vm.category = data[0].id;
        }
      });
    },
    registerFeed: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/register_subscription',
        data: {
          'url': vm.url,
          'rss': vm.rss,
          'title': vm.title,
          'category': vm.category,
        },
      }).then(data => {
        if (data === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        if (data.result === "ERROR_ALREADY_REGISTER") {
          alert("すでに登録されています。");
          return false;
        }
        vm.success = true;
        vm.clear();
      });
    },
    // ページの詳細を取得する
    feedDetail: function() {
      const vm = this;
      if (!vm.url) {
        return false;
      }
      if (vm.url.match(/^https?:/g) === null) {
        return false;
      }

      vm.searchState = true;

      vm.$root.agent({
        url: '/api/examine_subscription',
        data: {
          url: vm.url
        },
      }).then(data => {
        if (data === null) {
          alert('Failure: Get information.\n please check url... :(');
          return false;
        }
        vm.rss = data.url;
        vm.title = data.title;
        vm.previewFeed = data.preview_feed;
        setTimeout(function() {
          vm.searchState = false;
        }, 500);
      });
    }
  },
}
</script>

