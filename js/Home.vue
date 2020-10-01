/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div />
</template>
<script>
export default {
  created: function() {
    const vm = this;
    vm.$root.agent({ url: '/api/get_numentry' }).then(res => {
      const next = res.nopinlist === true ? '/entry' : '/pin';
      vm.$router.push(next);
    });
  },
};
</script>
