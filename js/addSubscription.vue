/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <Feed ref="feed" />
    <hr>
    <Category @fetchCategory="fetchCategory" />
    <BackToTop />
  </div>
</template>

<script>
import Feed from './addSubscription/Feed.vue'
import Category from './addSubscription/Category.vue'
import BackToTop from './components/BackToTop.vue'

export default {
  components: {
    Feed,
    Category,
    BackToTop,
  },
  methods: {
    fetchCategory: function() {
      this.$refs.feed.fetchList();
    },
  },
};
</script>

