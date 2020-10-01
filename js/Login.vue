/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
<template>
  <div style="max-width:330px; padding:80px 15px 0; margin:0 auto;">
    <h3>Gion</h3>
    <input
      v-model="id"
      v-focus
      type="text"
      class="form-control"
      placeholder="ID"
      required
      @keydown.enter="login"
    >
    <input
      v-model="password"
      type="password"
      class="form-control"
      placeholder="Password"
      required
      @keydown.enter="login"
    >
    <button
      class="btn btn-primary"
      style="margin-top: 20px;"
      @click="login"
    >
      Sign in
    </button>
  </div>
</template>
<script>
export default {
  data: function() {
    return {
      id: "",
      password: "",
    };
  },
  methods: {
    login: function() {
      const vm = this;
      vm.$root.agent({
        url: '/api/login',
        data: {
          id: vm.id,
          password: vm.password,
        }
      }).then(() => {
        if (vm.$route.query.redirect) {
          vm.$router.push(vm.$route.query.redirect);
        } else {
          vm.$router.push("/");
        }
      });
    },
  },
};
</script>
