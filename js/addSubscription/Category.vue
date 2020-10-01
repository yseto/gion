/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="row">
    <div class="col-md-8">
      <h4>Categories</h4>
      <div class="form-horizontal">
        <div class="row form-group">
          <label
            class="col-sm-3 col-form-label"
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
        <div class="row form-group">
          <div class="col-sm-3" />
          <div class="col-sm-9">
            <button
              type="button"
              class="btn"
              :class="success ? 'btn-outline-primary' : 'btn-primary'"
              :disabled="!!!inputCategoryName"
              @click.prevent="registerCategory"
            >
              {{ success ? "Saved!..." : "Register" }}
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
      inputCategoryName: null,
      success: false,
    };
  },
  methods: {
    // カテゴリの登録
    registerCategory: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/register_category',
        data: {
          name: vm.inputCategoryName
        },
      }).then(data => {
        if (data.result === "ERROR_ALREADY_REGISTER") {
          alert("すでに登録されています。");
        } else {
          vm.$emit("fetchCategory");
          vm.inputCategoryName = null;
          vm.success = true;
          setTimeout(function() {
            vm.success = false;
          }, 750);
        }
      });
    },
  },
}
</script>

