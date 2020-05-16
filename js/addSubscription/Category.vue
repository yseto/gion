/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="row">
    <div class="col-md-8">
      <h4>Categories</h4>
      <div class="form-horizontal">
        <div class="form-group">
          <label
            class="col-sm-3 control-label"
            for="inputCategoryName"
          >Name</label>
          <div class="col-sm-6">
            <input
              v-model="inputCategoryName"
              type="text"
              class="form-control"
              placeholder="Name"
            >
          </div>
        </div>
        <div class="form-group">
          <div class="col-sm-9 col-sm-offset-3">
            <button
              type="button"
              class="btn btn-primary"
              @click.prevent="registerCategory"
            >
              Register
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
      inputCategoryName: null
    };
  },
  methods: {
    // カテゴリの登録
    registerCategory: function() {
      const vm = this;
      if (vm.inputCategoryName.length) {
        vm.$root.agent({
          url: '/api/register_category',
          data: {
            name: vm.inputCategoryName
          },
        }, function(data) {
          if (data.result === "ERROR_ALREADY_REGISTER") {
            alert("すでに登録されています。");
          } else {
            vm.$emit("fetchCategory");
            alert("登録しました。");
          }
        });
      }
      return false;
    },
  },
}
</script>

