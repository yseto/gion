/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <Feed ref="feed" />
    <hr>
    <Category @fetchCategory="fetchCategory" />
    <p class="clearfix hidden-lg hidden-md">
      <a
        class="btn btn-default pull-right"
        @click="$root.returntop"
      >Back to Top</a>
    </p>
  </div><!--/container-->
</template>

<script>
import Feed from './addSubscription/Feed.vue'
import Category from './addSubscription/Category.vue'

export default {
  components: {
    Feed,
    Category
  },
  methods: {
    fetchCategory: function() {
      this.$refs.feed.fetchList();
    },
  },
};
</script>

