/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <table
      class="table table-condensed"
      style="table-layout: fixed;"
    >
      <tbody>
        <div
          v-for="category in subscription"
          :key="category.id"
        >
          <tr class="row">
            <th class="col-9 text-truncate">
              <span>{{ category.name }}</span>
            </th>
            <td class="col-3 text-right">
              <button
                class="btn btn-danger btn-sm"
                @click="removeIt(category.id, 'category', category.name)"
              >
                削除
              </button>
            </td>
          </tr>
          <tr
            v-for="item in category.subscription"
            :key="item.id"
            class="row"
          >
            <td class="col-9 text-truncate">
              <a
                class="btn btn-link btn-sm"
                :href="item.siteurl"
                :title="item.title"
                target="blank"
              >
                <span
                  v-if="item.http_status >= '400'"
                  class="badge badge-dark"
                >取得に失敗</span>
                <span>{{ item.title }}</span>
              </a>
            </td>
            <td class="col-3 text-right">
              <button
                class="btn btn-info btn-sm"
                @click="changeCategory(item.id, item.category_id)"
              >
                移動
              </button>
              <button
                class="btn btn-danger btn-sm"
                @click="removeIt(item.id, 'entry', item.title)"
              >
                削除
              </button>
            </td>
          </tr>
        </div>
      </tbody>
    </table>

    <div
      id="categoryModal"
      :class="{ 'd-block': categoryModal }"
      class="modal"
      tabindex="-1"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h4 class="modal-title">
              Change: Categories
            </h4>
          </div>
          <div class="modal-body">
            <label
              class="col-form-label"
              for="selectCat"
            >Categories</label>
            <select
              v-model="fieldCategory"
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
          <div class="modal-footer">
            <a
              class="btn btn-success"
              @click="submit"
            >OK</a>
            <button
              class="btn btn-light"
              @click="categoryModal=false"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    <BackToTop />
  </div><!--/.container-->
</template>

<script>
import BackToTop from './components/BackToTop.vue'

export default {
  components: {
    BackToTop,
  },
  data: function() {
    return {
      categories: [],
      subscription: [],
      fieldCategory: null,
      fieldId: null,
      categoryModal: false
    };
  },
  created: function() {
    this.fetchList();
  },
  methods: {
    // エントリのカテゴリの変更ウィンドウを表示する
    changeCategory: function(id, category) {
      this.fieldCategory = category;
      this.fieldId = id;
      this.categoryModal = true;
    },
    removeIt: function(id, type, name) {
      var vm = this;
      if (!confirm(name + ' を削除しますか')) {
        return false;
      }
      vm.$root.agent({
        url: '/api/delete_it',
        data: {
          subscription: type,
          id: id
        }
      }).then(() => { vm.fetchList() });
    },
    // カテゴリの変更
    submit: function() {
      var vm = this;
      vm.$root.agent({
        url: '/api/change_it',
        data: {
          id: vm.fieldId,
          category: vm.fieldCategory,
        },
      }).then(() => {
        vm.categoryModal = false;
        vm.fetchList();
      });
    },
    fetchList: function() {
      var vm = this;
      vm.$root.agent({ url: '/api/get_subscription' }).then(data => {
        vm.subscription = data;
        vm.categories = data.map(x => { return { id: x.id, name: x.name } });
      });
    }
  }
};
</script>
