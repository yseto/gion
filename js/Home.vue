/* vim:set ts=2 sts=2 sw=2:*/
<script>
export default {
  created: function() {
    if (document.querySelector('meta[name=mode-nopin]').content === 'true') {
      this.$root.go('#entry');
    } else {
      this.$root.go('#pin');
    }
  },
};
</script>
