/* vim:set ts=2 sts=2 sw=2:*/
<template>
<div>
  <GionHeader></GionHeader>
  <div class="container">
    <div class="row">
      <table class="table table-condensed" style="table-layout: fixed;">
        <tbody>
          <tr v-for="(item, index) in lists">
            <th v-if="item.type == 'title'">
              {{ item.name }}
              <span class="pull-right">
                <button class="btn btn-danger btn-xs" v-on:click="removeIt(item.id, 'category', item.name)">削除</button>
              </span>
            </th>
            <td v-else style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
              <a class="pull-left btn btn-link btn-xs" v-bind:href="item.siteurl" v-bind:title="item.title" target="blank">
                <span class="visible-xs">{{ item.title }}</span><!-- cutting need -->
                <span class="visible-sm visible-md visible-lg">{{ item.title }}</span>
                <span v-if="item.http_status < -5 || item.http_status == '404'" class="badge">取得に失敗しました</span>
              </a> 
              <span class="pull-right">
                <button class="btn btn-info btn-xs" v-on:click="changeCategory(item.id, item.category_id)">移動</button>
                &nbsp;
                <button class="btn btn-danger btn-xs" v-on:click="removeIt(item.id, 'entry', item.title)">削除</button>
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div><!--/row-->

    <hr>
   
    <div class="modal show" id="categoryModal" tabindex="-1" v-if="categoryModal">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h4 class="modal-title">Change: Categories</h4>
          </div>
          <div class="modal-body">
            <label class="control-label" for="selectCat">Categories</label>
            <select v-model="field_category" class="form-control" placeholder="Choose Category">
              <option v-for="item in category" v-bind:value="item.id">{{ item.name }}</option>
            </select>
          </div>
          <div class="modal-footer">
            <a class="btn btn-success" v-on:click="submit">OK</a>
            <button class="btn btn-default" v-on:click="categoryModal=false">Cancel</button>
          </div>
        </div>
      </div>
    </div>
    <p class="clearfix hidden-lg hidden-md"><a class="btn btn-default pull-right" v-on:click="$root.returntop">Back to Top</a></p>
  </div><!--/.container-->
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
      category: [],
      subscription: [],
      lists: [],
      field_category: null,
      field_id: null,
      categoryModal: false
    };
  },
  created: function() {
    this.fetchList();
  },
  methods: {
    // エントリのカテゴリの変更ウィンドウを表示する
    changeCategory: function(id, category) {
      this.field_category = category;
      this.field_id = id;
      this.categoryModal = true;
    },
    removeIt: function(id, type, name) {
      var self = this;
      if (!confirm(name + ' を削除しますか')) {
        return false;
      }
      agent({
        url: '/api/delete_it',
        data: {
          subscription: type,
          id: id
        }
      }, function() {
        self.fetchList();
      });
    },
    // カテゴリの変更
    submit: function() {
      var self = this;
      agent({
        url: '/api/change_it',
        data: {
          id: self.field_id,
          category: self.field_category,
        },
      }, function() {
        self.categoryModal = false;
        self.fetchList();
      });
    },
    fetchList: function() {
      var self = this;
      var tmp = [], list = {};

      agent({
        url: '/api/get_subscription'
      }, function(data) {
          self.category = data.category;
          self.subscription = data.subscription;

          self.category.forEach(function(_, i) {
            list[self.category[i].id] = {
              id: self.category[i].id,
              list: [],
              name: self.category[i].name
            };
          });
          self.subscription.forEach(function(_, i) {
            list[self.subscription[i].category_id].list.push(self.subscription[i]);
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
          self.lists = tmp;
      });
    }
  }
};
</script>
