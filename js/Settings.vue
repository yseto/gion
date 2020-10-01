/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div class="container">
    <Config />
    <hr>
    <Password />
    <hr>
    <Opml />
  </div>
</template>

<script>
import Config from './Settings/Config.vue';
import Opml from './Settings/Opml.vue';
import Password from './Settings/Password.vue';

export default {
  components: {
    Config,
    Opml,
    Password,
  },
};
</script>
