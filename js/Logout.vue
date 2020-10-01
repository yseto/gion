/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div />
</template>
<script>
import TokenStore from './components/TokenStore.js'

export default {
  mounted: function() {
    const vm = this;
    vm.$root.agent({ url: '/api/logout' }).then(() => {
      TokenStore.commit("logout");
      vm.$router.push("/login");
    });
  }
};
</script>

