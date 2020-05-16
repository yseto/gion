/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <div class="row">
      <table
        class="table table-condensed"
        style="table-layout: fixed;"
      >
        <tbody>
          <tr
            v-for="(item, index) in lists"
            :key="index"
          >
            <th v-if="item.type == 'title'">
              {{ item.name }}
              <span class="pull-right">
                <button
                  class="btn btn-danger btn-xs"
                  @click="removeIt(item.id, 'category', item.name)"
                >削除</button>
              </span>
            </th>
            <td
              v-else
              style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"
            >
              <a
                class="pull-left btn btn-link btn-xs"
                :href="item.siteurl"
                :title="item.title"
                target="blank"
              >
                <span class="visible-xs">{{ item.title }}</span><!-- cutting need -->
                <span class="visible-sm visible-md visible-lg">{{ item.title }}</span>
                <span
                  v-if="item.http_status < -5 || item.http_status == '404'"
                  class="badge"
                >取得に失敗しました</span>
              </a> 
              <span class="pull-right">
                <button
                  class="btn btn-info btn-xs"
                  @click="changeCategory(item.id, item.category_id)"
                >移動</button>
              &nbsp;
                <button
                  class="btn btn-danger btn-xs"
                  @click="removeIt(item.id, 'entry', item.title)"
                >削除</button>
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div><!--/row-->

    <hr>
 
    <div
      v-if="categoryModal"
      id="categoryModal"
      class="modal show"
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
              class="control-label"
              for="selectCat"
            >Categories</label>
            <select
              v-model="fieldCategory"
              class="form-control"
              placeholder="Choose Category"
            >
              <option
                v-for="item in category"
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
              class="btn btn-default"
              @click="categoryModal=false"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    <p class="clearfix hidden-lg hidden-md">
      <a
        class="btn btn-default pull-right"
        @click="$root.returntop"
      >Back to Top</a>
    </p>
  </div><!--/.container-->
</template>

<script>
export default {
  data: function() {
    return {
      category: [],
      subscription: [],
      lists: [],
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
      }, function() {
        vm.fetchList();
      });
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
      }, function() {
        vm.categoryModal = false;
        vm.fetchList();
      });
    },
    fetchList: function() {
      var vm = this;
      var tmp = [], list = {};

      vm.$root.agent({
        url: '/api/get_subscription'
      }, function(data) {
        vm.category = data.category;
        vm.subscription = data.subscription;

        vm.category.forEach(function(_, i) {
          list[vm.category[i].id] = {
            id: vm.category[i].id,
            list: [],
            name: vm.category[i].name
          };
        });
        vm.subscription.forEach(function(_, i) {
          list[vm.subscription[i].category_id].list.push(vm.subscription[i]);
        });

        // combined
        Object.keys(list).forEach(function(i) {
          tmp.push({
            id: list[i].id,
            name: list[i].name,
            type: 'title',
          });
          list[i].list.forEach(function(_, j) {
            var value = list[i].list[j];
            value.type = 'item';
            tmp.push(value);
          });
        }, list);
        vm.lists = tmp;
      });
    }
  }
};
</script>
