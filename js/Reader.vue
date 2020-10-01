/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <div class="row">
      <div class="col-sm-3">
        <PinList ref="pinList" />
        <CategoryList
          ref="categoryList"
          @contentUpdate="contentUpdate"
        />
      </div>
      <div class="col-sm-9">
        <ContentList
          ref="contentList"
          @categoryUpdate="categoryUpdate"
        />
      </div>
    </div>

    <ul class="pager hidden-lg hidden-md">
      <li class="previous">
        <a
          class="btn btn-default"
          @click.prevent="categoryPrevious"
        >&lt;&lt; Category Back</a>
      </li>
      <li class="next">
        <a
          class="btn btn-default"
          @click.prevent="categoryNext"
        >Category Next &gt;&gt;</a>
      </li>
    </ul>

    <p class="clearfix hidden-lg hidden-md">
      <a
        class="btn btn-default pull-right"
        @click="$root.returntop"
      >Back to Top</a>
    </p>
  </div>
</template>

<script>
import PinList from './Reader/PinList.vue'
import CategoryList from './Reader/CategoryList.vue'
import ContentList from './Reader/ContentList.vue'

export default {
  components: {
    PinList,
    CategoryList,
    ContentList,
  },
  destroyed: function() {
    document.removeEventListener('keypress', this.keypressHandler);
  },
  mounted: function() {
    // キーボードのイベント
    document.addEventListener("keypress", this.keypressHandler);
  },
  methods: {
    keypressHandler: function(e) {
      e.preventDefault();
      switch (e.code) {
      case "KeyA":
        this.categoryPrevious();
        break;
      case "KeyS":
        this.categoryNext();
        break;
      case "KeyO":
        this.$refs.pinList.toggleVisible();
        break;
      case "KeyP":
        this.togglePin();
        break;
      case "KeyR":
        this.contentUpdate();
        break;
      case "KeyK":
        this.contentPrevious();
        break;
      case "KeyJ":
        this.contentNext();
        break;
      case "KeyV":
        this.itemView();
        break;
      }
    },

    // カテゴリの移動
    categoryNext: function() {
      this.$refs.categoryList.next();
    },
    categoryPrevious: function() {
      this.$refs.categoryList.previous();
    },
    // カテゴリ一覧の更新
    categoryUpdate: function() {
      this.$refs.categoryList.update();
    },

    // エントリの移動
    contentNext: function() {
      this.$refs.contentList.next();
    },
    contentPrevious: function() {
      this.$refs.contentList.previous();
    },
    // エントリ一覧の更新
    contentUpdate: function() {
      this.$refs.contentList.update(this.$refs.categoryList.current());
    },

    // アイテムを閲覧する
    itemView: function() {
      window.open(this.$refs.contentList.current());
    },

    // ピン立て
    togglePin: function() {
      this.$refs.contentList.togglePin();
      this.$refs.pinList.update();
    },
  },
};
</script>
